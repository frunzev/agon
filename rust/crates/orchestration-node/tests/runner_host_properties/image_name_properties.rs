use std::cell::RefCell;

use orchestration_hub::sandbox::ensure_valid_image;
use orchestration_node::runner_bridge::{
    ImageProbeOutcome, describe_image_problem,
};
use orchestration_node::runner_settings::{
    ContainerEngineChoice, SandboxSettings,
};
use proptest::prelude::*;
use proptest::sample::select;

const VALID_IMAGE_PATTERN: &str = "[a-z][a-z0-9./-]{0,20}:[a-z0-9.]{1,8}";
const DOCKER_NAME: &str = "Docker";
const PODMAN_NAME: &str = "Podman";

fn any_engine() -> impl Strategy<Value = ContainerEngineChoice> {
    select(vec![
        ContainerEngineChoice::Docker,
        ContainerEngineChoice::Podman,
    ])
}

fn any_outcome() -> impl Strategy<Value = ImageProbeOutcome> {
    prop_oneof![
        Just(ImageProbeOutcome::Present),
        Just(ImageProbeOutcome::Missing),
        Just(ImageProbeOutcome::EngineStopped),
        "\\PC{1,20}".prop_map(ImageProbeOutcome::EngineFailed),
    ]
}

fn engine_trouble() -> impl Strategy<Value = ImageProbeOutcome> {
    prop_oneof![
        Just(ImageProbeOutcome::EngineStopped),
        "[a-z ]{1,20}".prop_map(ImageProbeOutcome::EngineFailed),
    ]
}

fn refused_image() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(String::new()),
        "-[a-z-]{0,12}",
        "[a-z]{0,6}[ \\t\\n\u{a0}\u{3000}][a-z:]{0,6}",
    ]
}

fn any_image_text() -> impl Strategy<Value = String> {
    prop_oneof![VALID_IMAGE_PATTERN, refused_image(), "\\PC{0,16}"]
}

fn container(engine: ContainerEngineChoice, image: &str) -> SandboxSettings {
    SandboxSettings::Container {
        engine,
        image: image.to_owned(),
        allowed_hosts: Vec::new(),
    }
}

fn other_engine(engine: ContainerEngineChoice) -> ContainerEngineChoice {
    match engine {
        ContainerEngineChoice::Docker => ContainerEngineChoice::Podman,
        ContainerEngineChoice::Podman => ContainerEngineChoice::Docker,
    }
}

fn shown_name(engine: ContainerEngineChoice) -> &'static str {
    match engine {
        ContainerEngineChoice::Docker => DOCKER_NAME,
        ContainerEngineChoice::Podman => PODMAN_NAME,
    }
}

fn probe_and_record(
    engine: ContainerEngineChoice,
    image: &str,
    outcome: &ImageProbeOutcome,
) -> (Option<String>, Vec<String>) {
    let asked_programs = RefCell::new(Vec::new());
    let problem = describe_image_problem(
        &container(engine, image),
        |engine_program: &str, _image: &str| {
            asked_programs.borrow_mut().push(engine_program.to_owned());
            outcome.clone()
        },
    );
    (problem, asked_programs.into_inner())
}

proptest! {
    #[test]
    fn test_describe_image_problem_property_refused_names_are_never_probed(
        engine in any_engine(),
        image in refused_image(),
        outcome in any_outcome(),
    ) {
        let (problem, asked_programs) =
            probe_and_record(engine, &image, &outcome);

        let expected = format!("The runner image name {image:?} is not valid");
        prop_assert_eq!(problem, Some(expected));
        prop_assert!(asked_programs.is_empty(), "{:?}", asked_programs);
    }

    #[test]
    fn test_describe_image_problem_property_agrees_with_the_sandbox_rule(
        engine in any_engine(),
        image in any_image_text(),
    ) {
        let (problem, _asked_programs) =
            probe_and_record(engine, &image, &ImageProbeOutcome::Present);

        let is_accepted_by_sandbox = ensure_valid_image(&image).is_ok();
        let is_accepted_by_check = problem.is_none();
        prop_assert_eq!(is_accepted_by_check, is_accepted_by_sandbox);
    }

    #[test]
    fn test_describe_image_problem_property_a_missing_image_reads_alike(
        image in VALID_IMAGE_PATTERN,
    ) {
        let missing = ImageProbeOutcome::Missing;

        let (by_docker, _docker_programs) =
            probe_and_record(ContainerEngineChoice::Docker, &image, &missing);
        let (by_podman, _podman_programs) =
            probe_and_record(ContainerEngineChoice::Podman, &image, &missing);

        prop_assert_eq!(&by_docker, &by_podman);
        let problem = by_docker.unwrap_or_default();
        prop_assert!(problem.contains(&image), "{}", problem);
    }

    #[test]
    fn test_name_engine_program_property_probes_the_chosen_engine_once(
        engine in any_engine(),
        image in VALID_IMAGE_PATTERN,
        outcome in any_outcome(),
    ) {
        let (_problem, asked_programs) =
            probe_and_record(engine, &image, &outcome);

        let expected = shown_name(engine).to_lowercase();
        prop_assert_eq!(asked_programs, vec![expected]);
    }

    #[test]
    fn test_name_engine_program_property_engines_use_their_own_program(
        image in VALID_IMAGE_PATTERN,
        outcome in any_outcome(),
    ) {
        let (_docker_problem, docker_programs) = probe_and_record(
            ContainerEngineChoice::Docker,
            &image,
            &outcome,
        );
        let (_podman_problem, podman_programs) = probe_and_record(
            ContainerEngineChoice::Podman,
            &image,
            &outcome,
        );

        prop_assert_ne!(docker_programs, podman_programs);
    }

    #[test]
    fn test_name_engine_program_property_programs_are_bare_names(
        engine in any_engine(),
        image in VALID_IMAGE_PATTERN,
    ) {
        let (_problem, asked_programs) =
            probe_and_record(engine, &image, &ImageProbeOutcome::Present);

        for program in &asked_programs {
            let is_lowercase = program.chars().all(char::is_lowercase);
            let is_bare = !program.is_empty() && is_lowercase;
            prop_assert!(is_bare, "{}", program);
        }
    }

    #[test]
    fn test_name_engine_property_trouble_names_only_the_chosen_engine(
        engine in any_engine(),
        image in VALID_IMAGE_PATTERN,
        trouble in engine_trouble(),
    ) {
        let (problem, _asked_programs) =
            probe_and_record(engine, &image, &trouble);

        let problem = problem.unwrap_or_default();
        prop_assert!(problem.starts_with(shown_name(engine)), "{}", problem);
        let other_name = shown_name(other_engine(engine));
        prop_assert!(!problem.contains(other_name), "{}", problem);
    }

    #[test]
    fn test_name_engine_property_the_name_is_the_capitalized_program(
        engine in any_engine(),
        image in VALID_IMAGE_PATTERN,
    ) {
        let (problem, asked_programs) = probe_and_record(
            engine,
            &image,
            &ImageProbeOutcome::EngineStopped,
        );

        let problem = problem.unwrap_or_default();
        let name = problem.split(' ').next().unwrap_or_default();
        prop_assert_eq!(vec![name.to_lowercase()], asked_programs);
    }

    #[test]
    fn test_name_engine_property_messages_differ_only_by_the_name(
        image in VALID_IMAGE_PATTERN,
        trouble in engine_trouble(),
    ) {
        let (by_docker, _docker_programs) =
            probe_and_record(ContainerEngineChoice::Docker, &image, &trouble);
        let (by_podman, _podman_programs) =
            probe_and_record(ContainerEngineChoice::Podman, &image, &trouble);

        let docker_text = by_docker.unwrap_or_default();
        let renamed = docker_text.replace(DOCKER_NAME, PODMAN_NAME);
        prop_assert_eq!(Some(renamed), by_podman);
    }
}
