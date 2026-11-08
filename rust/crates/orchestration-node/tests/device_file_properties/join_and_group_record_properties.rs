use orchestration_node::device_files::DeviceFiles;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::Index;

use crate::device_folder::{
    PENDING_JOIN_FILE_NAME, RECORD_FILE_NAMES, SERVER_GROUP_FILE_NAME,
};
use crate::record_checks::{
    check_half_written_file_is_refused, check_last_save_wins,
    check_only_its_file_is_written, check_round_trip,
    check_unrelated_files_load_nothing, check_wrong_shape_is_refused,
};
use crate::record_strategies::{pending_join_strategy, wrong_shape_strategy};
use crate::support::group_strategies::group_strategy;

const CASE_COUNT: u32 = 24;
const MOST_SAVES: usize = 4;
const LONGEST_UNRELATED_CONTENT: usize = 64;

fn unrelated_name_strategy() -> impl Strategy<Value = &'static str> {
    prop::sample::select(RECORD_FILE_NAMES.to_vec())
}

fn unrelated_content_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..LONGEST_UNRELATED_CONTENT)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CASE_COUNT))]

    #[test]
    fn test_save_pending_join_property_loads_back_after_reopening(
        pending_join in pending_join_strategy(),
    ) {
        check_round_trip(
            DeviceFiles::save_pending_join,
            DeviceFiles::load_pending_join,
            &pending_join,
        )?;
    }

    #[test]
    fn test_save_pending_join_property_the_last_save_wins(
        pending_joins in vec(pending_join_strategy(), 1..MOST_SAVES),
    ) {
        check_last_save_wins(
            DeviceFiles::save_pending_join,
            DeviceFiles::load_pending_join,
            &pending_joins,
        )?;
    }

    #[test]
    fn test_save_pending_join_property_writes_only_its_json_file(
        pending_join in pending_join_strategy(),
    ) {
        check_only_its_file_is_written(
            DeviceFiles::save_pending_join,
            &pending_join,
            PENDING_JOIN_FILE_NAME,
        )?;
    }

    #[test]
    fn test_load_pending_join_property_other_files_load_nothing(
        unrelated_name in unrelated_name_strategy(),
        unrelated_content in unrelated_content_strategy(),
    ) {
        prop_assume!(unrelated_name != PENDING_JOIN_FILE_NAME);
        check_unrelated_files_load_nothing(
            DeviceFiles::load_pending_join,
            unrelated_name,
            &unrelated_content,
        )?;
    }

    #[test]
    fn test_load_pending_join_property_a_half_written_file_is_refused(
        pending_join in pending_join_strategy(),
        cut in any::<Index>(),
    ) {
        check_half_written_file_is_refused(
            DeviceFiles::load_pending_join,
            &pending_join,
            PENDING_JOIN_FILE_NAME,
            cut,
        )?;
    }

    #[test]
    fn test_load_pending_join_property_a_wrong_shape_is_refused(
        wrong_shape in wrong_shape_strategy(),
    ) {
        check_wrong_shape_is_refused(
            DeviceFiles::load_pending_join,
            PENDING_JOIN_FILE_NAME,
            &wrong_shape,
        )?;
    }

    #[test]
    fn test_save_server_group_property_loads_back_after_reopening(
        server_group in group_strategy(),
    ) {
        check_round_trip(
            DeviceFiles::save_server_group,
            DeviceFiles::load_server_group,
            &server_group,
        )?;
    }

    #[test]
    fn test_save_server_group_property_the_last_save_wins(
        server_groups in vec(group_strategy(), 1..MOST_SAVES),
    ) {
        check_last_save_wins(
            DeviceFiles::save_server_group,
            DeviceFiles::load_server_group,
            &server_groups,
        )?;
    }

    #[test]
    fn test_save_server_group_property_writes_only_its_json_file(
        server_group in group_strategy(),
    ) {
        check_only_its_file_is_written(
            DeviceFiles::save_server_group,
            &server_group,
            SERVER_GROUP_FILE_NAME,
        )?;
    }

    #[test]
    fn test_load_server_group_property_other_files_load_nothing(
        unrelated_name in unrelated_name_strategy(),
        unrelated_content in unrelated_content_strategy(),
    ) {
        prop_assume!(unrelated_name != SERVER_GROUP_FILE_NAME);
        check_unrelated_files_load_nothing(
            DeviceFiles::load_server_group,
            unrelated_name,
            &unrelated_content,
        )?;
    }

    #[test]
    fn test_load_server_group_property_a_half_written_file_is_refused(
        server_group in group_strategy(),
        cut in any::<Index>(),
    ) {
        check_half_written_file_is_refused(
            DeviceFiles::load_server_group,
            &server_group,
            SERVER_GROUP_FILE_NAME,
            cut,
        )?;
    }

    #[test]
    fn test_load_server_group_property_a_wrong_shape_is_refused(
        wrong_shape in wrong_shape_strategy(),
    ) {
        check_wrong_shape_is_refused(
            DeviceFiles::load_server_group,
            SERVER_GROUP_FILE_NAME,
            &wrong_shape,
        )?;
    }
}
