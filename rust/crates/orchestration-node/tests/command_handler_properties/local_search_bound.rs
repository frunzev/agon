use std::sync::mpsc::{self, RecvTimeoutError};
use std::thread;
use std::time::Duration;

use serde_json::Value;

use crate::support::pairing_steps::join_on_local_network;
use crate::support::test_device::TestDevice;

const SEARCH_LIMIT: Duration = Duration::from_secs(30);
const ANSWER_SLACK: Duration = Duration::from_secs(30);
const SILENT_JOIN: &str = "the join stopped without answering";

pub type LocalJoin = (TestDevice, Result<Value, String>);

pub fn join_locally_within_search_bound(
    joining: TestDevice,
    code: String,
) -> Result<LocalJoin, String> {
    let (answer_sender, answer_receiver) = mpsc::channel();
    thread::spawn(move || {
        let joined = join_on_local_network(&joining, &code);
        let _unheard_answer = answer_sender.send((joining, joined));
    });

    let allowed_time = SEARCH_LIMIT + ANSWER_SLACK;
    match answer_receiver.recv_timeout(allowed_time) {
        Ok(local_join) => Ok(local_join),
        Err(RecvTimeoutError::Disconnected) => Err(SILENT_JOIN.to_owned()),
        Err(RecvTimeoutError::Timeout) => {
            Err(format!("the search outlasted {allowed_time:?}"))
        }
    }
}
