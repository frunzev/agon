use proptest::prelude::*;
use serde_json::{Value, json};

use crate::command_shapes::FILE_SHAPES;
use crate::file_questions::{
    ADDRESS_PATTERN, FILE_LISTING_NAMES, file_command_strategy, file_question,
    list_branches, read_project_address,
};
use crate::handler_desk::{
    HANDLER_CASES, INVALID_ARGUMENTS_START, NO_ACCOUNT_KIND,
    NO_ACCOUNT_PROBLEM, read_error_kind, read_own_device_id, read_problem,
    read_reply_problem, shared_fresh_device, shared_workspace,
    uuid_text_strategy,
};
use crate::shape_checks::shape_strategy;
use crate::support::test_device::fail;

const HOSTILE_FOLDER_PATTERN: &str = concat!(
    "/[a-z]{0,6}",
    "|([a-z]{1,4}/)?\\.\\.(/[a-z]{1,4})?",
    "|[a-z]{1,4}[\\\\\t\n][a-z]{0,4}",
);
const EMPTY_FILE_PATHS: [&str; 4] = ["", ".", "./", "a/.."];
const RUNNER_TEXT_PATTERN: &str = "\\PC{1,16}";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HANDLER_CASES))]

    #[test]
    fn test_handle_file_command_property_no_account_names_its_kind(
        shape in shape_strategy(&FILE_SHAPES),
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&shape.build_command());

        prop_assert_eq!(read_reply_problem(&reply), NO_ACCOUNT_PROBLEM);
        prop_assert_eq!(read_error_kind(&reply), Some(NO_ACCOUNT_KIND));
    }

    #[test]
    fn test_handle_file_command_property_hostile_folders_are_refused_first(
        folder in HOSTILE_FOLDER_PATTERN,
        project_id in uuid_text_strategy(),
    ) {
        let device = shared_fresh_device()?;
        let mut question =
            file_question(FILE_LISTING_NAMES[0], &project_id, "a", "runner");
        question["folder"] = json!(folder);

        let reply = device.send(&question);

        let problem = read_reply_problem(&reply);
        prop_assert!(!problem.is_empty());
        let is_argument_refusal = problem.starts_with(INVALID_ARGUMENTS_START);
        prop_assert!(!is_argument_refusal, "{}", problem);
        prop_assert_ne!(problem, NO_ACCOUNT_PROBLEM);
        prop_assert_eq!(read_error_kind(&reply), None);
    }

    #[test]
    fn test_handle_file_command_property_hostile_paths_are_refused_first(
        path in prop_oneof![
            HOSTILE_FOLDER_PATTERN.boxed(),
            prop::sample::select(EMPTY_FILE_PATHS.to_vec())
                .prop_map(str::to_owned)
                .boxed(),
        ],
        project_id in uuid_text_strategy(),
    ) {
        let device = shared_fresh_device()?;
        let mut question =
            file_question(FILE_LISTING_NAMES[1], &project_id, "a", "runner");
        question["path"] = json!(path);

        let reply = device.send(&question);

        let problem = read_reply_problem(&reply);
        prop_assert!(!problem.is_empty());
        let is_argument_refusal = problem.starts_with(INVALID_ARGUMENTS_START);
        prop_assert!(!is_argument_refusal, "{}", problem);
        prop_assert_ne!(problem, NO_ACCOUNT_PROBLEM);
        prop_assert_eq!(read_error_kind(&reply), None);
    }

    #[test]
    fn test_list_repository_branches_property_an_unknown_project_is_named(
        project_id in uuid_text_strategy(),
    ) {
        let prepared = shared_workspace()?;
        let project_address = read_project_address(prepared)?;

        let problem = read_problem(prepared.device.run(&list_branches(
            &project_id,
            &project_address,
            &Value::Null,
        )));

        let expected = format!("project {project_id} was not found");
        prop_assert_eq!(problem, expected);
    }

    #[test]
    fn test_list_repository_branches_property_a_foreign_address_is_named(
        address in ADDRESS_PATTERN,
    ) {
        let prepared = shared_workspace()?;

        let problem = read_problem(prepared.device.run(&list_branches(
            &prepared.project_id,
            &address,
            &Value::Null,
        )));

        let expected =
            format!("the repository {address} is not part of the project");
        prop_assert_eq!(problem, expected);
    }

    #[test]
    fn test_list_repository_branches_property_no_holder_means_unavailable(
        preferred in prop::option::of("[a-z0-9-]{1,12}"),
    ) {
        let prepared = shared_workspace()?;
        let project_address = read_project_address(prepared)?;

        let source = prepared
            .device
            .run(&list_branches(
                &prepared.project_id,
                &project_address,
                &json!(preferred),
            ))
            .map_err(fail)?;

        let unavailable = json!({ "kind": "unavailable", "holders": [] });
        prop_assert_eq!(source, unavailable);
    }

    #[test]
    fn test_ask_runner_property_an_unknown_runner_is_named(
        command in file_command_strategy(),
        runner_id in RUNNER_TEXT_PATTERN,
    ) {
        let prepared = shared_workspace()?;
        let project_address = read_project_address(prepared)?;
        let own_device_id =
            read_own_device_id(&prepared.device).map_err(fail)?;
        prop_assume!(runner_id != own_device_id);

        let problem = read_problem(prepared.device.run(&file_question(
            command,
            &prepared.project_id,
            &project_address,
            &runner_id,
        )));

        prop_assert_eq!(problem, format!("runner {runner_id} was not found"));
    }

    #[test]
    fn test_ask_runner_property_matches_the_whole_identifier_only(
        command in file_command_strategy(),
        extra in "[a-z0-9]{1,6}",
        cut in 1_usize..8,
    ) {
        let prepared = shared_workspace()?;
        let project_address = read_project_address(prepared)?;
        let own_device_id =
            read_own_device_id(&prepared.device).map_err(fail)?;
        let kept_length = own_device_id.len().saturating_sub(cut);
        let near_ids = [
            format!("{own_device_id}{extra}"),
            own_device_id[..kept_length].to_owned(),
        ];

        for near_id in &near_ids {
            let problem = read_problem(prepared.device.run(&file_question(
                command,
                &prepared.project_id,
                &project_address,
                near_id,
            )));
            let expected = format!("runner {near_id} was not found");
            prop_assert_eq!(problem, expected);
        }
    }

    #[test]
    fn test_ask_runner_property_this_device_is_a_known_runner(
        command in file_command_strategy(),
    ) {
        let prepared = shared_workspace()?;
        let project_address = read_project_address(prepared)?;
        let own_device_id =
            read_own_device_id(&prepared.device).map_err(fail)?;

        let problem = read_problem(prepared.device.run(&file_question(
            command,
            &prepared.project_id,
            &project_address,
            &own_device_id,
        )));

        let not_found = format!("runner {own_device_id} was not found");
        prop_assert!(!problem.is_empty());
        prop_assert_ne!(problem, not_found);
    }
}
