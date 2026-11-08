use std::sync::Barrier;
use std::thread;

use orchestration_node::device_files::{DeviceFiles, HostedServerRecord};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::device_folder::{
    ACCOUNT_FILE_NAME, HOSTED_SERVER_FILE_NAME, PENDING_JOIN_FILE_NAME,
    SERVER_FILE_NAME, create_device_folder, list_file_names,
};
use crate::path_checks::FOLDER_NAME_PATTERN;
use crate::record_strategies::{
    account_strategy, app_server_strategy, pending_join_strategy,
};
use crate::support::test_device::fail;

const CASE_COUNT: u32 = 12;
const LEAST_WRITERS: usize = 2;
const MOST_WRITERS: usize = 6;
const SAVES_PER_WRITER: usize = 20;
const DOTTED_SUFFIX_PATTERN: &str = "(\\.[a-z0-9]{1,6}){1,3}";

fn save_ports_repeatedly(
    files: &DeviceFiles,
    first_port: u16,
    start_together: &Barrier,
) -> Result<(), String> {
    start_together.wait();
    for save in 0..SAVES_PER_WRITER {
        let save_offset =
            u16::try_from(save).map_err(|error| error.to_string())?;
        let record = HostedServerRecord {
            port: first_port.wrapping_add(save_offset),
        };
        files
            .save_hosted_server(&record)
            .map_err(|error| error.to_string())?;
    }
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CASE_COUNT))]

    #[test]
    fn test_choose_temporary_path_property_parallel_saves_never_clash(
        first_ports in vec(any::<u16>(), LEAST_WRITERS..MOST_WRITERS),
    ) {
        let folder = create_device_folder()?;
        let files = DeviceFiles::open(&folder.data_path).map_err(fail)?;
        let start_together = Barrier::new(first_ports.len());

        let outcomes: Vec<Result<(), String>> = thread::scope(|scope| {
            let mut writers = Vec::new();
            for first_port in &first_ports {
                let files = &files;
                let start_together = &start_together;
                writers.push(scope.spawn(move || {
                    save_ports_repeatedly(files, *first_port, start_together)
                }));
            }
            let mut outcomes = Vec::new();
            for writer in writers {
                outcomes.push(writer.join().unwrap_or_else(|_| {
                    Err("a writer panicked".to_owned())
                }));
            }
            outcomes
        });

        for outcome in outcomes {
            prop_assert!(outcome.is_ok(), "{:?}", outcome);
        }
        prop_assert!(files.load_hosted_server().map_err(fail)?.is_some());
        let names = list_file_names(&folder.data_path)?;
        prop_assert_eq!(names, vec![HOSTED_SERVER_FILE_NAME.to_owned()]);
    }

    #[test]
    fn test_choose_temporary_path_property_stays_in_the_record_folder(
        folder_name in FOLDER_NAME_PATTERN,
        dotted_suffix in DOTTED_SUFFIX_PATTERN,
        app_server in app_server_strategy(),
    ) {
        let folder = create_device_folder()?;
        let names_around_before = list_file_names(folder.root_path())?;
        let dotted_name = format!("{folder_name}{dotted_suffix}");
        let data_path = folder.root_path().join(&dotted_name);
        let files = DeviceFiles::open(&data_path).map_err(fail)?;

        files.save_app_server(&app_server).map_err(fail)?;

        let mut expected_around = names_around_before;
        expected_around.push(dotted_name);
        expected_around.sort();
        prop_assert_eq!(list_file_names(folder.root_path())?, expected_around);
        let names_inside = list_file_names(&data_path)?;
        prop_assert_eq!(names_inside, vec![SERVER_FILE_NAME.to_owned()]);
    }

    #[test]
    fn test_choose_temporary_path_property_never_replaces_a_sibling_record(
        account in account_strategy(),
        app_servers in vec(app_server_strategy(), 1..4),
        pending_join in pending_join_strategy(),
    ) {
        let folder = create_device_folder()?;
        let files = DeviceFiles::open(&folder.data_path).map_err(fail)?;

        files.save_account(&account).map_err(fail)?;
        files.save_pending_join(&pending_join).map_err(fail)?;
        for app_server in &app_servers {
            files.save_app_server(app_server).map_err(fail)?;
        }

        prop_assert_eq!(files.load_account().map_err(fail)?, Some(account));
        let loaded_join = files.load_pending_join().map_err(fail)?;
        prop_assert_eq!(loaded_join, Some(pending_join));
        let loaded_server = files.load_app_server().map_err(fail)?;
        prop_assert_eq!(loaded_server.as_ref(), app_servers.last());
        let mut expected_names = vec![
            ACCOUNT_FILE_NAME.to_owned(),
            PENDING_JOIN_FILE_NAME.to_owned(),
            SERVER_FILE_NAME.to_owned(),
        ];
        expected_names.sort();
        prop_assert_eq!(list_file_names(&folder.data_path)?, expected_names);
    }
}
