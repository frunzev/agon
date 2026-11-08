use proptest::prelude::*;

use crate::command_shapes::{
    AGENT_LOGIN_SHAPES, AGENT_PLACE_SHAPES, APPROVAL_SHAPES, DELETION_SHAPES,
    DEVICE_SHAPES, FILE_SHAPES,
};
use crate::handler_desk::HANDLER_CASES;
use crate::shape_checks::{
    check_dart_command_is_accepted, check_missing_field_is_refused,
    check_mistyped_field_is_refused, check_stray_field_is_refused,
    dart_command_strategy, shape_strategy, stray_field_strategy,
};
use crate::support::command_strategies::arbitrary_json;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HANDLER_CASES))]

    #[test]
    fn test_agent_login_command_property_accepts_the_dart_shapes(
        command in dart_command_strategy(&AGENT_LOGIN_SHAPES),
    ) {
        check_dart_command_is_accepted(&command)?;
    }

    #[test]
    fn test_agent_login_command_property_refuses_a_missing_field(
        shape in shape_strategy(&AGENT_LOGIN_SHAPES),
        chosen in any::<prop::sample::Index>(),
    ) {
        check_missing_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_agent_login_command_property_refuses_a_stray_field_anywhere(
        (shape, stray_field) in shape_strategy(&AGENT_LOGIN_SHAPES)
            .prop_flat_map(|shape| (Just(shape), stray_field_strategy(shape))),
        stray_value in arbitrary_json(),
    ) {
        check_stray_field_is_refused(shape, &stray_field, stray_value)?;
    }

    #[test]
    fn test_agent_login_command_property_refuses_a_mistyped_field(
        shape in shape_strategy(&AGENT_LOGIN_SHAPES),
        chosen in any::<prop::sample::Index>(),
    ) {
        check_mistyped_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_agent_place_command_property_accepts_the_dart_shapes(
        command in dart_command_strategy(&AGENT_PLACE_SHAPES),
    ) {
        check_dart_command_is_accepted(&command)?;
    }

    #[test]
    fn test_agent_place_command_property_refuses_a_missing_field(
        shape in shape_strategy(&AGENT_PLACE_SHAPES),
        chosen in any::<prop::sample::Index>(),
    ) {
        check_missing_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_agent_place_command_property_refuses_a_stray_field_anywhere(
        (shape, stray_field) in shape_strategy(&AGENT_PLACE_SHAPES)
            .prop_flat_map(|shape| (Just(shape), stray_field_strategy(shape))),
        stray_value in arbitrary_json(),
    ) {
        check_stray_field_is_refused(shape, &stray_field, stray_value)?;
    }

    #[test]
    fn test_agent_place_command_property_refuses_a_mistyped_field(
        shape in shape_strategy(&AGENT_PLACE_SHAPES),
        chosen in any::<prop::sample::Index>(),
    ) {
        check_mistyped_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_approval_command_property_accepts_the_dart_shapes(
        command in dart_command_strategy(&APPROVAL_SHAPES),
    ) {
        check_dart_command_is_accepted(&command)?;
    }

    #[test]
    fn test_approval_command_property_refuses_a_missing_field(
        shape in shape_strategy(&APPROVAL_SHAPES),
        chosen in any::<prop::sample::Index>(),
    ) {
        check_missing_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_approval_command_property_refuses_a_stray_field_anywhere(
        (shape, stray_field) in shape_strategy(&APPROVAL_SHAPES)
            .prop_flat_map(|shape| (Just(shape), stray_field_strategy(shape))),
        stray_value in arbitrary_json(),
    ) {
        check_stray_field_is_refused(shape, &stray_field, stray_value)?;
    }

    #[test]
    fn test_approval_command_property_refuses_a_mistyped_field(
        shape in shape_strategy(&APPROVAL_SHAPES),
        chosen in any::<prop::sample::Index>(),
    ) {
        check_mistyped_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_deletion_command_property_accepts_the_dart_shapes(
        command in dart_command_strategy(&DELETION_SHAPES),
    ) {
        check_dart_command_is_accepted(&command)?;
    }

    #[test]
    fn test_deletion_command_property_refuses_a_missing_field(
        shape in shape_strategy(&DELETION_SHAPES),
        chosen in any::<prop::sample::Index>(),
    ) {
        check_missing_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_deletion_command_property_refuses_a_stray_field_anywhere(
        (shape, stray_field) in shape_strategy(&DELETION_SHAPES)
            .prop_flat_map(|shape| (Just(shape), stray_field_strategy(shape))),
        stray_value in arbitrary_json(),
    ) {
        check_stray_field_is_refused(shape, &stray_field, stray_value)?;
    }

    #[test]
    fn test_deletion_command_property_refuses_a_mistyped_field(
        shape in shape_strategy(&DELETION_SHAPES),
        chosen in any::<prop::sample::Index>(),
    ) {
        check_mistyped_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_device_command_property_accepts_the_dart_shapes(
        command in dart_command_strategy(&DEVICE_SHAPES),
    ) {
        check_dart_command_is_accepted(&command)?;
    }

    #[test]
    fn test_device_command_property_refuses_a_missing_field(
        shape in shape_strategy(&DEVICE_SHAPES),
        chosen in any::<prop::sample::Index>(),
    ) {
        check_missing_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_device_command_property_refuses_a_stray_field_anywhere(
        (shape, stray_field) in shape_strategy(&DEVICE_SHAPES)
            .prop_flat_map(|shape| (Just(shape), stray_field_strategy(shape))),
        stray_value in arbitrary_json(),
    ) {
        check_stray_field_is_refused(shape, &stray_field, stray_value)?;
    }

    #[test]
    fn test_device_command_property_refuses_a_mistyped_field(
        shape in shape_strategy(&DEVICE_SHAPES),
        chosen in any::<prop::sample::Index>(),
    ) {
        check_mistyped_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_file_command_property_accepts_the_dart_shapes(
        command in dart_command_strategy(&FILE_SHAPES),
    ) {
        check_dart_command_is_accepted(&command)?;
    }

    #[test]
    fn test_file_command_property_refuses_a_missing_field(
        shape in shape_strategy(&FILE_SHAPES),
        chosen in any::<prop::sample::Index>(),
    ) {
        check_missing_field_is_refused(shape, chosen)?;
    }

    #[test]
    fn test_file_command_property_refuses_a_stray_field_anywhere(
        (shape, stray_field) in shape_strategy(&FILE_SHAPES)
            .prop_flat_map(|shape| (Just(shape), stray_field_strategy(shape))),
        stray_value in arbitrary_json(),
    ) {
        check_stray_field_is_refused(shape, &stray_field, stray_value)?;
    }

    #[test]
    fn test_file_command_property_refuses_a_mistyped_field(
        shape in shape_strategy(&FILE_SHAPES),
        chosen in any::<prop::sample::Index>(),
    ) {
        check_mistyped_field_is_refused(shape, chosen)?;
    }
}
