use proptest::prelude::*;

use crate::file_questions::{
    ADDRESS_PATTERN, file_command_strategy, file_question,
    read_project_address,
};
use crate::handler_desk::{
    HANDLER_CASES, read_own_device_id, read_problem, shared_workspace,
    uuid_text_strategy,
};
use crate::support::test_device::fail;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HANDLER_CASES))]

    #[test]
    fn test_ask_holder_for_files_property_own_copy_refusal_is_steady(
        command in file_command_strategy(),
        repeat_count in 2_usize..4,
    ) {
        let prepared = shared_workspace()?;
        let project_address = read_project_address(prepared)?;
        let own_device_id =
            read_own_device_id(&prepared.device).map_err(fail)?;
        let question = file_question(
            command,
            &prepared.project_id,
            &project_address,
            &own_device_id,
        );
        let first = prepared.device.run(&question);

        for _ in 1..repeat_count {
            prop_assert_eq!(prepared.device.run(&question), first.clone());
        }
        prop_assert!(first.is_err());
    }

    #[test]
    fn test_ask_holder_for_files_property_own_copy_checks_the_project(
        command in file_command_strategy(),
        address in ADDRESS_PATTERN,
    ) {
        let prepared = shared_workspace()?;
        let own_device_id =
            read_own_device_id(&prepared.device).map_err(fail)?;

        let problem = read_problem(prepared.device.run(&file_question(
            command,
            &prepared.project_id,
            &address,
            &own_device_id,
        )));

        let expected =
            format!("the repository {address} is not part of the project");
        prop_assert_eq!(problem, expected);
    }

    #[test]
    fn test_ask_holder_for_files_property_own_copy_needs_a_known_project(
        command in file_command_strategy(),
        project_id in uuid_text_strategy(),
    ) {
        let prepared = shared_workspace()?;
        let project_address = read_project_address(prepared)?;
        let own_device_id =
            read_own_device_id(&prepared.device).map_err(fail)?;

        let problem = read_problem(prepared.device.run(&file_question(
            command,
            &project_id,
            &project_address,
            &own_device_id,
        )));

        let expected = format!("project {project_id} was not found");
        prop_assert_eq!(problem, expected);
    }
}
