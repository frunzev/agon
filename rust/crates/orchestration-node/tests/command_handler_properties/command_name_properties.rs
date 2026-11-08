use proptest::prelude::*;

use crate::command_shapes::{
    AGENT_LOGIN_SHAPES, AGENT_PLACE_SHAPES, APPROVAL_SHAPES, DELETION_SHAPES,
    DEVICE_SHAPES, FILE_SHAPES,
};
use crate::handler_desk::HANDLER_CASES;
use crate::name_checks::{
    AreaRefusal, check_dart_names_are_known_once,
    check_name_routes_to_its_area, check_names_are_snake_case,
};
use crate::shape_checks::shape_strategy;

const NAME_SUFFIX_PATTERN: &str = "[a-zA-Z_ ]{1,6}";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HANDLER_CASES))]

    #[test]
    fn test_agent_login_command_names_property_match_the_dart_names_once(
        _seed in any::<u8>(),
    ) {
        check_dart_names_are_known_once(&AGENT_LOGIN_SHAPES)?;
    }

    #[test]
    fn test_agent_login_command_names_property_are_snake_case(
        _seed in any::<u8>(),
    ) {
        check_names_are_snake_case(&AGENT_LOGIN_SHAPES)?;
    }

    #[test]
    fn test_agent_login_command_names_property_route_only_the_exact_name(
        shape in shape_strategy(&AGENT_LOGIN_SHAPES),
        suffix in NAME_SUFFIX_PATTERN,
    ) {
        let refusal = AreaRefusal::NotARunner;
        check_name_routes_to_its_area(shape, refusal, &suffix)?;
    }

    #[test]
    fn test_agent_place_command_names_property_match_the_dart_names_once(
        _seed in any::<u8>(),
    ) {
        check_dart_names_are_known_once(&AGENT_PLACE_SHAPES)?;
    }

    #[test]
    fn test_agent_place_command_names_property_are_snake_case(
        _seed in any::<u8>(),
    ) {
        check_names_are_snake_case(&AGENT_PLACE_SHAPES)?;
    }

    #[test]
    fn test_agent_place_command_names_property_route_only_the_exact_name(
        shape in shape_strategy(&AGENT_PLACE_SHAPES),
        suffix in NAME_SUFFIX_PATTERN,
    ) {
        let refusal = AreaRefusal::NotARunner;
        check_name_routes_to_its_area(shape, refusal, &suffix)?;
    }

    #[test]
    fn test_approval_command_names_property_match_the_dart_names_once(
        _seed in any::<u8>(),
    ) {
        check_dart_names_are_known_once(&APPROVAL_SHAPES)?;
    }

    #[test]
    fn test_approval_command_names_property_are_snake_case(
        _seed in any::<u8>(),
    ) {
        check_names_are_snake_case(&APPROVAL_SHAPES)?;
    }

    #[test]
    fn test_approval_command_names_property_route_only_the_exact_name(
        shape in shape_strategy(&APPROVAL_SHAPES),
        suffix in NAME_SUFFIX_PATTERN,
    ) {
        let refusal = AreaRefusal::NoAccount;
        check_name_routes_to_its_area(shape, refusal, &suffix)?;
    }

    #[test]
    fn test_deletion_command_names_property_match_the_dart_names_once(
        _seed in any::<u8>(),
    ) {
        check_dart_names_are_known_once(&DELETION_SHAPES)?;
    }

    #[test]
    fn test_deletion_command_names_property_are_snake_case(
        _seed in any::<u8>(),
    ) {
        check_names_are_snake_case(&DELETION_SHAPES)?;
    }

    #[test]
    fn test_deletion_command_names_property_route_only_the_exact_name(
        shape in shape_strategy(&DELETION_SHAPES),
        suffix in NAME_SUFFIX_PATTERN,
    ) {
        let refusal = AreaRefusal::NoAccount;
        check_name_routes_to_its_area(shape, refusal, &suffix)?;
    }

    #[test]
    fn test_device_command_names_property_match_the_dart_names_once(
        _seed in any::<u8>(),
    ) {
        check_dart_names_are_known_once(&DEVICE_SHAPES)?;
    }

    #[test]
    fn test_device_command_names_property_are_snake_case(
        _seed in any::<u8>(),
    ) {
        check_names_are_snake_case(&DEVICE_SHAPES)?;
    }

    #[test]
    fn test_device_command_names_property_route_only_the_exact_name(
        shape in shape_strategy(&DEVICE_SHAPES),
        suffix in NAME_SUFFIX_PATTERN,
    ) {
        let refusal = AreaRefusal::NoAccount;
        check_name_routes_to_its_area(shape, refusal, &suffix)?;
    }

    #[test]
    fn test_file_command_names_property_match_the_dart_names_once(
        _seed in any::<u8>(),
    ) {
        check_dart_names_are_known_once(&FILE_SHAPES)?;
    }

    #[test]
    fn test_file_command_names_property_are_snake_case(
        _seed in any::<u8>(),
    ) {
        check_names_are_snake_case(&FILE_SHAPES)?;
    }

    #[test]
    fn test_file_command_names_property_route_only_the_exact_name(
        shape in shape_strategy(&FILE_SHAPES),
        suffix in NAME_SUFFIX_PATTERN,
    ) {
        let refusal = AreaRefusal::NoAccount;
        check_name_routes_to_its_area(shape, refusal, &suffix)?;
    }
}
