use proptest::prelude::*;
use serde_json::json;

use crate::hosting_desk::{
    heavy_cases, host_a_server, read_hosted_peer_address,
};
use crate::local_announcements::{
    describe_announced_address, watch_for_announcement,
};
use crate::server_announcement_properties::watch_hosted_announcement;
use crate::support::test_device::fail;

proptest! {
    #![proptest_config(heavy_cases(1))]

    #[test]
    fn test_server_announcement_stop_property_a_stopped_node_says_goodbye(
        _round in 0_u8..1,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;
        let wanted = describe_announced_address(&peer_address);
        let (watch, announced) =
            watch_for_announcement(&wanted).map_err(fail)?;

        let _stopped = hosting.device.stop();

        let withdrawn = watch.wait_for_withdrawal(&announced.full_name);
        prop_assert_eq!(withdrawn, Ok(()));
    }

    #[test]
    fn test_server_announcement_stop_property_forgetting_says_goodbye(
        _round in 0_u8..1,
    ) {
        let hosting = host_a_server().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;
        let wanted = describe_announced_address(&peer_address);
        let (watch, announced) =
            watch_for_announcement(&wanted).map_err(fail)?;

        hosting
            .device
            .run(&json!({ "command": "forget_this_device" }))
            .map_err(fail)?;

        let withdrawn = watch.wait_for_withdrawal(&announced.full_name);
        prop_assert_eq!(withdrawn, Ok(()));
    }

    #[test]
    fn test_server_announcement_stop_property_a_restart_announces_again(
        _round in 0_u8..1,
    ) {
        let mut hosting = host_a_server().map_err(fail)?;
        let before = watch_hosted_announcement(&hosting).map_err(fail)?;

        hosting.device =
            hosting.device.stop_and_start_again().map_err(fail)?;

        let after = watch_hosted_announcement(&hosting).map_err(fail)?;
        prop_assert_eq!(after.full_name, before.full_name);
        prop_assert_eq!(after.properties, before.properties);
    }
}
