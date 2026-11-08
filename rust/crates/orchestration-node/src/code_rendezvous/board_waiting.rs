use std::time::Duration;

use orchestration_p2p::peer_error::PeerError;
use tokio::time::timeout;

use crate::node_error::NodeError;

pub const RECORD_BOARD_WAIT_LIMIT: Duration = Duration::from_secs(5);

pub async fn wait_for_record_board<Answer>(
    board_work: impl Future<Output = Result<Answer, NodeError>>,
) -> Result<Answer, NodeError> {
    let bounded_work = timeout(RECORD_BOARD_WAIT_LIMIT, board_work);
    match bounded_work.await {
        Ok(board_answer) => board_answer,
        Err(_elapsed) => Err(describe_silent_board()),
    }
}

fn describe_silent_board() -> NodeError {
    let wait_seconds = RECORD_BOARD_WAIT_LIMIT.as_secs();
    let silence = format!("no answer within {wait_seconds} seconds");
    NodeError::Rendezvous(PeerError::RecordBoardUnreachable(silence))
}
