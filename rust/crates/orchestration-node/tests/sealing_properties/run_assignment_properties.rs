use orchestration_api::work::{FollowUp, RunAssignment};
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::protected_files::ProtectedFiles;
use orchestration_node::content_sealing::{
    open_run_assignment, seal_rule, seal_skill, seal_task, seal_workflow,
};
use orchestration_security::sealing::WorkspaceKey;
use proptest::prelude::*;
use proptest::sample::Index;

use crate::run_sealing_samples::{plain_run_with_steps, seal_whole_run};
use crate::sealing_samples::{
    SEALING_CASES, foreign_keyring, hostile_texts_strategy, is_unreadable,
    tamper_sealed_text, workspace_number,
};
use crate::support::entity_strategies::{
    sample_keyring, sample_rule, sample_skill, sample_task, sample_workflow,
};
use crate::support::test_device::{describe, fail};

const TAMPERED_PART_COUNT: usize = 5;

fn plain_assignment(texts: &[String]) -> RunAssignment {
    let first_text = texts.first().cloned().unwrap_or_default();
    RunAssignment {
        step_name: "step-0".to_owned(),
        run: plain_run_with_steps(texts, texts),
        task: sample_task(&first_text),
        workspace_id: workspace_number(10),
        workspace_approval_policy: ApprovalPolicy::NeverAsk,
        project: None,
        workflow: Some(sample_workflow(texts)),
        skills: vec![sample_skill(&first_text)],
        rules: vec![sample_rule(&first_text)],
        follow_up: Some(FollowUp {
            answered_user_messages: texts.len(),
        }),
        protected_files: ProtectedFiles::default(),
    }
}

fn seal_assignment(
    workspace_key: &WorkspaceKey,
    assignment: &RunAssignment,
) -> Result<RunAssignment, String> {
    let mut sealed = assignment.clone();
    sealed.run = seal_whole_run(workspace_key, &assignment.run)?;
    sealed.task =
        seal_task(workspace_key, &assignment.task).map_err(describe)?;
    if let Some(workflow) = &assignment.workflow {
        let sealed_workflow =
            seal_workflow(workspace_key, workflow).map_err(describe)?;
        sealed.workflow = Some(sealed_workflow);
    }
    sealed.skills.clear();
    for skill in &assignment.skills {
        let sealed_skill =
            seal_skill(workspace_key, skill).map_err(describe)?;
        sealed.skills.push(sealed_skill);
    }
    sealed.rules.clear();
    for rule in &assignment.rules {
        let sealed_rule = seal_rule(workspace_key, rule).map_err(describe)?;
        sealed.rules.push(sealed_rule);
    }
    Ok(sealed)
}

fn tamper_one_part(
    sealed: &mut RunAssignment,
    part: usize,
    position: Index,
    shift: u8,
) {
    let tampered_text = match part {
        0 => &mut sealed.task.details,
        1 => &mut sealed.rules[0].details,
        2 => &mut sealed.skills[0].instructions,
        3 => &mut sealed.run.log[0].text,
        _ => match &mut sealed.workflow {
            Some(workflow) => &mut workflow.agents[0].task,
            None => return,
        },
    };
    *tampered_text = tamper_sealed_text(tampered_text, position, shift);
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALING_CASES))]

    #[test]
    fn test_open_run_assignment_property_round_trips_every_sealed_part(
        texts in hostile_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(10)).map_err(fail)?;
        let assignment = plain_assignment(&texts);

        let sealed = seal_assignment(&workspace_key, &assignment)
            .map_err(fail)?;
        let opened = open_run_assignment(&keyring, &sealed).map_err(fail)?;

        prop_assert_eq!(opened, assignment);
    }

    #[test]
    fn test_open_run_assignment_property_detects_tampering_in_any_part(
        texts in hostile_texts_strategy(),
        part in 0..TAMPERED_PART_COUNT,
        position in any::<Index>(),
        shift in any::<u8>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(10)).map_err(fail)?;
        let assignment = plain_assignment(&texts);
        let mut sealed = seal_assignment(&workspace_key, &assignment)
            .map_err(fail)?;
        tamper_one_part(&mut sealed, part, position, shift);

        let outcome = open_run_assignment(&keyring, &sealed);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_open_run_assignment_property_needs_the_workspace_key(
        texts in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(10)).map_err(fail)?;
        let other_keyring = foreign_keyring().map_err(fail)?;
        let mut assignment = plain_assignment(&texts);
        assignment.workflow = None;

        let sealed = seal_assignment(&workspace_key, &assignment)
            .map_err(fail)?;
        let outcome = open_run_assignment(&other_keyring, &sealed);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }
}
