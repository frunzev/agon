use std::collections::BTreeSet;
use std::fs;

use orchestration_node::device_files::DeviceFiles;
use orchestration_node::node_error::NodeError;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::select;
use serde_json::Value;
use tempfile::TempDir;

use crate::support::test_device::{describe, fail};

const MOST_DAMAGED_BYTES: usize = 48;
const WRONG_SHAPES: [&str; 4] = ["17", "true", "null", "{\"unexpected\":1}"];
const PARSER_WORDS: [&str; 4] = ["JSON", "line", "column", "EOF"];

type RecordLoad = fn(&DeviceFiles) -> Result<bool, NodeError>;

#[derive(Clone, Copy, Debug)]
struct NamedRecord {
    file_name: &'static str,
    plain_name: &'static str,
    load: RecordLoad,
}

fn load_account(files: &DeviceFiles) -> Result<bool, NodeError> {
    Ok(files.load_account()?.is_some())
}

fn load_server(files: &DeviceFiles) -> Result<bool, NodeError> {
    Ok(files.load_app_server()?.is_some())
}

fn load_group(files: &DeviceFiles) -> Result<bool, NodeError> {
    Ok(files.load_server_group()?.is_some())
}

fn load_hosted(files: &DeviceFiles) -> Result<bool, NodeError> {
    Ok(files.load_hosted_server()?.is_some())
}

fn load_join(files: &DeviceFiles) -> Result<bool, NodeError> {
    Ok(files.load_pending_join()?.is_some())
}

fn load_places(files: &DeviceFiles) -> Result<bool, NodeError> {
    Ok(files.load_agent_offers()?.is_some())
}

const NAMED_RECORDS: [NamedRecord; 6] = [
    NamedRecord {
        file_name: "account.json",
        plain_name: "account",
        load: load_account,
    },
    NamedRecord {
        file_name: "app-server.json",
        plain_name: "server address",
        load: load_server,
    },
    NamedRecord {
        file_name: "server-group.json",
        plain_name: "server group",
        load: load_group,
    },
    NamedRecord {
        file_name: "hosted-app-server.json",
        plain_name: "hosted server",
        load: load_hosted,
    },
    NamedRecord {
        file_name: "pending-join.json",
        plain_name: "pending join",
        load: load_join,
    },
    NamedRecord {
        file_name: "agent-place.json",
        plain_name: "agent places",
        load: load_places,
    },
];

fn named_record() -> impl Strategy<Value = NamedRecord> {
    select(NAMED_RECORDS.to_vec())
}

fn is_not_json(bytes: &[u8]) -> bool {
    serde_json::from_slice::<Value>(bytes).is_err()
}

fn undecodable_bytes() -> impl Strategy<Value = Vec<u8>> {
    let any_bytes = vec(any::<u8>(), 0..MOST_DAMAGED_BYTES);
    let any_text = "\\PC{0,40}".prop_map(String::into_bytes);
    prop_oneof![any_bytes, any_text]
        .prop_filter("not JSON", |bytes| is_not_json(bytes))
}

fn load_written(
    record: NamedRecord,
    bytes: &[u8],
) -> Result<Result<bool, NodeError>, String> {
    let folder = TempDir::new().map_err(describe)?;
    let files = DeviceFiles::open(folder.path()).map_err(describe)?;
    fs::write(folder.path().join(record.file_name), bytes)
        .map_err(describe)?;
    Ok((record.load)(&files))
}

fn expected_problem(record: NamedRecord) -> String {
    format!("the saved {} record is damaged", record.plain_name)
}

fn names_the_record(
    loaded: &Result<bool, NodeError>,
    record: NamedRecord,
) -> bool {
    matches!(
        loaded,
        Err(NodeError::DamagedRecord(name)) if *name == record.plain_name
    )
}

proptest! {
    #[test]
    fn test_read_device_record_property_undecodable_bytes_name_it(
        record in named_record(),
        bytes in undecodable_bytes(),
    ) {
        let loaded = load_written(record, &bytes).map_err(fail)?;

        prop_assert!(names_the_record(&loaded, record), "{:?}", loaded);
    }

    #[test]
    fn test_read_device_record_property_wrong_shapes_name_it(
        record in named_record(),
        shape in select(WRONG_SHAPES.to_vec()),
    ) {
        let loaded = load_written(record, shape.as_bytes()).map_err(fail)?;

        prop_assert!(names_the_record(&loaded, record), "{:?}", loaded);
    }

    #[test]
    fn test_read_device_record_property_a_missing_record_loads_nothing(
        record in named_record(),
    ) {
        let folder = TempDir::new().map_err(fail)?;
        let files = DeviceFiles::open(folder.path()).map_err(fail)?;

        let loaded = (record.load)(&files);

        prop_assert!(matches!(loaded, Ok(false)), "{:?}", loaded);
    }

    #[test]
    fn test_name_damaged_record_property_a_folder_stays_a_storage_problem(
        record in named_record(),
    ) {
        let folder = TempDir::new().map_err(fail)?;
        let files = DeviceFiles::open(folder.path()).map_err(fail)?;
        fs::create_dir(folder.path().join(record.file_name)).map_err(fail)?;

        let loaded = (record.load)(&files);

        let is_storage_problem = matches!(loaded, Err(NodeError::Storage(_)));
        prop_assert!(is_storage_problem, "{:?}", loaded);
    }

    #[test]
    fn test_name_damaged_record_property_names_are_plain_and_distinct(
        bytes in undecodable_bytes(),
    ) {
        let mut problems = BTreeSet::new();
        for record in NAMED_RECORDS {
            let loaded = load_written(record, &bytes).map_err(fail)?;
            let problem = loaded.err().map(|error| error.to_string());
            prop_assert_eq!(problem.clone(), Some(expected_problem(record)));
            problems.insert(problem);
        }

        prop_assert_eq!(problems.len(), NAMED_RECORDS.len());
    }

    #[test]
    fn test_name_damaged_record_property_hides_the_parser_detail(
        record in named_record(),
        hidden_text in "[A-Z]{12}",
    ) {
        let damaged = format!("{{\"{hidden_text}\": \"{hidden_text}");

        let loaded = load_written(record, damaged.as_bytes()).map_err(fail)?;

        let problem = loaded.err().map(|error| error.to_string());
        let problem = problem.unwrap_or_default();
        prop_assert!(!problem.contains(&hidden_text), "{}", problem);
        for word in PARSER_WORDS {
            prop_assert!(!problem.contains(word), "{}", problem);
        }
    }
}
