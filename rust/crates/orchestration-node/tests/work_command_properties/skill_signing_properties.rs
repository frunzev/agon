use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::json;

use crate::skill_desk::{
    MOST_WORKFLOWS, STEP_TASK_PATTERN, create_skilled_workflow, create_skills,
    delete_skill, listed_view,
};
use crate::support::test_device::fail;
use crate::work_desk::check_on_workspace;
use crate::workflow_desk::{run_on_workflow, save_workflow};

#[test]
fn test_remove_skill_from_workflows_property_a_signed_workflow_stays_signed() {
    check_on_workspace(&STEP_TASK_PATTERN, |prepared, plan_task| {
        let skill_ids = create_skills(prepared).map_err(fail)?;
        let skills = vec![skill_ids.clone(), vec![skill_ids[0].clone()]];
        let workflow =
            create_skilled_workflow(prepared, (&plan_task, "Build"), &skills)
                .map_err(fail)?;
        run_on_workflow(&prepared.device, "sign_workflow", &workflow["id"])
            .map_err(fail)?;

        delete_skill(prepared, &skill_ids[0]).map_err(fail)?;

        let listed = listed_view(prepared, &workflow).map_err(fail)?;
        prop_assert_eq!(&listed["signature_state"], "signed");
        let document = listed["document"].as_str().unwrap_or_default();
        prop_assert!(!document.contains(&skill_ids[0]), "{}", document);
        prop_assert!(document.contains(&skill_ids[1]), "{}", document);
        Ok(())
    });
}

#[test]
fn test_remove_skill_from_workflows_property_unsigned_work_stays_unsigned() {
    check_on_workspace(&STEP_TASK_PATTERN, |prepared, changed_task| {
        let skill_ids = create_skills(prepared).map_err(fail)?;
        let skills = vec![vec![skill_ids[0].clone()], Vec::new()];
        let never_signed =
            create_skilled_workflow(prepared, ("Plan", "Build"), &skills)
                .map_err(fail)?;
        let changed =
            create_skilled_workflow(prepared, ("Plan", "Build"), &skills)
                .map_err(fail)?;
        let signed =
            run_on_workflow(&prepared.device, "sign_workflow", &changed["id"])
                .map_err(fail)?;
        let mut edited = signed["workflow"].clone();
        edited["agents"][1]["task"] = json!(changed_task);
        save_workflow(prepared, &prepared.workspace_id, &edited)
            .map_err(fail)?;

        delete_skill(prepared, &skill_ids[0]).map_err(fail)?;

        let never_signed_view =
            listed_view(prepared, &never_signed).map_err(fail)?;
        let changed_view = listed_view(prepared, &changed).map_err(fail)?;
        prop_assert_eq!(
            &never_signed_view["signature_state"],
            "not_signed_yet"
        );
        prop_assert_eq!(
            &changed_view["signature_state"],
            "changed_not_signed"
        );
        let agents = &changed_view["workflow"]["agents"];
        prop_assert_eq!(&agents[0]["skills"], &json!([]));
        prop_assert_eq!(&agents[1]["task"], &json!(changed_task));
        Ok(())
    });
}

#[test]
fn test_remove_skill_from_workflows_property_every_user_is_cleaned() {
    let cases = vec(any::<bool>(), 1..=MOST_WORKFLOWS);
    check_on_workspace(&cases, |prepared, signings| {
        let skill_ids = create_skills(prepared).map_err(fail)?;
        let skills = vec![Vec::new(), vec![skill_ids[1].clone()]];
        let mut workflows = Vec::new();
        for is_signed in &signings {
            let workflow =
                create_skilled_workflow(prepared, ("Plan", "Build"), &skills)
                    .map_err(fail)?;
            if *is_signed {
                run_on_workflow(
                    &prepared.device,
                    "sign_workflow",
                    &workflow["id"],
                )
                .map_err(fail)?;
            }
            workflows.push(workflow);
        }

        delete_skill(prepared, &skill_ids[1]).map_err(fail)?;

        for (workflow, is_signed) in workflows.iter().zip(&signings) {
            let listed = listed_view(prepared, workflow).map_err(fail)?;
            let agents = &listed["workflow"]["agents"];
            prop_assert_eq!(&agents[1]["skills"], &json!([]));
            let expected_state = if *is_signed {
                "signed"
            } else {
                "not_signed_yet"
            };
            prop_assert_eq!(&listed["signature_state"], expected_state);
        }
        Ok(())
    });
}
