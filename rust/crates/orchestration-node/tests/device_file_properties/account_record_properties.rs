use orchestration_node::device_files::DeviceFiles;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::Index;

use crate::device_folder::{ACCOUNT_FILE_NAME, RECORD_FILE_NAMES};
use crate::record_checks::{
    check_half_written_file_is_refused, check_last_save_wins,
    check_only_its_file_is_written, check_round_trip,
    check_unrelated_files_load_nothing, check_wrong_shape_is_refused,
};
use crate::record_strategies::{account_strategy, wrong_shape_strategy};

const CASE_COUNT: u32 = 24;
const MOST_SAVES: usize = 4;
const LONGEST_UNRELATED_CONTENT: usize = 64;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CASE_COUNT))]

    #[test]
    fn test_save_account_property_loads_back_after_reopening(
        account in account_strategy(),
    ) {
        check_round_trip(
            DeviceFiles::save_account,
            DeviceFiles::load_account,
            &account,
        )?;
    }

    #[test]
    fn test_save_account_property_the_last_save_wins(
        accounts in vec(account_strategy(), 1..MOST_SAVES),
    ) {
        check_last_save_wins(
            DeviceFiles::save_account,
            DeviceFiles::load_account,
            &accounts,
        )?;
    }

    #[test]
    fn test_save_account_property_writes_only_its_json_file(
        account in account_strategy(),
    ) {
        check_only_its_file_is_written(
            DeviceFiles::save_account,
            &account,
            ACCOUNT_FILE_NAME,
        )?;
    }

    #[test]
    fn test_load_account_property_other_files_load_nothing(
        unrelated_name in prop::sample::select(RECORD_FILE_NAMES.to_vec()),
        unrelated_content in vec(any::<u8>(), 0..LONGEST_UNRELATED_CONTENT),
    ) {
        prop_assume!(unrelated_name != ACCOUNT_FILE_NAME);
        check_unrelated_files_load_nothing(
            DeviceFiles::load_account,
            unrelated_name,
            &unrelated_content,
        )?;
    }

    #[test]
    fn test_load_account_property_a_half_written_file_is_refused(
        account in account_strategy(),
        cut in any::<Index>(),
    ) {
        check_half_written_file_is_refused(
            DeviceFiles::load_account,
            &account,
            ACCOUNT_FILE_NAME,
            cut,
        )?;
    }

    #[test]
    fn test_load_account_property_a_wrong_shape_is_refused(
        wrong_shape in wrong_shape_strategy(),
    ) {
        check_wrong_shape_is_refused(
            DeviceFiles::load_account,
            ACCOUNT_FILE_NAME,
            &wrong_shape,
        )?;
    }
}
