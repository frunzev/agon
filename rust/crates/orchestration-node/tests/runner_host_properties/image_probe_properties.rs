use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;

use orchestration_node::runner_bridge::ImageProbeOutcome;
use proptest::prelude::*;
use proptest::sample::select;
use tempfile::TempDir;

use crate::engine_scripts::{
    ENGINE_FILE_NAME, EngineAnswers, EngineManner, probe_within_limit,
    read_calls, read_probed_image, write_engine,
};
use crate::support::test_device::{describe, fail};

const PROBE_CASES: u32 = 12;
const INFO_CALL: &str = "info";
const IMAGE_CALL: &str = "image";
const PLAIN_IMAGE_PATTERN: &str = "[a-z][a-z0-9./-]{0,20}:[a-z0-9.]{1,8}";
const ODD_IMAGE_PATTERN: &str = "[^\\s\\-\\x00][^\\s\\x00]{0,30}";
const NOT_EXECUTABLE_MODE: u32 = 0o644;

fn program_text(engine_path: &Path) -> Result<String, String> {
    let text = engine_path.to_str().ok_or("the engine path is not text")?;
    Ok(text.to_owned())
}

fn probe_engine(
    answers: EngineAnswers,
    manner: EngineManner,
    image: &str,
) -> Result<(ImageProbeOutcome, Vec<String>, Option<String>), String> {
    let folder = TempDir::new().map_err(describe)?;
    let engine_path = write_engine(folder.path(), answers, manner)?;
    let outcome = probe_within_limit(&program_text(&engine_path)?, image)?;
    let calls = read_calls(&engine_path);
    let probed_image = read_probed_image(&engine_path);
    Ok((outcome, calls, probed_image))
}

fn expected_outcome(answers: EngineAnswers) -> ImageProbeOutcome {
    if answers.info_exit_code != 0 {
        return ImageProbeOutcome::EngineStopped;
    }
    if answers.image_exit_code != 0 {
        return ImageProbeOutcome::Missing;
    }
    ImageProbeOutcome::Present
}

fn build_answers(exit_codes: (u8, u8)) -> EngineAnswers {
    let (info_exit_code, image_exit_code) = exit_codes;
    EngineAnswers {
        info_exit_code,
        image_exit_code,
    }
}

fn answers_strategy() -> impl Strategy<Value = EngineAnswers> {
    (0_u8..=3, 0_u8..=3).prop_map(build_answers)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROBE_CASES))]

    #[test]
    fn test_probe_local_image_property_a_stopped_engine_hides_images(
        info_exit_code in 1_u8..=255,
        image_exit_code in any::<u8>(),
        image in PLAIN_IMAGE_PATTERN,
    ) {
        let answers = EngineAnswers { info_exit_code, image_exit_code };

        let (outcome, calls, probed_image) =
            probe_engine(answers, EngineManner::Plain, &image)
                .map_err(fail)?;

        prop_assert_eq!(outcome, ImageProbeOutcome::EngineStopped);
        prop_assert_eq!(calls, vec![INFO_CALL.to_owned()]);
        prop_assert_eq!(probed_image, None);
    }

    #[test]
    fn test_probe_local_image_property_the_image_answer_decides(
        image_exit_code in any::<u8>(),
        image in PLAIN_IMAGE_PATTERN,
    ) {
        let answers = EngineAnswers { info_exit_code: 0, image_exit_code };

        let (outcome, calls, probed_image) =
            probe_engine(answers, EngineManner::Plain, &image)
                .map_err(fail)?;

        prop_assert_eq!(outcome, expected_outcome(answers));
        let expected_calls = vec![INFO_CALL.to_owned(), IMAGE_CALL.to_owned()];
        prop_assert_eq!(calls, expected_calls);
        prop_assert_eq!(probed_image, Some(image));
    }

    #[test]
    fn test_probe_local_image_property_an_unrunnable_engine_fails(
        is_present in any::<bool>(),
        image in PLAIN_IMAGE_PATTERN,
    ) {
        let folder = TempDir::new().map_err(fail)?;
        let engine_path = folder.path().join(ENGINE_FILE_NAME);
        if is_present {
            fs::write(&engine_path, "#!/bin/sh\nexit 0\n").map_err(fail)?;
            let permissions = fs::Permissions::from_mode(NOT_EXECUTABLE_MODE);
            fs::set_permissions(&engine_path, permissions).map_err(fail)?;
        }
        let program = program_text(&engine_path).map_err(fail)?;

        let outcome = probe_within_limit(&program, &image).map_err(fail)?;

        let ImageProbeOutcome::EngineFailed(reason) = outcome else {
            return Err(fail(format!("not a failure: {outcome:?}")));
        };
        prop_assert!(!reason.trim().is_empty());
    }

    #[test]
    fn test_run_quietly_property_engines_read_no_input(
        answers in answers_strategy(),
        image in PLAIN_IMAGE_PATTERN,
    ) {
        let (outcome, _calls, _probed_image) =
            probe_engine(answers, EngineManner::ReadsInput, &image)
                .map_err(fail)?;

        prop_assert_eq!(outcome, expected_outcome(answers));
    }

    #[test]
    fn test_run_quietly_property_loud_engines_never_block(
        answers in answers_strategy(),
        image in PLAIN_IMAGE_PATTERN,
    ) {
        let (outcome, _calls, _probed_image) =
            probe_engine(answers, EngineManner::WritesLoudly, &image)
                .map_err(fail)?;

        prop_assert_eq!(outcome, expected_outcome(answers));
    }

    #[test]
    fn test_run_quietly_property_arguments_reach_the_engine_verbatim(
        image in prop_oneof![
            ODD_IMAGE_PATTERN,
            select(vec!["$HOME", "a;b", "`id`", "*", "\"q\"", "'s'"])
                .prop_map(str::to_owned),
        ],
    ) {
        let answers = EngineAnswers { info_exit_code: 0, image_exit_code: 0 };

        let (outcome, _calls, probed_image) =
            probe_engine(answers, EngineManner::Plain, &image)
                .map_err(fail)?;

        prop_assert_eq!(outcome, ImageProbeOutcome::Present);
        prop_assert_eq!(probed_image, Some(image));
    }
}
