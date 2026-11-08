use orchestration_node::device_files::PendingJoin;
use orchestration_security::pairing::PairingPublicKeys;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::device_folder::{create_device_folder, open_device_files};
use crate::record_strategies::pending_join_strategy;
use crate::support::test_device::fail;

const SHOWN_FIELDS: [&str; 2] = ["display_code", "join_id"];
const LONGEST_SECRET: usize = 48;

fn secret_bytes_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..LONGEST_SECRET)
}

proptest! {
    #[test]
    fn test_pending_join_view_property_keeps_the_join_and_its_code(
        pending_join in pending_join_strategy(),
    ) {
        let view = pending_join.view();

        prop_assert_eq!(view.join_id, pending_join.join_id);
        prop_assert_eq!(view.display_code, pending_join.display_code);
    }

    #[test]
    fn test_pending_join_view_property_never_shows_the_pairing_secrets(
        pending_join in pending_join_strategy(),
    ) {
        let shown = serde_json::to_value(pending_join.view()).map_err(fail)?;

        let mut shown_fields: Vec<String> = Vec::new();
        if let Some(shown_object) = shown.as_object() {
            shown_fields.extend(shown_object.keys().cloned());
        }
        shown_fields.sort();
        prop_assert_eq!(shown_fields, SHOWN_FIELDS.to_vec());
    }

    #[test]
    fn test_pending_join_view_property_ignores_secrets_and_storage(
        pending_join in pending_join_strategy(),
        other_nonce in secret_bytes_strategy(),
        other_commitment in secret_bytes_strategy(),
        other_signing_key in secret_bytes_strategy(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        let changed_secrets = PendingJoin {
            joiner_nonce: other_nonce,
            approver_commitment: other_commitment,
            approver: PairingPublicKeys {
                signing_public_key: other_signing_key,
                sealing_public_key: Vec::new(),
            },
            ..pending_join.clone()
        };

        files.save_pending_join(&pending_join).map_err(fail)?;
        let loaded = files.load_pending_join().map_err(fail)?;

        let loaded_view = loaded.map(|loaded_join| loaded_join.view());
        prop_assert_eq!(loaded_view, Some(pending_join.view()));
        prop_assert_eq!(changed_secrets.view(), pending_join.view());
    }
}
