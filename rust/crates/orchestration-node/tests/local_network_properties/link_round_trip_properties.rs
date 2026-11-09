use orchestration_node::live_link_messages::{
    ClientMessage, FileAnswer, FileRequest, RepositoryReference,
    RunnerMessage, decode_link_message, encode_link_message,
};
use proptest::prelude::*;
use serde_json::Value;

use crate::link_message_samples::{
    LINK_CASES, client_message_strategy, file_answer_strategy,
    file_request_strategy, hostile_text_strategy, name_client_kind,
    name_runner_kind, repository_reference_strategy, runner_message_strategy,
};
use crate::support::test_device::fail;

const KIND_FIELD: &str = "kind";

fn change_places(request: &FileRequest, place: &str) -> FileRequest {
    match request.clone() {
        FileRequest::ListBranches { repository } => {
            FileRequest::ListBranches { repository }
        }
        FileRequest::ListFolder { repository, .. } => {
            FileRequest::ListFolder {
                repository,
                branch: place.to_owned(),
                folder: place.to_owned(),
            }
        }
        FileRequest::ReadFile { repository, .. } => FileRequest::ReadFile {
            repository,
            branch: place.to_owned(),
            path: place.to_owned(),
        },
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LINK_CASES))]

    #[test]
    fn test_encode_link_message_property_client_messages_round_trip(
        message in client_message_strategy(),
    ) {
        let frame = encode_link_message(&message).map_err(fail)?;

        let decoded: ClientMessage =
            decode_link_message(&frame).map_err(fail)?;

        prop_assert_eq!(decoded, message);
    }

    #[test]
    fn test_encode_link_message_property_runner_messages_round_trip(
        message in runner_message_strategy(),
    ) {
        let frame = encode_link_message(&message).map_err(fail)?;

        let decoded: RunnerMessage =
            decode_link_message(&frame).map_err(fail)?;

        prop_assert_eq!(decoded, message);
    }

    #[test]
    fn test_encode_link_message_property_names_the_kind_in_snake_case(
        client_message in client_message_strategy(),
        runner_message in runner_message_strategy(),
    ) {
        let client_frame = encode_link_message(&client_message).map_err(fail)?;
        let runner_frame = encode_link_message(&runner_message).map_err(fail)?;

        let client_json: Value =
            serde_json::from_slice(&client_frame).map_err(fail)?;
        let runner_json: Value =
            serde_json::from_slice(&runner_frame).map_err(fail)?;

        let client_kind = name_client_kind(&client_message);
        let runner_kind = name_runner_kind(&runner_message);
        prop_assert_eq!(&client_json[KIND_FIELD], &Value::from(client_kind));
        prop_assert_eq!(&runner_json[KIND_FIELD], &Value::from(runner_kind));
    }

    #[test]
    fn test_encode_link_message_property_is_the_same_utf8_every_time(
        message in runner_message_strategy(),
    ) {
        let first_frame = encode_link_message(&message).map_err(fail)?;
        let second_frame = encode_link_message(&message).map_err(fail)?;

        prop_assert!(std::str::from_utf8(&first_frame).is_ok());
        prop_assert_eq!(first_frame, second_frame);
    }

    #[test]
    fn test_file_request_repository_property_names_the_given_repository(
        repository in repository_reference_strategy(),
        branch in hostile_text_strategy(),
        place in hostile_text_strategy(),
    ) {
        let requests = [
            FileRequest::ListBranches {
                repository: repository.clone(),
            },
            FileRequest::ListFolder {
                repository: repository.clone(),
                branch: branch.clone(),
                folder: place.clone(),
            },
            FileRequest::ReadFile {
                repository: repository.clone(),
                branch,
                path: place,
            },
        ];

        for request in &requests {
            prop_assert_eq!(request.repository(), &repository);
        }
    }

    #[test]
    fn test_file_request_repository_property_survives_a_round_trip(
        request in file_request_strategy(),
    ) {
        let frame = encode_link_message(&request).map_err(fail)?;

        let decoded: FileRequest = decode_link_message(&frame).map_err(fail)?;

        prop_assert_eq!(decoded.repository(), request.repository());
    }

    #[test]
    fn test_file_request_repository_property_ignores_branch_and_place(
        request in file_request_strategy(),
        place in hostile_text_strategy(),
    ) {
        let moved = change_places(&request, &place);

        prop_assert_eq!(moved.repository(), request.repository());
    }

    #[test]
    fn test_file_answer_deserialize_property_round_trips_alone(
        answer in file_answer_strategy(),
    ) {
        let frame = encode_link_message(&answer).map_err(fail)?;

        let decoded: FileAnswer = decode_link_message(&frame).map_err(fail)?;

        prop_assert_eq!(decoded, answer);
    }

    #[test]
    fn test_repository_reference_deserialize_property_round_trips_alone(
        repository in repository_reference_strategy(),
    ) {
        let frame = encode_link_message(&repository).map_err(fail)?;

        let decoded: RepositoryReference =
            decode_link_message(&frame).map_err(fail)?;

        prop_assert_eq!(decoded, repository);
    }
}
