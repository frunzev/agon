use orchestration_api::work::RunEvent;
use orchestration_core::device::RunnerLink;
use orchestration_core::identifiers::DeviceId;
use orchestration_core::run::{RunFailure, StepStatus};
use orchestration_node::content_sealing::{
    open_chat_message, open_log_line, seal_run_event,
};
use proptest::prelude::*;

use crate::sealing_samples::{
    SEALING_CASES, hostile_text_strategy, is_hex_only_sealed_text,
    workspace_number,
};
use crate::support::entity_strategies::{
    sample_chat_message, sample_keyring, sample_log_line, secret_text_strategy,
};
use crate::support::test_device::fail;

fn content_free_events(text: &str) -> Vec<RunEvent> {
    vec![
        RunEvent::StepStatusChanged {
            step_name: text.to_owned(),
            status: StepStatus::Running,
        },
        RunEvent::SessionStarted {
            session: text.to_owned(),
        },
        RunEvent::WorktreeCreated {
            branch: text.to_owned(),
        },
        RunEvent::LinkChanged {
            link: RunnerLink::Direct,
        },
        RunEvent::Failed {
            failure: RunFailure {
                step_name: text.to_owned(),
                runner: Some(DeviceId(text.to_owned())),
                reason: text.to_owned(),
                retry_runs_on_same_runner: true,
            },
        },
        RunEvent::Finished,
    ]
}

fn content_events(text: &str) -> Vec<RunEvent> {
    vec![
        RunEvent::LogAppended {
            line: sample_log_line(text),
        },
        RunEvent::ChatAppended {
            message: sample_chat_message(text),
        },
        RunEvent::StepResultRecorded {
            step_name: "build".to_owned(),
            result: text.to_owned(),
            outcome: Some("approved".to_owned()),
        },
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALING_CASES))]

    #[test]
    fn test_seal_run_event_property_content_free_events_pass_unchanged(
        text in hostile_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(9)).map_err(fail)?;

        for event in content_free_events(&text) {
            let sealed = seal_run_event(&workspace_key, &event).map_err(fail)?;
            prop_assert_eq!(sealed, event);
        }
    }

    #[test]
    fn test_seal_run_event_property_sealed_content_opens_back(
        text in hostile_text_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(9)).map_err(fail)?;
        let log_event = RunEvent::LogAppended {
            line: sample_log_line(&text),
        };
        let chat_event = RunEvent::ChatAppended {
            message: sample_chat_message(&text),
        };

        let sealed_log =
            seal_run_event(&workspace_key, &log_event).map_err(fail)?;
        let sealed_chat =
            seal_run_event(&workspace_key, &chat_event).map_err(fail)?;

        let RunEvent::LogAppended { line } = sealed_log else {
            return Err(fail("the log event changed its kind"));
        };
        let RunEvent::ChatAppended { message } = sealed_chat else {
            return Err(fail("the chat event changed its kind"));
        };
        let opened_line = open_log_line(&keyring, &line).map_err(fail)?;
        let opened_message =
            open_chat_message(&keyring, &message).map_err(fail)?;
        prop_assert_eq!(opened_line, sample_log_line(&text));
        prop_assert_eq!(opened_message, sample_chat_message(&text));
    }

    #[test]
    fn test_seal_run_event_property_step_result_keeps_name_and_outcome(
        text in hostile_text_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(9)).map_err(fail)?;
        let event = RunEvent::StepResultRecorded {
            step_name: "build".to_owned(),
            result: text.clone(),
            outcome: Some("approved".to_owned()),
        };

        let sealed = seal_run_event(&workspace_key, &event).map_err(fail)?;

        let RunEvent::StepResultRecorded { step_name, result, outcome } =
            sealed
        else {
            return Err(fail("the step result event changed its kind"));
        };
        prop_assert_eq!(step_name, "build");
        prop_assert_eq!(outcome.as_deref(), Some("approved"));
        prop_assert!(is_hex_only_sealed_text(&result));
        prop_assert_eq!(keyring.open_text(&result).map_err(fail)?, text);
    }

    #[test]
    fn test_seal_run_event_property_wire_json_never_carries_the_secret(
        secret in secret_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(9)).map_err(fail)?;

        for event in content_events(&secret) {
            let sealed = seal_run_event(&workspace_key, &event).map_err(fail)?;
            let wire_json = serde_json::to_string(&sealed).map_err(fail)?;
            prop_assert!(!wire_json.contains(&secret), "{}", wire_json);
        }
    }
}
