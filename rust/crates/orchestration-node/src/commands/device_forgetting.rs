#[cfg(feature = "app-server")]
use crate::app_server_hosting::forget_hosted_app_server;
use crate::node::Node;
use crate::node_error::NodeError;

pub(super) async fn forget_this_device(node: &Node) -> Result<(), NodeError> {
    let _account_update = node.lock_account_updates().await;
    node.forget_identity()?;
    #[cfg(feature = "app-server")]
    forget_hosted_app_server(node).await?;
    node.forget_device_records()
}
