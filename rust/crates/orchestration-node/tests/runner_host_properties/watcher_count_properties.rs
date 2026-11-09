use proptest::prelude::*;
use proptest::sample::Index;

use crate::live_link_steps::{QUIET_PERIOD, link_side};
use crate::run_view_steps::{
    DIRECT_LINK, LOST_AT_FIELD, UNREACHABLE_LINK, stays_linked,
    wait_for_server_link,
};
use crate::support::test_device::fail;
use crate::watcher_steps::{
    close_watchers, link_and_wait, open_watchers, open_watchers_at_once,
    open_watchers_of, take_one, unlink_and_wait,
};

const COUNT_CASES: u32 = 1;
const MOST_WATCHERS: usize = 3;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(COUNT_CASES))]

    #[test]
    fn test_see_off_property_a_leaving_watcher_keeps_the_others_linked(
        watcher_count in 2..=MOST_WATCHERS,
        leaving_choice in any::<Index>(),
    ) {
        let side = link_side().map_err(fail)?;
        let _turn = side.take_lone_run_turn();
        let leaving_count = 1 + leaving_choice.index(watcher_count - 1);
        let mut staying = link_and_wait(side, watcher_count).map_err(fail)?;
        let leaving: Vec<_> = staying.drain(..leaving_count).collect();

        close_watchers(side, leaving).map_err(fail)?;
        let kept_link = stays_linked(side.host, side.lone_run, QUIET_PERIOD)
            .map_err(fail)?;
        let finished = unlink_and_wait(side, staying);

        prop_assert!(kept_link);
        prop_assert!(finished.is_ok(), "{:?}", finished);
    }

    #[test]
    fn test_see_off_property_the_last_watcher_out_marks_unreachable(
        watcher_count in 1..=MOST_WATCHERS,
        first_leaver in any::<Index>(),
    ) {
        let side = link_side().map_err(fail)?;
        let _turn = side.take_lone_run_turn();
        let links = link_and_wait(side, watcher_count).map_err(fail)?;
        let (leaver, others) = take_one(links, first_leaver);

        close_watchers(side, vec![leaver]).map_err(fail)?;
        let run = unlink_and_wait(side, others).map_err(fail)?;

        prop_assert!(run[LOST_AT_FIELD].is_string(), "{}", run);
    }

    #[test]
    fn test_see_off_property_a_returning_watcher_relinks_the_run(
        first_count in 1..=MOST_WATCHERS,
    ) {
        let side = link_side().map_err(fail)?;
        let _turn = side.take_lone_run_turn();
        let first_links = link_and_wait(side, first_count).map_err(fail)?;
        unlink_and_wait(side, first_links).map_err(fail)?;

        let mut returning = link_and_wait(side, 2).map_err(fail)?;
        let early_leaver = returning.remove(0);
        close_watchers(side, vec![early_leaver]).map_err(fail)?;
        let kept_link = stays_linked(side.host, side.lone_run, QUIET_PERIOD)
            .map_err(fail)?;
        let finished = unlink_and_wait(side, returning);

        prop_assert!(kept_link);
        prop_assert!(finished.is_ok(), "{:?}", finished);
    }

    #[test]
    fn test_welcome_property_an_accepted_watcher_marks_the_run_direct(
        watcher_count in 1..=MOST_WATCHERS,
    ) {
        let side = link_side().map_err(fail)?;
        let _turn = side.take_lone_run_turn();
        let links = open_watchers(side, watcher_count).map_err(fail)?;

        let run = wait_for_server_link(side.host, side.lone_run, DIRECT_LINK);
        let finished = unlink_and_wait(side, links);

        let run = run.map_err(fail)?;
        prop_assert!(run[LOST_AT_FIELD].is_null(), "{}", run);
        prop_assert!(finished.is_ok(), "{:?}", finished);
    }

    #[test]
    fn test_welcome_property_watchers_arriving_at_once_are_all_counted(
        watcher_count in 2..=MOST_WATCHERS,
        staying_choice in any::<Index>(),
    ) {
        let side = link_side().map_err(fail)?;
        let _turn = side.take_lone_run_turn();
        let links =
            open_watchers_at_once(side, watcher_count).map_err(fail)?;
        wait_for_server_link(side.host, side.lone_run, DIRECT_LINK)
            .map_err(fail)?;
        let (stayer, leavers) = take_one(links, staying_choice);

        close_watchers(side, leavers).map_err(fail)?;
        let kept_link = stays_linked(side.host, side.lone_run, QUIET_PERIOD)
            .map_err(fail)?;
        let finished = unlink_and_wait(side, vec![stayer]);

        prop_assert!(kept_link);
        prop_assert!(finished.is_ok(), "{:?}", finished);
    }

    #[test]
    fn test_welcome_property_watchers_are_counted_per_run(
        shared_watcher_count in 1..=MOST_WATCHERS,
    ) {
        let side = link_side().map_err(fail)?;
        let _turn = side.take_lone_run_turn();
        let shared_links =
            open_watchers_of(side, side.shared_run, shared_watcher_count)
                .map_err(fail)?;
        let lone_links = link_and_wait(side, 1).map_err(fail)?;

        close_watchers(side, lone_links).map_err(fail)?;
        let lone_run =
            wait_for_server_link(side.host, side.lone_run, UNREACHABLE_LINK);
        close_watchers(side, shared_links).map_err(fail)?;

        prop_assert!(lone_run.is_ok(), "{:?}", lone_run);
    }
}
