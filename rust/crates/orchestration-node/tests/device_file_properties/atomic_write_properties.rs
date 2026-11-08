use std::fs;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;

use orchestration_node::device_files::{AppServerRecord, DeviceFiles};
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::Value;

use crate::device_folder::{
    ACCOUNT_FILE_NAME, HOSTED_SERVER_FILE_NAME, SERVER_FILE_NAME,
    create_device_folder, list_file_names, open_device_files,
};
use crate::record_strategies::{
    account_strategy, app_server_strategy, hosted_server_strategy,
};
use crate::support::test_device::fail;

const CASE_COUNT: u32 = 12;
const LEAST_SAVES: usize = 2;
const MOST_SAVES: usize = 12;
const LONG_ADDRESS_LENGTH: usize = 200_000;
const EXTRA_FIELD_PATTERN: &str = "extra_[a-z]{1,12}";

type ReaderOutcome = Result<usize, String>;

fn widen_record(app_server: &AppServerRecord) -> AppServerRecord {
    let filler = "x".repeat(LONG_ADDRESS_LENGTH);
    AppServerRecord {
        server_address: format!("{}{filler}", app_server.server_address),
    }
}

fn read_until_done(
    files: &DeviceFiles,
    allowed: &[AppServerRecord],
    is_writing: &AtomicBool,
) -> ReaderOutcome {
    let mut read_count = 0;
    while is_writing.load(Ordering::Acquire) {
        let loaded = files.load_app_server().map_err(|error| {
            format!("a load failed during saving: {error}")
        })?;
        let Some(loaded_record) = loaded else {
            return Err("a load found nothing during saving".to_owned());
        };
        if !allowed.contains(&loaded_record) {
            return Err("a load found a record nobody saved".to_owned());
        }
        read_count += 1;
    }
    Ok(read_count)
}

fn save_all(files: &DeviceFiles, records: &[AppServerRecord]) -> String {
    let mut problems = String::new();
    for record in records {
        if let Err(error) = files.save_app_server(record) {
            problems.push_str(&error.to_string());
        }
    }
    problems
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CASE_COUNT))]

    #[test]
    fn test_write_json_file_property_a_reader_never_sees_a_half_record(
        narrow_records in vec(app_server_strategy(), LEAST_SAVES..MOST_SAVES),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        let mut records = Vec::new();
        for narrow_record in &narrow_records {
            records.push(widen_record(narrow_record));
        }
        files.save_app_server(&records[0]).map_err(fail)?;
        let is_writing = AtomicBool::new(true);

        let (save_problems, reader_outcome) = thread::scope(|scope| {
            let reader = scope.spawn(|| {
                read_until_done(&files, &records, &is_writing)
            });
            let save_problems = save_all(&files, &records);
            is_writing.store(false, Ordering::Release);
            let reader_outcome = reader
                .join()
                .unwrap_or_else(|_| Err("the reader panicked".to_owned()));
            (save_problems, reader_outcome)
        });

        prop_assert_eq!(save_problems, String::new());
        prop_assert!(reader_outcome.is_ok(), "{:?}", reader_outcome);
        let names = list_file_names(&folder.data_path)?;
        prop_assert_eq!(names, vec![SERVER_FILE_NAME.to_owned()]);
    }

    #[test]
    fn test_write_json_file_property_a_failed_save_leaves_no_stray_file(
        account in account_strategy(),
        kept_content in vec(any::<u8>(), 0..64),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        let blocking_folder = folder.data_path.join(ACCOUNT_FILE_NAME);
        fs::create_dir(&blocking_folder).map_err(fail)?;
        let kept_file = blocking_folder.join(HOSTED_SERVER_FILE_NAME);
        fs::write(&kept_file, &kept_content).map_err(fail)?;

        let saved = files.save_account(&account);

        prop_assert!(saved.is_err(), "{:?}", saved);
        let names = list_file_names(&folder.data_path)?;
        prop_assert_eq!(names, vec![ACCOUNT_FILE_NAME.to_owned()]);
        prop_assert_eq!(fs::read(&kept_file).map_err(fail)?, kept_content);
    }

    #[test]
    fn test_read_json_file_property_a_folder_in_place_of_a_record_errs(
        _case in any::<u8>(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        let record_path = folder.data_path.join(HOSTED_SERVER_FILE_NAME);
        fs::create_dir(&record_path).map_err(fail)?;

        let loaded = files.load_hosted_server();

        prop_assert!(loaded.is_err(), "{:?}", loaded);
        prop_assert!(record_path.is_dir());
    }

    #[test]
    fn test_read_json_file_property_a_vanished_folder_loads_nothing(
        hosted_server in hosted_server_strategy(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        files.save_hosted_server(&hosted_server).map_err(fail)?;

        fs::remove_dir_all(&folder.data_path).map_err(fail)?;

        prop_assert!(matches!(files.load_hosted_server(), Ok(None)));
        prop_assert!(matches!(files.load_account(), Ok(None)));
        prop_assert!(matches!(files.load_pending_join(), Ok(None)));
    }

    #[test]
    fn test_read_json_file_property_unknown_fields_are_tolerated(
        app_server in app_server_strategy(),
        extra_name in EXTRA_FIELD_PATTERN,
        extra_text in any::<String>(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        let mut stored_value =
            serde_json::to_value(&app_server).map_err(fail)?;
        if let Value::Object(fields) = &mut stored_value {
            fields.insert(extra_name, Value::String(extra_text));
        }
        let stored_bytes = serde_json::to_vec(&stored_value).map_err(fail)?;
        let record_path = folder.data_path.join(SERVER_FILE_NAME);
        fs::write(record_path, stored_bytes).map_err(fail)?;

        let loaded = files.load_app_server().map_err(fail)?;

        prop_assert_eq!(loaded, Some(app_server));
    }
}

#[cfg(unix)]
mod linked_records {
    use proptest::prelude::*;

    use crate::device_folder::{
        SERVER_FILE_NAME, create_device_folder, link_to_outside_file,
        open_device_files,
    };
    use crate::record_strategies::app_server_strategy;
    use crate::support::test_device::fail;

    proptest! {
        #[test]
        fn test_write_json_file_property_a_link_never_writes_outside(
            app_server in app_server_strategy(),
            outside_content in proptest::collection::vec(any::<u8>(), 0..64),
        ) {
            let folder = create_device_folder()?;
            let files = open_device_files(&folder)?;
            let outside_file = link_to_outside_file(
                &folder,
                SERVER_FILE_NAME,
                &outside_content,
            )?;

            files.save_app_server(&app_server).map_err(fail)?;

            let kept = std::fs::read(&outside_file).map_err(fail)?;
            prop_assert_eq!(kept, outside_content);
            let loaded = files.load_app_server().map_err(fail)?;
            prop_assert_eq!(loaded, Some(app_server));
        }
    }
}
