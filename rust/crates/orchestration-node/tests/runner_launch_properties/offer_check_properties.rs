use std::cell::RefCell;

use orchestration_node::place_offers::find_blocking_problem;
use orchestration_node::runner_bridge::{
    ImageProbeOutcome, check_offers, describe_image_problem,
    find_settings_place,
};
use orchestration_node::runner_settings::SandboxSettings;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::runner_settings_samples::sandbox_strategy;

const MOST_SANDBOXES: usize = 6;

fn outcome_strategy() -> impl Strategy<Value = ImageProbeOutcome> {
    prop_oneof![
        Just(ImageProbeOutcome::Present),
        Just(ImageProbeOutcome::Missing),
        Just(ImageProbeOutcome::EngineStopped),
        "\\PC{1,20}".prop_map(ImageProbeOutcome::EngineFailed),
    ]
}

fn answer_with(
    outcome: &ImageProbeOutcome,
) -> impl Fn(&str, &str) -> ImageProbeOutcome {
    move |_engine: &str, _image: &str| outcome.clone()
}

proptest! {
    #[test]
    fn test_check_offers_property_one_offer_per_sandbox_in_order(
        sandboxes in vec(sandbox_strategy(), 0..MOST_SANDBOXES),
        outcome in outcome_strategy(),
    ) {
        let offers = check_offers(&sandboxes, answer_with(&outcome));

        prop_assert_eq!(offers.len(), sandboxes.len());
        for (offer, sandbox) in offers.iter().zip(&sandboxes) {
            prop_assert_eq!(offer.place, find_settings_place(sandbox));
            let expected =
                describe_image_problem(sandbox, answer_with(&outcome));
            prop_assert_eq!(&offer.problem, &expected);
        }
    }

    #[test]
    fn test_check_offers_property_agrees_with_find_blocking_problem(
        sandboxes in vec(sandbox_strategy(), 1..MOST_SANDBOXES),
        outcome in outcome_strategy(),
    ) {
        let offers = check_offers(&sandboxes, answer_with(&outcome));

        let blocking = find_blocking_problem(&offers);

        let nothing_works = offers.iter().all(|offer| offer.problem.is_some());
        prop_assert_eq!(blocking.is_some(), nothing_works);
        if nothing_works {
            prop_assert_eq!(blocking, offers[0].problem.clone());
        }
        let has_local = sandboxes.contains(&SandboxSettings::LocalProcess);
        if has_local {
            prop_assert_eq!(find_blocking_problem(&offers), None);
        }
    }

    #[test]
    fn test_check_offers_property_probes_each_container_once_by_its_image(
        sandboxes in vec(sandbox_strategy(), 0..MOST_SANDBOXES),
    ) {
        let probed_images = RefCell::new(Vec::new());
        let recording_probe = |_engine: &str, image: &str| {
            probed_images.borrow_mut().push(image.to_owned());
            ImageProbeOutcome::Present
        };

        let offers = check_offers(&sandboxes, recording_probe);

        let mut expected_images = Vec::new();
        for sandbox in &sandboxes {
            if let SandboxSettings::Container { image, .. } = sandbox {
                expected_images.push(image.clone());
            }
        }
        prop_assert_eq!(probed_images.into_inner(), expected_images);
        for offer in &offers {
            prop_assert_eq!(&offer.problem, &None);
        }
    }
}
