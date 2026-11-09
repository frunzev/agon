use orchestration_core::device::DeviceRole;
use orchestration_node::node_error::NodeError;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::claimant_samples::{
    Claimant, MOST_CLAIMANTS, build_claimants, claim_other_key,
    claimant_strategy, describe_verdict, forge_claim, is_trusted_claim,
    read_with,
};
use crate::support::file_reader_samples::{ReaderShape, build_device};
use crate::support::test_device::fail;

const BORROWER_SEED: u8 = 200;
const LENDER_SEED: u8 = 201;

fn map_claimants(
    claimants: &[Claimant],
    change: fn(Claimant) -> Claimant,
) -> Vec<Claimant> {
    let mut changed = Vec::new();
    for claimant in claimants {
        changed.push(change(*claimant));
    }
    changed
}

fn is_untrusted_reader(verdict: &Result<(), NodeError>) -> bool {
    matches!(verdict, Err(NodeError::UntrustedFileReader))
}

proptest! {
    #[test]
    fn test_find_devices_with_peer_key_property_order_never_matters(
        claimants in vec(claimant_strategy(), 1..=MOST_CLAIMANTS),
    ) {
        let devices = build_claimants(&claimants).map_err(fail)?;
        let mut reversed_devices = devices.clone();
        reversed_devices.reverse();

        let verdict = read_with(&devices);
        let reversed_verdict = read_with(&reversed_devices);

        prop_assert_eq!(
            describe_verdict(&verdict),
            describe_verdict(&reversed_verdict)
        );
    }

    #[test]
    fn test_find_devices_with_peer_key_property_a_trusted_claim_admits(
        claimants in vec(claimant_strategy(), 1..=MOST_CLAIMANTS),
    ) {
        let devices = build_claimants(&claimants).map_err(fail)?;

        let verdict = read_with(&devices);

        let is_expected =
            claimants.iter().any(|claimant| is_trusted_claim(*claimant));
        prop_assert_eq!(verdict.is_ok(), is_expected, "{:?}", verdict);
        if verdict.is_err() {
            prop_assert!(is_untrusted_reader(&verdict), "{:?}", verdict);
        }
    }

    #[test]
    fn test_find_devices_with_peer_key_property_bystanders_never_matter(
        claimants in vec(claimant_strategy(), 1..=MOST_CLAIMANTS),
        bystanders in vec(claimant_strategy(), 1..=MOST_CLAIMANTS),
        is_crowd_first in any::<bool>(),
    ) {
        let bystanders = map_claimants(&bystanders, claim_other_key);
        let mut crowd = claimants.clone();
        if is_crowd_first {
            crowd.splice(0..0, bystanders);
        } else {
            crowd.extend(bystanders);
        }
        let devices = build_claimants(&claimants).map_err(fail)?;
        let crowd_devices = build_claimants(&crowd).map_err(fail)?;

        let verdict = read_with(&devices);
        let crowd_verdict = read_with(&crowd_devices);

        prop_assert_eq!(verdict.is_ok(), crowd_verdict.is_ok());
    }

    #[test]
    fn test_has_peer_key_property_forged_claims_never_admit(
        claimants in vec(claimant_strategy(), 1..=MOST_CLAIMANTS),
    ) {
        let forged_claimants = map_claimants(&claimants, forge_claim);
        let devices = build_claimants(&forged_claimants).map_err(fail)?;

        let verdict = read_with(&devices);

        prop_assert!(is_untrusted_reader(&verdict), "{:?}", verdict);
    }

    #[test]
    fn test_has_peer_key_property_other_keys_never_admit(
        claimants in vec(claimant_strategy(), 1..=MOST_CLAIMANTS),
    ) {
        let other_claimants = map_claimants(&claimants, claim_other_key);
        let devices = build_claimants(&other_claimants).map_err(fail)?;

        let verdict = read_with(&devices);

        prop_assert!(is_untrusted_reader(&verdict), "{:?}", verdict);
    }

    #[test]
    fn test_has_peer_key_property_a_borrowed_address_never_admits(
        role in prop_oneof![
            Just(DeviceRole::Client),
            Just(DeviceRole::ClientAndRunner),
        ],
    ) {
        let trusted_shape = ReaderShape {
            role,
            revoked: false,
            in_workspace: true,
            signs_address: true,
        };
        let lender = build_device(trusted_shape, LENDER_SEED).map_err(fail)?;
        let mut borrower =
            build_device(trusted_shape, BORROWER_SEED).map_err(fail)?;
        borrower.peer_address.clone_from(&lender.peer_address);

        let verdict = read_with(&[borrower]);

        prop_assert!(is_untrusted_reader(&verdict), "{:?}", verdict);
    }
}
