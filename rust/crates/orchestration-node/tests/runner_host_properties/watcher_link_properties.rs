use chrono::Utc;
use orchestration_core::identifiers::RunId;
use orchestration_node::live_link_messages::{ClientMessage, RunnerMessage};
use proptest::prelude::*;
use uuid::Uuid;

use crate::live_link_steps::{
    LinkSide, QUIET_PERIOD, ask, collect_for, count_frames_until_end,
    is_direct_link_change, link_side, open_link, receive_message,
    send_client_message, wait_for_direct_link_change,
};
use crate::run_view_steps::{
    DIRECT_LINK, LOST_AT_FIELD, wait_for_server_link,
};
use crate::support::test_device::fail;
use crate::watcher_steps::{
    close_watchers, link_and_wait, open_watchers, read_lost_at,
    unlink_and_wait,
};

const LINK_CASES: u32 = 1;
const MOST_WATCHERS: usize = 3;
const UNTRUSTED_WATCHER_REASON: &str =
    "the peer is not a trusted client of this run's workspace";

async fn watch_as_stranger(
    side: &LinkSide,
) -> Result<(RunnerMessage, usize), String> {
    let mut link = open_link(&side.stranger, side.host).await?;
    let watch_request = ClientMessage::Watch {
        run_id: side.shared_run,
    };
    send_client_message(&mut link, &watch_request).await?;
    let reply = receive_message(&mut link).await?;
    let later_frames = count_frames_until_end(&mut link).await?;
    Ok((reply, later_frames))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LINK_CASES))]

    #[test]
    fn test_serve_watcher_property_an_unclaimed_run_is_never_accepted(
        number in any::<u128>(),
    ) {
        let side = link_side().map_err(fail)?;
        let watch_request = ClientMessage::Watch {
            run_id: RunId(Uuid::from_u128(number)),
        };

        let reply = side
            .runtime
            .block_on(ask(&side.client, side.host, &watch_request))
            .map_err(fail)?;

        let is_refused = matches!(reply, RunnerMessage::Refused { .. });
        prop_assert!(is_refused, "{:?}", reply);
    }

    #[test]
    fn test_serve_watcher_property_a_stranger_is_refused_and_let_go(
        ask_count in 1_usize..3,
    ) {
        let side = link_side().map_err(fail)?;

        for _ in 0..ask_count {
            let (reply, later_frames) = side
                .runtime
                .block_on(watch_as_stranger(side))
                .map_err(fail)?;

            let expected = RunnerMessage::Refused {
                reason: UNTRUSTED_WATCHER_REASON.to_owned(),
            };
            prop_assert_eq!(reply, expected);
            prop_assert_eq!(later_frames, 0);
        }
    }

    #[test]
    fn test_serve_watcher_property_hears_events_posted_after_accepting(
        watcher_count in 1..=MOST_WATCHERS,
    ) {
        let side = link_side().map_err(fail)?;
        let _turn = side.take_lone_run_turn();
        let mut links = open_watchers(side, watcher_count).map_err(fail)?;

        let mut heard_arrivals = Vec::new();
        for link in &mut links {
            let hearing = wait_for_direct_link_change(link);
            heard_arrivals.push(side.runtime.block_on(hearing));
        }
        let finished = unlink_and_wait(side, links);

        for heard in heard_arrivals {
            prop_assert_eq!(heard, Ok(()));
        }
        prop_assert!(finished.is_ok(), "{:?}", finished);
    }

    #[test]
    fn test_post_link_change_property_a_lost_link_records_when(
        watcher_count in 1..=MOST_WATCHERS,
    ) {
        let side = link_side().map_err(fail)?;
        let _turn = side.take_lone_run_turn();
        let links = link_and_wait(side, watcher_count).map_err(fail)?;
        let before_loss = Utc::now();

        let run = unlink_and_wait(side, links).map_err(fail)?;
        let after_loss = Utc::now();

        let lost_at = read_lost_at(&run).map_err(fail)?;
        prop_assert!(before_loss <= lost_at, "{} {}", before_loss, lost_at);
        prop_assert!(lost_at <= after_loss, "{} {}", lost_at, after_loss);
    }

    #[test]
    fn test_post_link_change_property_every_change_reaches_the_watchers(
        newcomer_count in 1..=MOST_WATCHERS,
    ) {
        let side = link_side().map_err(fail)?;
        let _turn = side.take_lone_run_turn();
        let mut first = link_and_wait(side, 1).map_err(fail)?;
        let newcomers = open_watchers(side, newcomer_count).map_err(fail)?;

        let heard = side
            .runtime
            .block_on(collect_for(&mut first[0], QUIET_PERIOD))
            .map_err(fail)?;
        close_watchers(side, newcomers).map_err(fail)?;
        let finished = unlink_and_wait(side, first);

        let mut announcement_count = 0;
        for message in &heard {
            if is_direct_link_change(message) {
                announcement_count += 1;
            }
        }
        prop_assert!(announcement_count >= newcomer_count, "{:?}", heard);
        prop_assert!(finished.is_ok(), "{:?}", finished);
    }

    #[test]
    fn test_post_link_change_property_a_new_link_clears_the_lost_time(
        watcher_count in 1..=MOST_WATCHERS,
    ) {
        let side = link_side().map_err(fail)?;
        let _turn = side.take_lone_run_turn();
        let first_links = link_and_wait(side, watcher_count).map_err(fail)?;
        let lost_run = unlink_and_wait(side, first_links).map_err(fail)?;

        let again = open_watchers(side, watcher_count).map_err(fail)?;
        let relinked =
            wait_for_server_link(side.host, side.lone_run, DIRECT_LINK);
        let finished = unlink_and_wait(side, again);

        prop_assert!(lost_run[LOST_AT_FIELD].is_string(), "{}", lost_run);
        let relinked = relinked.map_err(fail)?;
        prop_assert!(relinked[LOST_AT_FIELD].is_null(), "{}", relinked);
        prop_assert!(finished.is_ok(), "{:?}", finished);
    }
}
