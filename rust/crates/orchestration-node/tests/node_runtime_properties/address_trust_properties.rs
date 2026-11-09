use orchestration_node::live_link_messages::RunnerMessage;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::json;

use crate::fake_runner::RunnerAnswer;
use crate::forged_workspace::{
    TAMPERINGS, UNTRUSTED_ADDRESS_END, list_device_views,
    prepare_forged_workspace, publish_own_fake_runner, read_verified_flag,
    start_running_run,
};
use crate::forging_server::Forgery;
use crate::peer_publishing::wait_for_announcement;
use crate::support::test_device::fail;
use crate::watch_desk::{read_watch_problem, watch_run};

const TRUST_CASES: u32 = 3;
const MOST_LISTINGS: usize = 6;

fn tampering_strategy() -> impl Strategy<Value = Forgery> {
    prop::sample::select(TAMPERINGS.to_vec())
}

fn forgery_strategy() -> impl Strategy<Value = Forgery> {
    prop_oneof![Just(Forgery::Untouched), tampering_strategy()]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(TRUST_CASES))]

    #[test]
    fn test_trusted_peer_address_property_a_genuine_address_is_trusted(
        listing_count in 1..=MOST_LISTINGS,
    ) {
        let workspace = prepare_forged_workspace().map_err(fail)?;
        let announced = wait_for_announcement(&workspace.device)
            .map_err(fail)?;
        workspace.server.forge(&workspace.device_id, Forgery::Untouched);

        for _ in 0..listing_count {
            let views = list_device_views(&workspace.device).map_err(fail)?;
            let verified = read_verified_flag(&views, &workspace.device_id);
            prop_assert_eq!(verified, Some(json!(true)));
            let own_view = views
                .iter()
                .find(|view| view["is_this_device"] == json!(true));
            let listed = own_view
                .map(|view| view["device"]["peer_address"]["address"].clone());
            prop_assert_eq!(listed, Some(json!(announced)));
        }
    }

    #[test]
    fn test_trusted_peer_address_property_any_tampering_is_untrusted(
        tampering in tampering_strategy(),
    ) {
        let workspace = prepare_forged_workspace().map_err(fail)?;
        wait_for_announcement(&workspace.device).map_err(fail)?;
        workspace.server.forge(&workspace.device_id, tampering);

        let views = list_device_views(&workspace.device).map_err(fail)?;

        let verified = read_verified_flag(&views, &workspace.device_id);
        prop_assert_eq!(verified, Some(json!(false)));
    }

    #[test]
    fn test_trusted_peer_address_property_trust_follows_every_listing(
        forgeries in vec(forgery_strategy(), 1..MOST_LISTINGS),
    ) {
        let workspace = prepare_forged_workspace().map_err(fail)?;
        wait_for_announcement(&workspace.device).map_err(fail)?;

        for forgery in &forgeries {
            workspace.server.forge(&workspace.device_id, *forgery);
            let views = list_device_views(&workspace.device).map_err(fail)?;
            let verified = read_verified_flag(&views, &workspace.device_id);
            let is_genuine = *forgery == Forgery::Untouched;
            prop_assert_eq!(verified, Some(json!(is_genuine)));
        }
    }

    #[test]
    fn test_connect_to_runner_property_an_untrusted_runner_is_not_dialed(
        tampering in tampering_strategy(),
    ) {
        let workspace = prepare_forged_workspace().map_err(fail)?;
        let answer = RunnerAnswer::Reply(RunnerMessage::Accepted);
        let fake_runner =
            publish_own_fake_runner(&workspace, answer).map_err(fail)?;
        let run_id = start_running_run(&workspace).map_err(fail)?;
        workspace.server.forge(&workspace.device_id, tampering);

        let view = watch_run(&workspace.device, &run_id).map_err(fail)?;

        let expected = format!(
            "device {} {UNTRUSTED_ADDRESS_END}",
            workspace.device_id
        );
        prop_assert_eq!(read_watch_problem(&view), expected);
        prop_assert!(fake_runner.received().is_empty());
    }
}
