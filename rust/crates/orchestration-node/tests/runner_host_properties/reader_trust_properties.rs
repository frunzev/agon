use orchestration_core::device::DeviceRole;
use orchestration_core::identifiers::ProjectId;
use orchestration_core::workspace::Project;
use orchestration_node::live_link_messages::RepositoryReference;
use orchestration_node::node_error::NodeError;
use orchestration_node::runner_bridge::{
    check_file_reader, check_reader_access,
};
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::claimant_samples::{describe_verdict, is_trusted_client};
use crate::support::file_reader_samples::{
    ADDRESS, READER_KEY, ReaderShape, build_device, project, reader_shape,
    reference,
};
use crate::support::test_device::fail;

const MOST_OTHER_PROJECTS: usize = 4;
const SAMPLE_PROJECT_NUMBER: u128 = 9;

fn other_project(number: u128) -> Project {
    Project {
        id: ProjectId(Uuid::from_u128(number)),
        ..project()
    }
}

fn unknown_project_reference(number: u128) -> RepositoryReference {
    RepositoryReference {
        project_id: ProjectId(Uuid::from_u128(number)),
        address: ADDRESS.to_owned(),
    }
}

fn is_other_project(number: &u128) -> bool {
    *number != SAMPLE_PROJECT_NUMBER
}

fn other_project_number() -> impl Strategy<Value = u128> {
    any::<u128>().prop_filter("not the sample project", is_other_project)
}

fn read_own_sample(shape: ReaderShape, seed: u8) -> Result<bool, String> {
    let device = build_device(shape, seed)?;
    let verdict =
        check_reader_access(&device, &[project()], &reference(ADDRESS));
    Ok(verdict.is_ok())
}

fn is_untrusted_reader(verdict: &Result<(), NodeError>) -> bool {
    matches!(verdict, Err(NodeError::UntrustedFileReader))
}

proptest! {
    #[test]
    fn test_is_trusted_client_property_follows_the_trust_rule(
        shape in reader_shape(),
        seed in 1_u8..200,
    ) {
        let is_admitted = read_own_sample(shape, seed).map_err(fail)?;

        prop_assert_eq!(is_admitted, is_trusted_client(shape));
    }

    #[test]
    fn test_is_trusted_client_property_revoked_devices_are_never_trusted(
        shape in reader_shape(),
        seed in 1_u8..200,
    ) {
        let revoked_shape = ReaderShape {
            revoked: true,
            ..shape
        };

        let is_admitted = read_own_sample(revoked_shape, seed).map_err(fail)?;

        prop_assert!(!is_admitted);
    }

    #[test]
    fn test_is_trusted_client_property_runners_are_never_trusted(
        shape in reader_shape(),
        seed in 1_u8..200,
    ) {
        let runner_shape = ReaderShape {
            role: DeviceRole::Runner,
            ..shape
        };

        let is_admitted = read_own_sample(runner_shape, seed).map_err(fail)?;

        prop_assert!(!is_admitted);
    }

    #[test]
    fn test_check_reader_access_property_other_projects_never_matter(
        shape in reader_shape(),
        seed in 1_u8..200,
        other_numbers in vec(other_project_number(), 0..=MOST_OTHER_PROJECTS),
        is_listed_first in any::<bool>(),
    ) {
        let device = build_device(shape, seed).map_err(fail)?;
        let mut projects = Vec::new();
        for number in &other_numbers {
            projects.push(other_project(*number));
        }
        if is_listed_first {
            projects.insert(0, project());
        } else {
            projects.push(project());
        }

        let alone =
            check_reader_access(&device, &[project()], &reference(ADDRESS));
        let among_others =
            check_reader_access(&device, &projects, &reference(ADDRESS));

        prop_assert_eq!(
            describe_verdict(&alone),
            describe_verdict(&among_others)
        );
    }

    #[test]
    fn test_check_reader_access_property_an_unknown_project_is_refused(
        shape in reader_shape(),
        seed in 1_u8..200,
        unknown_number in other_project_number(),
    ) {
        let device = build_device(shape, seed).map_err(fail)?;
        let unknown = unknown_project_reference(unknown_number);

        let own_verdict = check_reader_access(&device, &[project()], &unknown);
        let peer_verdict =
            check_file_reader(&[device], &[project()], &READER_KEY, &unknown);

        prop_assert!(is_untrusted_reader(&own_verdict), "{:?}", own_verdict);
        prop_assert!(is_untrusted_reader(&peer_verdict), "{:?}", peer_verdict);
    }
}
