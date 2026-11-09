use std::sync::Arc;
use std::thread;

use orchestration_core::identifiers::DeviceId;
use orchestration_node::node::Node;
use proptest::collection::vec;
use proptest::prelude::*;
use tempfile::TempDir;

use crate::access_node::{ACCESS_CASES, open_node};
use crate::support::test_device::fail;

const MOST_CALLS: usize = 6;
const MOST_THREADS: usize = 6;

#[derive(Clone, Copy, Debug)]
enum IdentityStep {
    Create,
    Find,
    Forget,
}

fn identity_step_strategy() -> impl Strategy<Value = IdentityStep> {
    prop::sample::select(vec![
        IdentityStep::Create,
        IdentityStep::Find,
        IdentityStep::Forget,
    ])
}

fn create_device_id(node: &Node) -> Result<DeviceId, TestCaseError> {
    let identity = node.find_or_create_identity().map_err(fail)?;
    Ok(identity.device_id())
}

fn find_device_id(node: &Node) -> Result<Option<DeviceId>, TestCaseError> {
    let identity = node.find_identity().map_err(fail)?;
    Ok(identity.map(|found| found.device_id()))
}

fn create_from_threads(
    node: &Arc<Node>,
    thread_count: usize,
) -> Result<Vec<DeviceId>, TestCaseError> {
    let mut creating = Vec::new();
    for _ in 0..thread_count {
        let shared_node = Arc::clone(node);
        creating.push(thread::spawn(move || {
            shared_node
                .find_or_create_identity()
                .map(|identity| identity.device_id())
                .map_err(|problem| problem.to_string())
        }));
    }
    let mut device_ids = Vec::new();
    for handle in creating {
        let created = handle
            .join()
            .map_err(|_| TestCaseError::fail("a creating thread stopped"))?;
        device_ids.push(created.map_err(TestCaseError::fail)?);
    }
    Ok(device_ids)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ACCESS_CASES))]

    #[test]
    fn test_find_identity_property_a_fresh_node_has_none(
        call_count in 1..MOST_CALLS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        for _ in 0..call_count {
            prop_assert_eq!(find_device_id(&node)?, None);
        }
    }

    #[test]
    fn test_find_identity_property_finds_the_created_identity(
        call_count in 1..MOST_CALLS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        let created = create_device_id(&node)?;
        let reopened = open_node(&data_directory).map_err(fail)?;

        for _ in 0..call_count {
            prop_assert_eq!(find_device_id(&node)?, Some(created.clone()));
            prop_assert_eq!(find_device_id(&reopened)?, Some(created.clone()));
        }
    }

    #[test]
    fn test_find_identity_property_forgetting_leaves_none(
        create_first in any::<bool>(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        if create_first {
            create_device_id(&node)?;
        }

        node.forget_identity().map_err(fail)?;

        prop_assert_eq!(find_device_id(&node)?, None);
        let reopened = open_node(&data_directory).map_err(fail)?;
        prop_assert_eq!(find_device_id(&reopened)?, None);
    }

    #[test]
    fn test_find_or_create_identity_property_repeats_give_one_identity(
        call_count in 1..MOST_CALLS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        let first = create_device_id(&node)?;
        for _ in 1..call_count {
            prop_assert_eq!(create_device_id(&node)?, first.clone());
        }
    }

    #[test]
    fn test_find_or_create_identity_property_reopening_keeps_it(
        reopen_count in 1..MOST_CALLS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let first_node = open_node(&data_directory).map_err(fail)?;
        let first = create_device_id(&first_node)?;

        for _ in 0..reopen_count {
            let reopened = open_node(&data_directory).map_err(fail)?;
            prop_assert_eq!(create_device_id(&reopened)?, first.clone());
        }
    }

    #[test]
    fn test_find_or_create_identity_property_separate_folders_differ(
        folder_count in 2..MOST_CALLS,
    ) {
        let mut device_ids = Vec::new();
        let mut folders = Vec::new();
        for _ in 0..folder_count {
            let data_directory = TempDir::new().map_err(fail)?;
            let node = open_node(&data_directory).map_err(fail)?;
            device_ids.push(create_device_id(&node)?);
            folders.push(data_directory);
        }

        let mut unique_ids = device_ids.clone();
        unique_ids.sort_by(|first, second| first.0.cmp(&second.0));
        unique_ids.dedup();
        prop_assert_eq!(unique_ids.len(), device_ids.len());
    }

    #[test]
    fn test_lock_identity_property_threads_create_one_identity(
        thread_count in 2..MOST_THREADS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = Arc::new(open_node(&data_directory).map_err(fail)?);

        let device_ids = create_from_threads(&node, thread_count)?;

        let reopened = open_node(&data_directory).map_err(fail)?;
        let stored = find_device_id(&reopened)?;
        for device_id in &device_ids {
            prop_assert_eq!(Some(device_id), stored.as_ref());
        }
    }

    #[test]
    fn test_lock_identity_property_finding_threads_see_the_created_one(
        thread_count in 2..MOST_THREADS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = Arc::new(open_node(&data_directory).map_err(fail)?);

        let mut finding = Vec::new();
        for _ in 0..thread_count {
            let shared_node = Arc::clone(&node);
            finding.push(thread::spawn(move || {
                shared_node
                    .find_identity()
                    .map(|found| found.map(|identity| identity.device_id()))
                    .map_err(|problem| problem.to_string())
            }));
        }
        let created = create_device_id(&node)?;

        for handle in finding {
            let found = handle
                .join()
                .map_err(|_| TestCaseError::fail("a finding thread stopped"))?
                .map_err(TestCaseError::fail)?;
            if let Some(found_id) = found {
                prop_assert_eq!(&found_id, &created);
            }
        }
        prop_assert_eq!(find_device_id(&node)?, Some(created));
    }

    #[test]
    fn test_lock_identity_property_follows_a_model_of_steps(
        steps in vec(identity_step_strategy(), 1..12),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        let mut model: Option<DeviceId> = None;
        let mut created_ids: Vec<DeviceId> = Vec::new();
        for step in steps {
            match step {
                IdentityStep::Create => {
                    let device_id = create_device_id(&node)?;
                    if let Some(known) = &model {
                        prop_assert_eq!(&device_id, known);
                    } else {
                        prop_assert!(!created_ids.contains(&device_id));
                        created_ids.push(device_id.clone());
                    }
                    model = Some(device_id);
                }
                IdentityStep::Find => {
                    prop_assert_eq!(find_device_id(&node)?, model.clone());
                }
                IdentityStep::Forget => {
                    node.forget_identity().map_err(fail)?;
                    model = None;
                }
            }
        }
    }

    #[test]
    fn test_load_into_cache_property_an_absent_identity_is_looked_up_again(
        look_count in 1..MOST_CALLS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let looking_node = open_node(&data_directory).map_err(fail)?;
        for _ in 0..look_count {
            prop_assert_eq!(find_device_id(&looking_node)?, None);
        }

        let creating_node = open_node(&data_directory).map_err(fail)?;
        let created = create_device_id(&creating_node)?;

        prop_assert_eq!(find_device_id(&looking_node)?, Some(created));
    }

    #[test]
    fn test_load_into_cache_property_forgetting_empties_the_cache(
        create_count in 1..MOST_CALLS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        let mut device_ids = Vec::new();
        for _ in 0..create_count {
            device_ids.push(create_device_id(&node)?);
            node.forget_identity().map_err(fail)?;
            prop_assert_eq!(find_device_id(&node)?, None);
        }

        let mut unique_ids = device_ids.clone();
        unique_ids.sort_by(|first, second| first.0.cmp(&second.0));
        unique_ids.dedup();
        prop_assert_eq!(unique_ids.len(), device_ids.len());
    }

    #[test]
    fn test_load_into_cache_property_the_cache_matches_the_store(
        create_in_other in any::<bool>(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        let other = open_node(&data_directory).map_err(fail)?;
        let created = if create_in_other {
            create_device_id(&other)?
        } else {
            create_device_id(&node)?
        };

        let found = find_device_id(&node)?;
        let found_again = find_device_id(&node)?;

        prop_assert_eq!(found.as_ref(), Some(&created));
        prop_assert_eq!(found_again.as_ref(), Some(&created));
        let reopened = open_node(&data_directory).map_err(fail)?;
        prop_assert_eq!(find_device_id(&reopened)?, Some(created));
    }
}
