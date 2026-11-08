use chrono::Weekday;
use orchestration_core::agent_place::AgentPlace;
use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{DeviceId, WorkflowId};
use orchestration_core::library::{SkillImprovement, SkillUsage};
use orchestration_core::scope::{ProjectScope, WorkspaceScope};
use orchestration_core::task::{Schedule, TaskDoer, TimeOfDay};
use orchestration_core::workflow::AgentKind;
use orchestration_core::workspace::AgentAccess;
use orchestration_node::item_drafting::{
    DraftKind, ItemDraft, check_item_draft, parse_item_answer,
};
use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use serde::Serialize;
use serde_json::Value;
use uuid::Uuid;

use crate::prompt_instructions::{
    find_field_line, list_field_names, render_instructions,
};
use crate::support::draft_answer_samples::well_formed_answer;
use crate::support::drafting_samples::{
    context_strategy, empty_context, kind_strategy, valid_work_draft,
};
use crate::support::entity_strategies::secret_text_strategy;
use crate::support::test_device::fail;

const LINE_CASES: u32 = 48;
const KIND_FIELD: &str = "kind";
const UNASKED_PROJECT_FIELD: &str = "approval_policy";
const NEVER_NULL: &str = "never null";
const REPEATS_LABEL: &str = "Repeats: ";
const LAST_HOUR: u32 = 23;
const LAST_MINUTE: u32 = 59;
const ALL_WEEKDAYS: [Weekday; 7] = [
    Weekday::Mon,
    Weekday::Tue,
    Weekday::Wed,
    Weekday::Thu,
    Weekday::Fri,
    Weekday::Sat,
    Weekday::Sun,
];

fn wire_text(
    value: &impl Serialize,
    field: Option<&str>,
) -> Result<String, TestCaseError> {
    let encoded = serde_json::to_value(value).map_err(fail)?;
    let picked = match field {
        Some(field_name) => encoded.get(field_name).cloned(),
        None => Some(encoded),
    };
    let text = picked.and_then(|picked| picked.as_str().map(str::to_owned));
    Ok(text.unwrap_or_default())
}

fn list_parsed_fields(
    kind: DraftKind,
    answer: &Value,
) -> Result<Vec<String>, TestCaseError> {
    let parsed = parse_item_answer(kind, &answer.to_string()).map_err(fail)?;
    let encoded = serde_json::to_value(&parsed).map_err(fail)?;
    let mut fields = Vec::new();
    for field in encoded.as_object().into_iter().flat_map(|map| map.keys()) {
        if field != KIND_FIELD {
            fields.push(field.clone());
        }
    }
    Ok(fields)
}

fn count_schedule_problems(schedule: Schedule) -> usize {
    let context = empty_context();
    let mut work = valid_work_draft(&context, "title", "details");
    work.schedule = Some(schedule);
    check_item_draft(&context, &ItemDraft::Task(work))
        .problems
        .iter()
        .filter(|problem| problem.starts_with(REPEATS_LABEL))
        .count()
}

fn daily_at(hour: u32, minute: u32) -> Schedule {
    Schedule::Day {
        at: TimeOfDay { hour, minute },
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LINE_CASES))]

    #[test]
    fn test_list_kind_lines_property_every_listed_field_is_parsed(
        context in context_strategy(),
        kind in kind_strategy(),
        words in secret_text_strategy(),
    ) {
        let instructions = render_instructions(&context, kind, &words)?;
        let answer = well_formed_answer(kind, &context, &words);

        let parsed_fields = list_parsed_fields(kind, &answer)?;

        for field in list_field_names(&instructions) {
            prop_assert!(parsed_fields.contains(&field), "{}", field);
        }
    }

    #[test]
    fn test_list_kind_lines_property_every_parsed_field_is_explained(
        context in context_strategy(),
        kind in kind_strategy(),
        words in secret_text_strategy(),
    ) {
        let instructions = render_instructions(&context, kind, &words)?;
        let answer = well_formed_answer(kind, &context, &words);

        let parsed_fields = list_parsed_fields(kind, &answer)?;

        let listed = list_field_names(&instructions);
        for field in parsed_fields {
            let is_unasked = kind == DraftKind::Project
                && field == UNASKED_PROJECT_FIELD;
            prop_assert_eq!(listed.contains(&field), !is_unasked, "{}", field);
        }
    }

    #[test]
    fn test_list_kind_lines_property_names_every_accepted_choice(
        kind in kind_strategy(),
        words in secret_text_strategy(),
    ) {
        let context = empty_context();
        let instructions = render_instructions(&context, kind, &words)?;

        let mut choices = Vec::new();
        if matches!(kind, DraftKind::Skill | DraftKind::Rule) {
            let only_workspaces =
                WorkspaceScope::OnlyWorkspaces { workspaces: Vec::new() };
            let only_projects =
                ProjectScope::OnlyProjects { projects: Vec::new() };
            let all_workspaces = WorkspaceScope::AllWorkspaces;
            let all_projects = ProjectScope::AllProjects;
            choices.push(wire_text(&all_workspaces, Some(KIND_FIELD))?);
            choices.push(wire_text(&only_workspaces, Some(KIND_FIELD))?);
            choices.push(wire_text(&all_projects, Some(KIND_FIELD))?);
            choices.push(wire_text(&only_projects, Some(KIND_FIELD))?);
        }
        if kind == DraftKind::Skill {
            choices.push(wire_text(&SkillUsage::Automatic, None)?);
            choices.push(wire_text(&SkillUsage::WhenChosen, None)?);
            choices.push(wire_text(&SkillImprovement::Never, None)?);
            choices.push(wire_text(&SkillImprovement::AskMe, None)?);
            choices.push(wire_text(&SkillImprovement::Auto, None)?);
        }
        if kind == DraftKind::Project {
            choices.push(wire_text(&AgentAccess::ReadOnly, None)?);
            choices.push(wire_text(&AgentAccess::PushAfterApproval, None)?);
        }
        for choice in choices {
            prop_assert!(!choice.is_empty());
            prop_assert!(instructions.contains(&choice), "{}", choice);
        }
    }

    #[test]
    fn test_list_work_lines_property_task_and_job_differ_only_in_schedule(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let task = render_instructions(&context, DraftKind::Task, &words)?;
        let job = render_instructions(&context, DraftKind::Job, &words)?;

        let task_lines: Vec<&str> = task.lines().collect();
        let job_lines: Vec<&str> = job.lines().collect();
        prop_assert_eq!(task_lines.len(), job_lines.len());
        let task_schedule = find_field_line(&task, "schedule");
        let job_schedule = find_field_line(&job, "schedule");
        for (task_line, job_line) in task_lines.iter().zip(&job_lines) {
            let is_schedule = *task_line == task_schedule;
            prop_assert_eq!(task_line == job_line, !is_schedule);
        }
        prop_assert!(job_schedule.contains(NEVER_NULL), "{}", job_schedule);
        prop_assert!(task_schedule.contains("null"), "{}", task_schedule);
        prop_assert!(!task_schedule.contains(NEVER_NULL));
    }

    #[test]
    fn test_list_work_lines_property_names_every_accepted_choice(
        kind in prop_oneof![Just(DraftKind::Task), Just(DraftKind::Job)],
        words in secret_text_strategy(),
    ) {
        let context = empty_context();
        let instructions = render_instructions(&context, kind, &words)?;

        let specific = RunnerTarget::SpecificRunner {
            device_id: DeviceId(String::new()),
        };
        let labelled = RunnerTarget::RunnerWithLabels { labels: Vec::new() };
        let one_agent = TaskDoer::OneAgent { agent: AgentKind::Codex };
        let workflow = TaskDoer::Workflow {
            workflow_id: WorkflowId(Uuid::nil()),
        };
        let choices = [
            wire_text(&RunnerTarget::AnyFreeRunner, Some(KIND_FIELD))?,
            wire_text(&specific, Some(KIND_FIELD))?,
            wire_text(&labelled, Some(KIND_FIELD))?,
            wire_text(&one_agent, Some(KIND_FIELD))?,
            wire_text(&workflow, Some(KIND_FIELD))?,
            wire_text(&AgentKind::ClaudeCode, None)?,
            wire_text(&AgentKind::Codex, None)?,
            wire_text(&AgentKind::GeminiCli, None)?,
            wire_text(&AgentPlace::LocalProcess, None)?,
            wire_text(&AgentPlace::Container, None)?,
            wire_text(&ApprovalPolicy::NeverAsk, None)?,
            wire_text(&ApprovalPolicy::AskBeforeRiskyActions, None)?,
        ];
        for choice in choices {
            prop_assert!(!choice.is_empty());
            prop_assert!(instructions.contains(&choice), "{}", choice);
        }
    }

    #[test]
    fn test_list_work_lines_property_schedule_forms_match_the_checks(
        kind in prop_oneof![Just(DraftKind::Task), Just(DraftKind::Job)],
        hour in 0..=LAST_HOUR,
        minute in 0..=LAST_MINUTE,
        too_late_hour in (LAST_HOUR + 1)..100,
        too_late_minute in (LAST_MINUTE + 1)..100,
    ) {
        let instructions = render_instructions(&empty_context(), kind, "w")?;
        let schedule_line = find_field_line(&instructions, "schedule");

        let hour_range = format!("\"hour\": 0-{LAST_HOUR}");
        let minute_range = format!("\"minute\": 0-{LAST_MINUTE}");
        prop_assert!(schedule_line.contains(&hour_range));
        prop_assert!(schedule_line.contains(&minute_range));
        for weekday in ALL_WEEKDAYS {
            let day_name = wire_text(&weekday, None)?;
            prop_assert!(schedule_line.contains(&day_name), "{}", day_name);
        }
        prop_assert_eq!(count_schedule_problems(daily_at(hour, minute)), 0);
        let hourly = Schedule::Hour { minute };
        prop_assert_eq!(count_schedule_problems(hourly), 0);
        let late_hour = daily_at(too_late_hour, minute);
        prop_assert_eq!(count_schedule_problems(late_hour), 1);
        let late_minute = Schedule::Hour { minute: too_late_minute };
        prop_assert_eq!(count_schedule_problems(late_minute), 1);
    }
}
