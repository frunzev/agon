use proptest::prelude::*;
use proptest::sample::{Index, select};

use crate::dart_command_shapes::{
    check_dart_shape_reaches_the_handler, check_missing_field_is_refused,
    check_stray_field_is_refused, shape_with_stray_field,
};
use crate::dart_shape_tables::{
    RUN_SHAPES, RUNNER_SHAPES, SERVER_BACKUP_SHAPES, TASK_SHAPES,
    WORKFLOW_AGENT_SHAPES, WORKFLOW_DRAFT_SHAPES, WORKFLOW_SHAPES,
};

const SHAPE_CASES: u32 = 12;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SHAPE_CASES))]

    #[test]
    fn test_handle_run_command_property_takes_dart_shapes(
        shape in select(&RUN_SHAPES[..]),
    ) {
        check_dart_shape_reaches_the_handler(shape)?;
    }

    #[test]
    fn test_handle_run_command_property_refuses_missing_field(
        shape in select(&RUN_SHAPES[..]),
        chosen in any::<Index>(),
    ) {
        check_missing_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_handle_run_command_property_refuses_stray_field(
        (shape, stray_field) in shape_with_stray_field(&RUN_SHAPES),
    ) {
        check_stray_field_is_refused(shape, &stray_field)?;
    }

    #[test]
    fn test_handle_runner_command_property_takes_dart_shapes(
        shape in select(&RUNNER_SHAPES[..]),
    ) {
        check_dart_shape_reaches_the_handler(shape)?;
    }

    #[test]
    fn test_handle_runner_command_property_refuses_missing_field(
        shape in select(&RUNNER_SHAPES[..]),
        chosen in any::<Index>(),
    ) {
        check_missing_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_handle_runner_command_property_refuses_stray_field(
        (shape, stray_field) in shape_with_stray_field(&RUNNER_SHAPES),
    ) {
        check_stray_field_is_refused(shape, &stray_field)?;
    }

    #[test]
    fn test_handle_server_backup_command_property_takes_dart_shapes(
        shape in select(&SERVER_BACKUP_SHAPES[..]),
    ) {
        check_dart_shape_reaches_the_handler(shape)?;
    }

    #[test]
    fn test_handle_server_backup_command_property_refuses_missing_field(
        shape in select(&SERVER_BACKUP_SHAPES[..]),
        chosen in any::<Index>(),
    ) {
        check_missing_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_handle_server_backup_command_property_refuses_stray_field(
        (shape, stray_field) in shape_with_stray_field(&SERVER_BACKUP_SHAPES),
    ) {
        check_stray_field_is_refused(shape, &stray_field)?;
    }

    #[test]
    fn test_handle_task_command_property_takes_dart_shapes(
        shape in select(&TASK_SHAPES[..]),
    ) {
        check_dart_shape_reaches_the_handler(shape)?;
    }

    #[test]
    fn test_handle_task_command_property_refuses_missing_field(
        shape in select(&TASK_SHAPES[..]),
        chosen in any::<Index>(),
    ) {
        check_missing_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_handle_task_command_property_refuses_stray_field(
        (shape, stray_field) in shape_with_stray_field(&TASK_SHAPES),
    ) {
        check_stray_field_is_refused(shape, &stray_field)?;
    }

    #[test]
    fn test_handle_workflow_command_property_takes_dart_shapes(
        shape in select(&WORKFLOW_SHAPES[..]),
    ) {
        check_dart_shape_reaches_the_handler(shape)?;
    }

    #[test]
    fn test_handle_workflow_command_property_refuses_missing_field(
        shape in select(&WORKFLOW_SHAPES[..]),
        chosen in any::<Index>(),
    ) {
        check_missing_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_handle_workflow_command_property_refuses_stray_field(
        (shape, stray_field) in shape_with_stray_field(&WORKFLOW_SHAPES),
    ) {
        check_stray_field_is_refused(shape, &stray_field)?;
    }

    #[test]
    fn test_handle_workflow_agent_command_property_takes_dart_shapes(
        shape in select(&WORKFLOW_AGENT_SHAPES[..]),
    ) {
        check_dart_shape_reaches_the_handler(shape)?;
    }

    #[test]
    fn test_handle_workflow_agent_command_property_refuses_missing_field(
        shape in select(&WORKFLOW_AGENT_SHAPES[..]),
        chosen in any::<Index>(),
    ) {
        check_missing_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_handle_workflow_agent_command_property_refuses_stray_field(
        (shape, stray_field) in shape_with_stray_field(&WORKFLOW_AGENT_SHAPES),
    ) {
        check_stray_field_is_refused(shape, &stray_field)?;
    }

    #[test]
    fn test_handle_workflow_draft_command_property_takes_dart_shapes(
        shape in select(&WORKFLOW_DRAFT_SHAPES[..]),
    ) {
        check_dart_shape_reaches_the_handler(shape)?;
    }

    #[test]
    fn test_handle_workflow_draft_command_property_refuses_missing_field(
        shape in select(&WORKFLOW_DRAFT_SHAPES[..]),
        chosen in any::<Index>(),
    ) {
        check_missing_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_handle_workflow_draft_command_property_refuses_stray_field(
        (shape, stray_field) in shape_with_stray_field(&WORKFLOW_DRAFT_SHAPES),
    ) {
        check_stray_field_is_refused(shape, &stray_field)?;
    }
}
