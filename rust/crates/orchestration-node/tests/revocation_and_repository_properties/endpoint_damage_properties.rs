use std::fs;

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::damaged_hosting_steps::{
    PEER_PORT_FILE_NAME, PEER_SECRET_FILE_NAME, RECORD_DAMAGED_KIND,
    damaged_hosted_bytes_strategy, read_kind_text, read_problem_text,
    start_with_file_bytes,
};
use crate::support::test_device::fail;

const DAMAGE_CASES: u32 = 4;
const MOST_STARTS: usize = 3;
const PEER_SECRET_TEXT: &str = "peer secret";
const LOWEST_REMEMBERED_PORT: u16 = 20_000;
const HIGHEST_REMEMBERED_PORT: u16 = 60_000;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DAMAGE_CASES))]

    #[test]
    fn test_find_or_create_server_secret_property_damage_offers_set_up(
        damaged_bytes in damaged_hosted_bytes_strategy(),
    ) {
        let damaged =
            start_with_file_bytes(PEER_SECRET_FILE_NAME, &damaged_bytes)
                .map_err(fail)?;

        let status = damaged.read_status().map_err(fail)?;

        prop_assert_eq!(read_kind_text(&status), RECORD_DAMAGED_KIND);
    }

    #[test]
    fn test_find_or_create_server_secret_property_every_start_agrees(
        damaged_bytes in damaged_hosted_bytes_strategy(),
        start_count in 2..=MOST_STARTS,
    ) {
        let mut damaged =
            start_with_file_bytes(PEER_SECRET_FILE_NAME, &damaged_bytes)
                .map_err(fail)?;

        let first_status = damaged.read_status().map_err(fail)?;
        let mut kinds = vec![read_kind_text(&first_status)];
        for _ in 1..start_count {
            damaged = damaged.start_again().map_err(fail)?;
            let status = damaged.read_status().map_err(fail)?;
            kinds.push(read_kind_text(&status));
        }

        prop_assert_eq!(kinds.len(), start_count);
        for kind in &kinds {
            prop_assert_eq!(kind, RECORD_DAMAGED_KIND);
        }
    }

    #[test]
    fn test_find_or_create_server_secret_property_the_problem_names_the_secret(
        damaged_bytes in damaged_hosted_bytes_strategy(),
    ) {
        let damaged =
            start_with_file_bytes(PEER_SECRET_FILE_NAME, &damaged_bytes)
                .map_err(fail)?;

        let status = damaged.read_status().map_err(fail)?;
        let problem = read_problem_text(&status);

        prop_assert!(problem.contains(PEER_SECRET_TEXT), "{problem}");
    }

    #[test]
    fn test_bind_on_remembered_port_property_damage_offers_set_up(
        damaged_bytes in damaged_hosted_bytes_strategy(),
    ) {
        let damaged =
            start_with_file_bytes(PEER_PORT_FILE_NAME, &damaged_bytes)
                .map_err(fail)?;

        let status = damaged.read_status().map_err(fail)?;

        prop_assert_eq!(read_kind_text(&status), RECORD_DAMAGED_KIND);
    }

    #[test]
    fn test_bind_on_remembered_port_property_a_damaged_record_is_kept(
        damaged_bytes in damaged_hosted_bytes_strategy(),
    ) {
        let damaged =
            start_with_file_bytes(PEER_PORT_FILE_NAME, &damaged_bytes)
                .map_err(fail)?;

        let status = damaged.read_status().map_err(fail)?;
        let record_after =
            fs::read(damaged.path_of(PEER_PORT_FILE_NAME)).map_err(fail)?;

        prop_assert_eq!(read_kind_text(&status), RECORD_DAMAGED_KIND);
        prop_assert_eq!(record_after, damaged_bytes);
    }

    #[test]
    fn test_bind_on_remembered_port_property_a_whole_record_still_hosts(
        remembered_port in LOWEST_REMEMBERED_PORT..HIGHEST_REMEMBERED_PORT,
    ) {
        let record = json!({ "port": remembered_port }).to_string();
        let started =
            start_with_file_bytes(PEER_PORT_FILE_NAME, record.as_bytes())
                .map_err(fail)?;

        let status = started.read_status().map_err(fail)?;

        prop_assert_eq!(&status["hosting_problem"], &Value::Null);
        prop_assert_eq!(&status["hosting_problem_kind"], &Value::Null);
        let hosted_address = &status["hosted_server_address"];
        prop_assert!(hosted_address.is_string(), "{}", status);
    }
}
