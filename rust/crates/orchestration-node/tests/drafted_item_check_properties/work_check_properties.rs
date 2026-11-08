use orchestration_core::identifiers::ProjectId;
use orchestration_node::item_drafting::{
    ItemDraft, WorkDraft, check_item_draft,
};
use proptest::prelude::*;

use crate::drafted_item_checks::{
    CHECK_CASES, blank_text_strategy, check_again, check_work,
    kept_text_strategy,
};
use crate::support::drafting_samples::{
    context_strategy, empty_context, foreign_uuid, sample_project,
    valid_work_draft,
};
use crate::work_samples::{JOB_WITHOUT_SCHEDULE, varied_work_strategy};

const MOST_PROJECTS: usize = 4;

fn without_schedule_problem(problems: &[String]) -> Vec<String> {
    let mut kept = Vec::new();
    for problem in problems {
        if problem != JOB_WITHOUT_SCHEDULE {
            kept.push(problem.clone());
        }
    }
    kept
}

fn trimmed_copy(work: &WorkDraft, title: &str, details: &str) -> WorkDraft {
    WorkDraft {
        title: title.to_owned(),
        details: details.to_owned(),
        ..work.clone()
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_check_task_draft_property_matches_the_job_but_its_schedule(
        (context, work) in varied_work_strategy(),
    ) {
        let (_, task_problems) = check_work(&context, &work, ItemDraft::Task)?;
        let (_, job_problems) = check_work(&context, &work, ItemDraft::Job)?;

        let schedule_problem = JOB_WITHOUT_SCHEDULE.to_owned();
        prop_assert!(!task_problems.contains(&schedule_problem));
        let expected = without_schedule_problem(&job_problems);
        prop_assert_eq!(task_problems, expected);
    }

    #[test]
    fn test_check_task_draft_property_is_idempotent(
        (context, work) in varied_work_strategy(),
    ) {
        let checked = check_item_draft(&context, &ItemDraft::Task(work));

        let checked_again = check_again(&context, &checked);

        prop_assert_eq!(checked_again, checked);
    }

    #[test]
    fn test_check_task_draft_property_answers_a_task(
        (context, work) in varied_work_strategy(),
    ) {
        let checked = check_item_draft(&context, &ItemDraft::Task(work));

        let is_task = matches!(checked.draft, ItemDraft::Task(_));
        prop_assert!(is_task, "{:?}", checked.draft);
    }

    #[test]
    fn test_check_job_draft_property_a_missing_schedule_is_named_last(
        (context, work) in varied_work_strategy(),
    ) {
        let unscheduled = WorkDraft { schedule: None, ..work };

        let (_, problems) =
            check_work(&context, &unscheduled, ItemDraft::Job)?;

        let schedule_problem = JOB_WITHOUT_SCHEDULE.to_owned();
        prop_assert_eq!(problems.last(), Some(&schedule_problem));
        let repeated = problems
            .iter()
            .filter(|problem| **problem == schedule_problem)
            .count();
        prop_assert_eq!(repeated, 1);
    }

    #[test]
    fn test_check_job_draft_property_is_idempotent(
        (context, work) in varied_work_strategy(),
    ) {
        let checked = check_item_draft(&context, &ItemDraft::Job(work));

        let checked_again = check_again(&context, &checked);

        prop_assert_eq!(checked_again, checked);
    }

    #[test]
    fn test_check_job_draft_property_answers_a_job(
        (context, work) in varied_work_strategy(),
    ) {
        let checked = check_item_draft(&context, &ItemDraft::Job(work));

        let is_job = matches!(checked.draft, ItemDraft::Job(_));
        prop_assert!(is_job, "{:?}", checked.draft);
    }

    #[test]
    fn test_complete_work_property_only_a_sole_project_fills_the_gap(
        project_count in 0..MOST_PROJECTS,
        is_job in any::<bool>(),
    ) {
        let mut context = empty_context();
        for index in 0..project_count {
            let name = format!("app-{index}");
            let address = format!("github.com/acme/app-{index}");
            context.projects.push(sample_project(index, &name, &address));
        }
        let work = WorkDraft {
            project_id: None,
            ..valid_work_draft(&context, "Ship", "Ship it")
        };
        let wrap = if is_job { ItemDraft::Job } else { ItemDraft::Task };

        let (completed, _) = check_work(&context, &work, wrap)?;

        let expected = match context.projects.as_slice() {
            [only_project] => Some(only_project.id),
            _ => None,
        };
        prop_assert_eq!(completed.project_id, expected);
    }

    #[test]
    fn test_complete_work_property_an_answered_project_is_kept(
        context in context_strategy(),
        is_foreign in any::<bool>(),
        position in any::<prop::sample::Index>(),
    ) {
        let project_id = if is_foreign {
            ProjectId(foreign_uuid())
        } else {
            context.projects[position.index(context.projects.len())].id
        };
        let work = WorkDraft {
            project_id: Some(project_id),
            ..valid_work_draft(&context, "Ship", "Ship it")
        };

        let (completed, _) = check_work(&context, &work, ItemDraft::Task)?;

        prop_assert_eq!(completed.project_id, Some(project_id));
    }

    #[test]
    fn test_complete_work_property_trims_only_title_and_details(
        context in context_strategy(),
        title in kept_text_strategy(),
        details in kept_text_strategy(),
        edges in (blank_text_strategy(), blank_text_strategy()),
    ) {
        let (leading, trailing) = edges;
        let work = valid_work_draft(
            &context,
            &format!("{leading}{title}{trailing}"),
            &format!("{trailing}{details}{leading}"),
        );

        let (completed, _) = check_work(&context, &work, ItemDraft::Job)?;

        prop_assert_eq!(completed, trimmed_copy(&work, &title, &details));
    }
}
