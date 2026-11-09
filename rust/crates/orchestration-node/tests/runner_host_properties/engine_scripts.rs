use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

use orchestration_node::runner_bridge::{
    ImageProbeOutcome, probe_local_image,
};

use crate::support::test_device::describe;

pub const ENGINE_FILE_NAME: &str = "engine";
pub const PROBE_LIMIT: Duration = Duration::from_secs(30);
const EXECUTABLE_MODE: u32 = 0o755;
const CALLS_SUFFIX: &str = ".calls";
const IMAGE_SUFFIX: &str = ".image";
const RECORD_CALL: &str = "printf '%s\\n' \"$1\" >> \"$0.calls\"\n";
const RECORD_IMAGE: &str = "printf '%s' \"$3\" > \"$0.image\"\n";
const READ_ALL_INPUT: &str = "cat > /dev/null\n";
const WRITE_LOUDLY: &str = "head -c 2000000 /dev/zero\n\
     head -c 2000000 /dev/zero >&2\n";

#[derive(Clone, Copy, Debug)]
pub struct EngineAnswers {
    pub info_exit_code: u8,
    pub image_exit_code: u8,
}

#[derive(Clone, Copy, Debug)]
pub enum EngineManner {
    Plain,
    ReadsInput,
    WritesLoudly,
}

fn describe_manner(manner: EngineManner) -> &'static str {
    match manner {
        EngineManner::Plain => "",
        EngineManner::ReadsInput => READ_ALL_INPUT,
        EngineManner::WritesLoudly => WRITE_LOUDLY,
    }
}

fn build_engine_script(
    answers: EngineAnswers,
    manner: EngineManner,
) -> String {
    let manner_lines = describe_manner(manner);
    let info_exit_code = answers.info_exit_code;
    let image_exit_code = answers.image_exit_code;
    format!(
        "#!/bin/sh\n{RECORD_CALL}{manner_lines}\
         if [ \"$1\" = info ]; then exit {info_exit_code}; fi\n\
         {RECORD_IMAGE}exit {image_exit_code}\n"
    )
}

pub fn write_engine(
    folder: &Path,
    answers: EngineAnswers,
    manner: EngineManner,
) -> Result<PathBuf, String> {
    let engine_path = folder.join(ENGINE_FILE_NAME);
    let script = build_engine_script(answers, manner);
    fs::write(&engine_path, script).map_err(describe)?;
    let permissions = fs::Permissions::from_mode(EXECUTABLE_MODE);
    fs::set_permissions(&engine_path, permissions).map_err(describe)?;
    Ok(engine_path)
}

fn with_suffix(engine_path: &Path, suffix: &str) -> PathBuf {
    let mut suffixed = engine_path.as_os_str().to_owned();
    suffixed.push(suffix);
    PathBuf::from(suffixed)
}

pub fn read_calls(engine_path: &Path) -> Vec<String> {
    let calls_path = with_suffix(engine_path, CALLS_SUFFIX);
    let calls_text = fs::read_to_string(calls_path).unwrap_or_default();
    let mut calls = Vec::new();
    for call in calls_text.lines() {
        calls.push(call.to_owned());
    }
    calls
}

pub fn read_probed_image(engine_path: &Path) -> Option<String> {
    fs::read_to_string(with_suffix(engine_path, IMAGE_SUFFIX)).ok()
}

fn probe_and_report(
    engine_program: &str,
    image: &str,
    sender: &mpsc::Sender<ImageProbeOutcome>,
) {
    let outcome = probe_local_image(engine_program, image);
    let _receiver_gone = sender.send(outcome);
}

pub fn probe_within_limit(
    engine_program: &str,
    image: &str,
) -> Result<ImageProbeOutcome, String> {
    let (sender, receiver) = mpsc::channel();
    let program = engine_program.to_owned();
    let probed_image = image.to_owned();
    thread::spawn(move || probe_and_report(&program, &probed_image, &sender));
    receiver.recv_timeout(PROBE_LIMIT).map_err(describe)
}
