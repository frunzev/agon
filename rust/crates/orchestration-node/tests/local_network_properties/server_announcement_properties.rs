use std::time::Duration;

use orchestration_node::server_address::ServerAddress;
use proptest::prelude::*;

use crate::announcement_watching::{AnnouncementBrowser, WatchedAnnouncement};
use crate::announcing::{APP_SERVER_SERVICE_TYPE, SERVER_ADDRESS_PROPERTY};
use crate::hosting_desk::{
    heavy_cases, read_hosted_peer_address, read_own_group, shared_hosting,
};
use crate::local_announcements::describe_announced_address;
use crate::support::hosting_steps::HostingDevice;
use crate::support::test_device::{TestDevice, fail};
use crate::support::waiting::wait_for;

const INSTANCE_NAME_PREFIX: &str = "agents-orchestration-";
const HOST_NAME_SUFFIX: &str = ".local.";
const NAME_SEPARATOR: &str = ".";
const DIRECT_FIELD_START: &str = "direct=";
const ANNOUNCEMENT_LIMIT: Duration = Duration::from_secs(60);
const DEBUG_LIMIT: Duration = Duration::from_secs(20);
const DEBUG_DESCRIPTION: &str = "the hosted server to show in the debug text";
const DEBUG_START: &str = "ServerAnnouncement {";
const DEBUG_END: &str = "}";
const DAEMON_WORD: &str = "daemon";

pub fn watch_hosted_announcement(
    hosting: &HostingDevice,
) -> Result<WatchedAnnouncement, String> {
    let peer_address = read_hosted_peer_address(&hosting.device)?;
    let wanted = describe_announced_address(&peer_address);
    let browser = AnnouncementBrowser::start()?;
    browser.wait_for_announcement(&wanted, ANNOUNCEMENT_LIMIT)
}

fn read_server_id(hosting: &HostingDevice) -> Result<String, String> {
    let view = read_own_group(&hosting.device, hosting.port)?;
    let term = view.group.term.ok_or("the group has no term")?;
    Ok(term.server_id.0)
}

fn find_announcement_debug(debug_text: &str) -> Option<String> {
    let start = debug_text.find(DEBUG_START)?;
    let after_start = &debug_text[start..];
    let end = after_start.find(DEBUG_END)?;
    Some(after_start[..=end].to_owned())
}

fn read_announcement_debug(device: &TestDevice) -> Result<String, String> {
    wait_for(DEBUG_LIMIT, DEBUG_DESCRIPTION, || {
        let debug_text = format!("{device:?}");
        Ok(find_announcement_debug(&debug_text))
    })
}

proptest! {
    #![proptest_config(heavy_cases(1))]

    #[test]
    fn test_server_announcement_start_property_carries_only_the_address(
        _round in 0_u8..1,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;

        let announced = watch_hosted_announcement(hosting).map_err(fail)?;

        let expected = vec![(
            SERVER_ADDRESS_PROPERTY.to_owned(),
            describe_announced_address(&peer_address),
        )];
        prop_assert_eq!(announced.properties, expected);
    }

    #[test]
    fn test_server_announcement_start_property_the_address_parses_back(
        _round in 0_u8..1,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;
        let announced = watch_hosted_announcement(hosting).map_err(fail)?;
        let announced_text = &announced.properties[0].1;

        let parsed = ServerAddress::parse(announced_text).map_err(fail)?;

        let hosted = ServerAddress::Peer(peer_address);
        prop_assert_eq!(&parsed, &hosted.without_direct_addresses());
        prop_assert!(parsed.direct_addresses().is_empty());
        prop_assert!(!announced_text.contains(DIRECT_FIELD_START));
    }

    #[test]
    fn test_server_announcement_start_property_names_the_server_and_port(
        _round in 0_u8..1,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let peer_address =
            read_hosted_peer_address(&hosting.device).map_err(fail)?;
        let server_id = read_server_id(hosting).map_err(fail)?;

        let announced = watch_hosted_announcement(hosting).map_err(fail)?;

        let instance_name = format!("{INSTANCE_NAME_PREFIX}{server_id}");
        let service_type = APP_SERVER_SERVICE_TYPE;
        let full_name =
            format!("{instance_name}{NAME_SEPARATOR}{service_type}");
        let host_name = format!("{instance_name}{HOST_NAME_SUFFIX}");
        prop_assert_eq!(&announced.full_name, &full_name);
        prop_assert_eq!(&announced.host_name, &host_name);
        for direct_address in &peer_address.direct_addresses {
            if direct_address.is_ipv4() {
                prop_assert_eq!(direct_address.port(), announced.port);
            }
        }
    }

    #[test]
    fn test_server_announcement_fmt_property_names_the_announced_service(
        _round in 0_u8..1,
    ) {
        let hosting = shared_hosting().map_err(fail)?;
        let announced = watch_hosted_announcement(hosting).map_err(fail)?;

        let shown = read_announcement_debug(&hosting.device).map_err(fail)?;

        let expected = format!(
            "{DEBUG_START} service_name: {:?}, .. {DEBUG_END}",
            announced.full_name
        );
        prop_assert_eq!(shown, expected);
    }

    #[test]
    fn test_server_announcement_fmt_property_hides_the_daemon(
        _round in 0_u8..1,
    ) {
        let hosting = shared_hosting().map_err(fail)?;

        let shown = read_announcement_debug(&hosting.device).map_err(fail)?;

        prop_assert!(!shown.to_lowercase().contains(DAEMON_WORD), "{shown}");
    }

    #[test]
    fn test_server_announcement_fmt_property_a_plain_device_shows_none(
        _round in 0_u8..1,
    ) {
        let device = TestDevice::start().map_err(fail)?;

        let debug_text = format!("{device:?}");

        prop_assert_eq!(find_announcement_debug(&debug_text), None);
    }
}
