use orchestration_api::accounts::{AccountView, SealedWorkspaceKey};
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::identifiers::WorkspaceId;
use orchestration_core::protected_files::ProtectedFiles;
use orchestration_core::workspace::Workspace;
use orchestration_node::device_files::{
    AppServerRecord, HostedServerRecord, PendingJoin,
};
use orchestration_security::pairing::PairingPublicKeys;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::{Value, json};
use uuid::Uuid;

use crate::support::file_reader_samples::{build_device, reader_shape};

const HOSTILE_TEXT_PATTERN: &str =
    "[\"\\\\{}\\[\\]\\x00-\\x1F\u{2028}\u{FEFF}\u{1F600} a-z]{1,24}";
const LONGEST_BYTES: usize = 48;
const MOST_WORKSPACES: usize = 3;
const LONGEST_LONG_TEXT: usize = 4096;

pub fn hostile_text_strategy() -> BoxedStrategy<String> {
    prop_oneof![
        Just(String::new()),
        any::<String>(),
        HOSTILE_TEXT_PATTERN,
        vec(any::<char>(), LONGEST_LONG_TEXT)
            .prop_map(|characters| characters.into_iter().collect()),
    ]
    .boxed()
}

fn bytes_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..LONGEST_BYTES)
}

pub fn pending_join_strategy() -> impl Strategy<Value = PendingJoin> {
    (
        any::<u128>(),
        hostile_text_strategy(),
        bytes_strategy(),
        (bytes_strategy(), bytes_strategy()),
        bytes_strategy(),
    )
        .prop_map(
            |(number, display_code, nonce, (signing, sealing), commitment)| {
                PendingJoin {
                    join_id: Uuid::from_u128(number),
                    display_code,
                    joiner_nonce: nonce,
                    approver: PairingPublicKeys {
                        signing_public_key: signing,
                        sealing_public_key: sealing,
                    },
                    approver_commitment: commitment,
                }
            },
        )
}

pub fn app_server_strategy() -> impl Strategy<Value = AppServerRecord> {
    hostile_text_strategy()
        .prop_map(|server_address| AppServerRecord { server_address })
}

pub fn hosted_server_strategy() -> impl Strategy<Value = HostedServerRecord> {
    any::<u16>().prop_map(|port| HostedServerRecord { port })
}

fn workspace_strategy() -> impl Strategy<Value = Workspace> {
    (
        any::<u128>(),
        hostile_text_strategy(),
        hostile_text_strategy(),
    )
        .prop_map(|(number, name, app_server_address)| Workspace {
            id: WorkspaceId(Uuid::from_u128(number)),
            name,
            app_server_address,
            approval_policy: ApprovalPolicy::default(),
            protected_files: ProtectedFiles::default(),
        })
}

fn sealed_key_strategy() -> impl Strategy<Value = SealedWorkspaceKey> {
    (any::<u128>(), bytes_strategy()).prop_map(|(number, sealed_key)| {
        SealedWorkspaceKey {
            workspace_id: WorkspaceId(Uuid::from_u128(number)),
            sealed_key,
        }
    })
}

pub fn account_strategy() -> impl Strategy<Value = AccountView> {
    (
        reader_shape(),
        1_u8..=u8::MAX,
        vec(workspace_strategy(), 0..MOST_WORKSPACES),
        vec(sealed_key_strategy(), 0..MOST_WORKSPACES),
    )
        .prop_filter_map(
            "the device is built",
            |(shape, seed, workspaces, sealed_workspace_keys)| {
                let device = build_device(shape, seed).ok()?;
                Some(AccountView {
                    device,
                    workspaces,
                    sealed_workspace_keys,
                })
            },
        )
}

pub fn wrong_shape_strategy() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(Value::Null),
        any::<i64>().prop_map(|number| json!(number)),
        any::<String>().prop_map(|text| json!(text)),
        any::<bool>().prop_map(|flag| json!(flag)),
        Just(json!([])),
        Just(json!({})),
    ]
}
