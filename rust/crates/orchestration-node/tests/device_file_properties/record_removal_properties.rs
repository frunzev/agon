use std::fs;

use orchestration_api::accounts::AccountView;
use orchestration_core::agent_place::AgentPlace;
use orchestration_node::device_files::{
    AppServerRecord, DeviceFiles, HostedServerRecord, PendingJoin,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::device_folder::{
    DEVICE_RECORD_NAMES, create_device_folder, list_file_names,
    open_device_files,
};
use crate::record_strategies::{
    account_strategy, app_server_strategy, pending_join_strategy,
};
use crate::support::group_strategies::group_strategy;
use crate::support::test_device::fail;

const CASE_COUNT: u32 = 16;
const MOST_REPEATS: usize = 4;
const LONGEST_CONTENT: usize = 64;
const KEPT_FILE_NAME: &str = "kept.bin";

#[derive(Debug)]
struct SavedRecords {
    account: AccountView,
    pending_join: PendingJoin,
    app_server: AppServerRecord,
}

fn saved_records_strategy() -> impl Strategy<Value = SavedRecords> {
    (
        account_strategy(),
        pending_join_strategy(),
        app_server_strategy(),
    )
        .prop_map(|(account, pending_join, app_server)| SavedRecords {
            account,
            pending_join,
            app_server,
        })
}

fn save_records(
    files: &DeviceFiles,
    records: &SavedRecords,
) -> Result<(), TestCaseError> {
    files.save_account(&records.account).map_err(fail)?;
    files
        .save_pending_join(&records.pending_join)
        .map_err(fail)?;
    files.save_app_server(&records.app_server).map_err(fail)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CASE_COUNT))]

    #[test]
    fn test_remove_pending_join_property_only_the_join_is_forgotten(
        records in saved_records_strategy(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        save_records(&files, &records)?;

        files.remove_pending_join().map_err(fail)?;

        prop_assert_eq!(files.load_pending_join().map_err(fail)?, None);
        let loaded_account = files.load_account().map_err(fail)?;
        prop_assert_eq!(loaded_account, Some(records.account));
        let loaded_server = files.load_app_server().map_err(fail)?;
        prop_assert_eq!(loaded_server, Some(records.app_server));
    }

    #[test]
    fn test_remove_pending_join_property_repeating_it_is_harmless(
        pending_join in proptest::option::of(pending_join_strategy()),
        repeats in 1..MOST_REPEATS,
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        if let Some(pending_join) = &pending_join {
            files.save_pending_join(pending_join).map_err(fail)?;
        }

        for _ in 0..repeats {
            files.remove_pending_join().map_err(fail)?;
        }

        prop_assert_eq!(files.load_pending_join().map_err(fail)?, None);
        prop_assert!(list_file_names(&folder.data_path)?.is_empty());
    }

    #[test]
    fn test_remove_device_records_property_forgets_only_device_records(
        records in saved_records_strategy(),
        server_group in group_strategy(),
        port in any::<u16>(),
        identity_bytes in vec(any::<u8>(), 1..LONGEST_CONTENT),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        save_records(&files, &records)?;
        files.save_server_group(&server_group).map_err(fail)?;
        let hosted_server = HostedServerRecord { port };
        files.save_hosted_server(&hosted_server).map_err(fail)?;
        let offers = vec![AgentPlace::LocalProcess];
        files.save_agent_offers(&offers).map_err(fail)?;
        fs::write(files.identity_path(), &identity_bytes).map_err(fail)?;
        fs::write(files.sealed_identity_path(), &identity_bytes)
            .map_err(fail)?;
        fs::create_dir(files.repository_cache_directory()).map_err(fail)?;
        fs::create_dir(files.hosted_server_directory()).map_err(fail)?;

        files.remove_device_records().map_err(fail)?;

        prop_assert_eq!(files.load_account().map_err(fail)?, None);
        prop_assert_eq!(files.load_pending_join().map_err(fail)?, None);
        prop_assert_eq!(files.load_app_server().map_err(fail)?, None);
        prop_assert_eq!(files.load_server_group().map_err(fail)?, None);
        let kept_server = files.load_hosted_server().map_err(fail)?;
        prop_assert_eq!(kept_server, Some(hosted_server));
        let kept_offers = files.load_agent_offers().map_err(fail)?;
        prop_assert_eq!(kept_offers, Some(offers));
        let kept_identity = fs::read(files.identity_path()).map_err(fail)?;
        prop_assert_eq!(&kept_identity, &identity_bytes);
        prop_assert!(files.sealed_identity_path().is_file());
        prop_assert!(files.repository_cache_directory().is_dir());
        prop_assert!(files.hosted_server_directory().is_dir());
    }

    #[test]
    fn test_remove_device_records_property_any_subset_goes_cleanly(
        present in vec(any::<bool>(), DEVICE_RECORD_NAMES.len()),
        content in vec(any::<u8>(), 0..LONGEST_CONTENT),
        repeats in 1..MOST_REPEATS,
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        let presence = DEVICE_RECORD_NAMES.iter().zip(&present);
        for (record_name, is_present) in presence {
            if *is_present {
                fs::write(folder.data_path.join(record_name), &content)
                    .map_err(fail)?;
            }
        }

        for _ in 0..repeats {
            files.remove_device_records().map_err(fail)?;
        }

        prop_assert!(list_file_names(&folder.data_path)?.is_empty());
    }

    #[test]
    fn test_remove_file_if_present_property_a_folder_is_never_removed(
        record_name in prop::sample::select(DEVICE_RECORD_NAMES.to_vec()),
        kept_content in vec(any::<u8>(), 0..LONGEST_CONTENT),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        let blocking_folder = folder.data_path.join(record_name);
        fs::create_dir(&blocking_folder).map_err(fail)?;
        let kept_file = blocking_folder.join(KEPT_FILE_NAME);
        fs::write(&kept_file, &kept_content).map_err(fail)?;

        let removed = files.remove_device_records();

        prop_assert!(removed.is_err(), "{:?}", removed);
        prop_assert_eq!(fs::read(&kept_file).map_err(fail)?, kept_content);
    }

    #[test]
    fn test_remove_file_if_present_property_absent_files_create_nothing(
        repeats in 1..MOST_REPEATS,
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;

        for _ in 0..repeats {
            files.remove_pending_join().map_err(fail)?;
            files.remove_device_records().map_err(fail)?;
        }

        prop_assert!(list_file_names(&folder.data_path)?.is_empty());
    }
}
