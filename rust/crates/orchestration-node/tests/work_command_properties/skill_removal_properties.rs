use proptest::prelude::*;
use serde_json::json;

use crate::handler_desk::count_requests_to;
use crate::skill_desk::{
    AGENT_COUNT, SKILL_COUNT, STEP_TASK_PATTERN, create_skilled_workflow,
    create_skills, delete_skill, listed_view, pick_skills, skill_choices,
    without,
};
use crate::support::test_device::{fail, read_text};
use crate::work_desk::check_on_workspace;
use crate::workflow_desk::{PUT_METHOD, WORKFLOWS_PATH, run_on_workflow};

#[test]
fn test_without_skill_property_no_agent_keeps_the_deleted_skill() {
    let cases = (skill_choices(), 0..SKILL_COUNT);
    check_on_workspace(&cases, |prepared, (choices, deleted_position)| {
        let skill_ids = create_skills(prepared).map_err(fail)?;
        let skills_per_agent = pick_skills(&skill_ids, &choices);
        let workflow = create_skilled_workflow(
            prepared,
            ("Plan it", "Build it"),
            &skills_per_agent,
        )
        .map_err(fail)?;
        let deleted_skill = &skill_ids[deleted_position];

        delete_skill(prepared, deleted_skill).map_err(fail)?;

        let listed = listed_view(prepared, &workflow).map_err(fail)?;
        for (position, skills) in skills_per_agent.iter().enumerate() {
            let expected = without(skills, deleted_skill);
            let agent = &listed["workflow"]["agents"][position];
            prop_assert_eq!(&agent["skills"], &json!(expected));
        }
        Ok(())
    });
}

#[test]
fn test_without_skill_property_only_the_skills_change() {
    let cases = (skill_choices(), STEP_TASK_PATTERN, STEP_TASK_PATTERN);
    check_on_workspace(
        &cases,
        |prepared, (choices, plan_task, build_task)| {
            let skill_ids = create_skills(prepared).map_err(fail)?;
            let skills_per_agent = pick_skills(&skill_ids, &choices);
            let workflow = create_skilled_workflow(
                prepared,
                (&plan_task, &build_task),
                &skills_per_agent,
            )
            .map_err(fail)?;

            delete_skill(prepared, &skill_ids[0]).map_err(fail)?;

            let listed = listed_view(prepared, &workflow).map_err(fail)?;
            let mut expected = workflow.clone();
            for position in 0..AGENT_COUNT {
                let kept = without(&skills_per_agent[position], &skill_ids[0]);
                expected["agents"][position]["skills"] = json!(kept);
            }
            prop_assert_eq!(&listed["workflow"], &expected);
            let stored = prepared.server.read_stored_state().map_err(fail)?;
            prop_assert!(!stored.contains(&plan_task));
            prop_assert!(!stored.contains(&build_task));
            Ok(())
        },
    );
}

#[test]
fn test_uses_skill_property_untouched_workflows_get_no_update() {
    check_on_workspace(&any::<bool>(), |prepared, is_signed| {
        let skill_ids = create_skills(prepared).map_err(fail)?;
        let using = vec![vec![skill_ids[0].clone()], Vec::new()];
        let not_using = vec![vec![skill_ids[1].clone()], Vec::new()];
        create_skilled_workflow(prepared, ("Plan", "Build"), &using)
            .map_err(fail)?;
        let untouched =
            create_skilled_workflow(prepared, ("Plan", "Build"), &not_using)
                .map_err(fail)?;
        if is_signed {
            run_on_workflow(
                &prepared.device,
                "sign_workflow",
                &untouched["id"],
            )
            .map_err(fail)?;
        }
        let before = listed_view(prepared, &untouched).map_err(fail)?;
        let untouched_id = read_text(&untouched, "/id").map_err(fail)?;
        let untouched_path = format!("{WORKFLOWS_PATH}/{untouched_id}");
        let puts_before =
            count_requests_to(&prepared.server, PUT_METHOD, &untouched_path);

        delete_skill(prepared, &skill_ids[0]).map_err(fail)?;

        let puts_after =
            count_requests_to(&prepared.server, PUT_METHOD, &untouched_path);
        prop_assert_eq!(puts_after, puts_before);
        let after = listed_view(prepared, &untouched).map_err(fail)?;
        prop_assert_eq!(after, before);
        Ok(())
    });
}

#[test]
fn test_uses_skill_property_an_unused_skill_rewrites_no_workflow() {
    check_on_workspace(&skill_choices(), |prepared, choices| {
        let skill_ids = create_skills(prepared).map_err(fail)?;
        let mut kept_per_agent = Vec::new();
        for skills in pick_skills(&skill_ids, &choices) {
            kept_per_agent.push(without(&skills, &skill_ids[2]));
        }
        create_skilled_workflow(prepared, ("Plan", "Build"), &kept_per_agent)
            .map_err(fail)?;
        let puts_before =
            count_requests_to(&prepared.server, PUT_METHOD, WORKFLOWS_PATH);

        delete_skill(prepared, &skill_ids[2]).map_err(fail)?;

        let puts_after =
            count_requests_to(&prepared.server, PUT_METHOD, WORKFLOWS_PATH);
        prop_assert_eq!(puts_after, puts_before);
        Ok(())
    });
}

#[test]
fn test_without_skill_property_a_repeated_skill_goes_entirely() {
    check_on_workspace(&(1..=3_usize), |prepared, repeats| {
        let skill_ids = create_skills(prepared).map_err(fail)?;
        let mut repeated = Vec::new();
        for _ in 0..repeats {
            repeated.push(skill_ids[0].clone());
            repeated.push(skill_ids[1].clone());
        }
        let skills = vec![repeated, Vec::new()];
        let workflow =
            create_skilled_workflow(prepared, ("Plan", "Build"), &skills)
                .map_err(fail)?;

        delete_skill(prepared, &skill_ids[0]).map_err(fail)?;

        let listed = listed_view(prepared, &workflow).map_err(fail)?;
        let kept = vec![skill_ids[1].clone(); repeats];
        let agents = &listed["workflow"]["agents"];
        prop_assert_eq!(&agents[0]["skills"], &json!(kept));
        Ok(())
    });
}

#[test]
fn test_uses_skill_property_a_skill_on_any_agent_counts() {
    check_on_workspace(&(0..AGENT_COUNT), |prepared, using_agent| {
        let skill_ids = create_skills(prepared).map_err(fail)?;
        let mut skills = vec![Vec::new(); AGENT_COUNT];
        skills[using_agent] = vec![skill_ids[2].clone()];
        let workflow =
            create_skilled_workflow(prepared, ("Plan", "Build"), &skills)
                .map_err(fail)?;
        let workflow_id = read_text(&workflow, "/id").map_err(fail)?;
        let workflow_path = format!("{WORKFLOWS_PATH}/{workflow_id}");
        let puts_before =
            count_requests_to(&prepared.server, PUT_METHOD, &workflow_path);

        delete_skill(prepared, &skill_ids[2]).map_err(fail)?;

        let puts_after =
            count_requests_to(&prepared.server, PUT_METHOD, &workflow_path);
        prop_assert_eq!(puts_after, puts_before + 1);
        let listed = listed_view(prepared, &workflow).map_err(fail)?;
        let agents = &listed["workflow"]["agents"];
        prop_assert_eq!(&agents[using_agent]["skills"], &json!([]));
        Ok(())
    });
}
