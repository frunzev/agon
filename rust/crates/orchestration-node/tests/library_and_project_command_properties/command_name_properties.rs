use proptest::prelude::*;

use crate::command_name_checks::{
    NAME_CASES, check_listed_once, check_reaches_its_parser, check_spelling,
    select_name,
};

const ITEM_DRAFT_NAMES: [&str; 2] = ["draft_item", "item_draft_status"];
const LIBRARY_NAMES: [&str; 6] = [
    "list_skills",
    "create_skill",
    "list_rules",
    "create_rule",
    "set_rule_enabled",
    "show_agents_markdown",
];
const LIBRARY_EDIT_NAMES: [&str; 5] = [
    "update_skill",
    "delete_skill",
    "undo_skill_change",
    "update_rule",
    "delete_rule",
];
const LIVE_NAMES: [&str; 2] = ["watch_run", "stop_watching_run"];
const PAIRING_NAMES: [&str; 7] = [
    "start_pairing",
    "pairing_request",
    "approve_pairing",
    "reject_pairing",
    "cancel_pairing",
    "join_with_code",
    "join_status",
];
const PROJECT_NAMES: [&str; 7] = [
    "list_projects",
    "create_project",
    "list_repositories",
    "create_repository",
    "remove_repository",
    "check_local_folder",
    "create_local_folder",
];
const PROTECTED_FILES_NAMES: [&str; 2] =
    ["set_protected_files", "reset_protected_files"];

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NAME_CASES))]

    #[test]
    fn test_item_draft_command_names_property_each_name_is_listed_once(
        name in select_name(&ITEM_DRAFT_NAMES),
    ) {
        check_listed_once(name)?;
    }

    #[test]
    fn test_item_draft_command_names_property_each_name_reaches_its_parser(
        name in select_name(&ITEM_DRAFT_NAMES),
    ) {
        check_reaches_its_parser(name)?;
    }

    #[test]
    fn test_item_draft_command_names_property_only_snake_case_is_known(
        name in select_name(&ITEM_DRAFT_NAMES),
    ) {
        check_spelling(name)?;
    }

    #[test]
    fn test_library_command_names_property_each_name_is_listed_once(
        name in select_name(&LIBRARY_NAMES),
    ) {
        check_listed_once(name)?;
    }

    #[test]
    fn test_library_command_names_property_each_name_reaches_its_parser(
        name in select_name(&LIBRARY_NAMES),
    ) {
        check_reaches_its_parser(name)?;
    }

    #[test]
    fn test_library_command_names_property_only_snake_case_is_known(
        name in select_name(&LIBRARY_NAMES),
    ) {
        check_spelling(name)?;
    }

    #[test]
    fn test_library_edit_command_names_property_each_name_is_listed_once(
        name in select_name(&LIBRARY_EDIT_NAMES),
    ) {
        check_listed_once(name)?;
    }

    #[test]
    fn test_library_edit_command_names_property_each_name_reaches_its_parser(
        name in select_name(&LIBRARY_EDIT_NAMES),
    ) {
        check_reaches_its_parser(name)?;
    }

    #[test]
    fn test_library_edit_command_names_property_only_snake_case_is_known(
        name in select_name(&LIBRARY_EDIT_NAMES),
    ) {
        check_spelling(name)?;
    }

    #[test]
    fn test_live_command_names_property_each_name_is_listed_once(
        name in select_name(&LIVE_NAMES),
    ) {
        check_listed_once(name)?;
    }

    #[test]
    fn test_live_command_names_property_each_name_reaches_its_parser(
        name in select_name(&LIVE_NAMES),
    ) {
        check_reaches_its_parser(name)?;
    }

    #[test]
    fn test_live_command_names_property_only_snake_case_is_known(
        name in select_name(&LIVE_NAMES),
    ) {
        check_spelling(name)?;
    }

    #[test]
    fn test_pairing_command_names_property_each_name_is_listed_once(
        name in select_name(&PAIRING_NAMES),
    ) {
        check_listed_once(name)?;
    }

    #[test]
    fn test_pairing_command_names_property_each_name_reaches_its_parser(
        name in select_name(&PAIRING_NAMES),
    ) {
        check_reaches_its_parser(name)?;
    }

    #[test]
    fn test_pairing_command_names_property_only_snake_case_is_known(
        name in select_name(&PAIRING_NAMES),
    ) {
        check_spelling(name)?;
    }

    #[test]
    fn test_project_command_names_property_each_name_is_listed_once(
        name in select_name(&PROJECT_NAMES),
    ) {
        check_listed_once(name)?;
    }

    #[test]
    fn test_project_command_names_property_each_name_reaches_its_parser(
        name in select_name(&PROJECT_NAMES),
    ) {
        check_reaches_its_parser(name)?;
    }

    #[test]
    fn test_project_command_names_property_only_snake_case_is_known(
        name in select_name(&PROJECT_NAMES),
    ) {
        check_spelling(name)?;
    }

    #[test]
    fn test_protected_files_command_names_property_each_name_is_listed_once(
        name in select_name(&PROTECTED_FILES_NAMES),
    ) {
        check_listed_once(name)?;
    }

    #[test]
    fn test_protected_files_command_names_property_names_reach_their_parser(
        name in select_name(&PROTECTED_FILES_NAMES),
    ) {
        check_reaches_its_parser(name)?;
    }

    #[test]
    fn test_protected_files_command_names_property_only_snake_case_is_known(
        name in select_name(&PROTECTED_FILES_NAMES),
    ) {
        check_spelling(name)?;
    }
}
