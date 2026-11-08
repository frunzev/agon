use chrono::{Utc, Weekday};
use orchestration_core::schedule_rules::next_run_after;
use orchestration_core::task::{Schedule, TimeOfDay};
use orchestration_node::item_drafting::{
    DraftingContext, ItemDraft, WorkDraft,
};
use proptest::prelude::*;

use crate::drafted_item_checks::{
    CHECK_CASES, check_work, count_labelled, find_labelled, is_clear_sentence,
    read_labelled, work_wrapper_strategy,
};
use crate::support::drafting_samples::{context_strategy, valid_work_draft};

const SCHEDULE_LABEL: &str = "Repeats";
const LAST_MINUTE: u32 = 59;
const LAST_HOUR: u32 = 23;
const LARGEST_TIME_PART: u32 = 200;
const FIRST_BAD_MINUTE: u32 = 60;
const WEEKDAYS: [Weekday; 7] = [
    Weekday::Mon,
    Weekday::Tue,
    Weekday::Wed,
    Weekday::Thu,
    Weekday::Fri,
    Weekday::Sat,
    Weekday::Sun,
];

fn weekday_strategy() -> impl Strategy<Value = Weekday> {
    proptest::sample::select(WEEKDAYS.to_vec())
}

fn schedule_strategy() -> impl Strategy<Value = Schedule> {
    let time = (0..LARGEST_TIME_PART, 0..LARGEST_TIME_PART)
        .prop_map(|(hour, minute)| TimeOfDay { hour, minute });
    prop_oneof![
        (0..LARGEST_TIME_PART).prop_map(|minute| Schedule::Hour { minute }),
        time.clone().prop_map(|at| Schedule::Day { at }),
        (weekday_strategy(), time)
            .prop_map(|(on, at)| Schedule::Week { on, at }),
    ]
}

fn invalid_schedule_strategy() -> impl Strategy<Value = Schedule> {
    schedule_strategy().prop_filter("an invalid schedule", |schedule| {
        next_run_after(schedule, Utc::now()).is_err()
    })
}

fn schedule_problem(
    context: &DraftingContext,
    schedule: Schedule,
) -> Result<String, TestCaseError> {
    let work = WorkDraft {
        schedule: Some(schedule),
        ..valid_work_draft(context, "Ship", "Ship it")
    };
    let (_, problems) = check_work(context, &work, ItemDraft::Job)?;
    Ok(read_labelled(&problems, SCHEDULE_LABEL))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_find_schedule_problem_property_agrees_with_next_run_after(
        context in context_strategy(),
        wrap in work_wrapper_strategy(),
        schedule in schedule_strategy(),
    ) {
        let work = WorkDraft {
            schedule: Some(schedule),
            ..valid_work_draft(&context, "Ship", "Ship it")
        };

        let (_, problems) = check_work(&context, &work, wrap)?;

        let expected = next_run_after(&schedule, Utc::now()).err().map(
            |problem| {
                format!("Repeats: {problem}. Ask for changes and give a \
                         valid time.")
            },
        );
        let found = find_labelled(&problems, SCHEDULE_LABEL);
        prop_assert_eq!(found.map(str::to_owned), expected);
    }

    #[test]
    fn test_find_schedule_problem_property_a_task_may_have_no_schedule(
        context in context_strategy(),
    ) {
        let work = WorkDraft {
            schedule: None,
            ..valid_work_draft(&context, "Ship", "Ship it")
        };

        let (_, problems) = check_work(&context, &work, ItemDraft::Task)?;

        prop_assert!(problems.is_empty(), "{:?}", problems);
    }

    #[test]
    fn test_find_schedule_problem_property_bounds_are_the_clock_bounds(
        context in context_strategy(),
        on in weekday_strategy(),
        is_hour_over in any::<bool>(),
    ) {
        let (hour, minute) = if is_hour_over {
            (LAST_HOUR + 1, LAST_MINUTE)
        } else {
            (LAST_HOUR, LAST_MINUTE + 1)
        };
        let last_time = TimeOfDay { hour: LAST_HOUR, minute: LAST_MINUTE };
        let over_time = TimeOfDay { hour, minute };
        let fitting = [
            Schedule::Hour { minute: LAST_MINUTE },
            Schedule::Day { at: last_time },
            Schedule::Week { on, at: last_time },
        ];
        let over = [
            Schedule::Hour { minute: LAST_MINUTE + 1 },
            Schedule::Day { at: over_time },
            Schedule::Week { on, at: over_time },
        ];
        let work = valid_work_draft(&context, "Ship", "Ship it");

        for schedule in fitting {
            let fitting_work = WorkDraft {
                schedule: Some(schedule),
                ..work.clone()
            };
            let (_, problems) =
                check_work(&context, &fitting_work, ItemDraft::Job)?;
            prop_assert!(problems.is_empty(), "{:?}", problems);
        }
        for schedule in over {
            let over_work = WorkDraft {
                schedule: Some(schedule),
                ..work.clone()
            };
            let (_, problems) =
                check_work(&context, &over_work, ItemDraft::Job)?;
            prop_assert_eq!(count_labelled(&problems, SCHEDULE_LABEL), 1);
        }
    }

    #[test]
    fn test_describe_invalid_schedule_property_names_the_core_problem(
        context in context_strategy(),
        schedule in invalid_schedule_strategy(),
    ) {
        let problem = schedule_problem(&context, schedule)?;

        let core_problem = next_run_after(&schedule, Utc::now())
            .err()
            .map(|problem| problem.to_string())
            .unwrap_or_default();
        let expected = format!(
            "Repeats: {core_problem}. Ask for changes and give a valid time."
        );
        prop_assert_eq!(problem, expected);
    }

    #[test]
    fn test_describe_invalid_schedule_property_names_an_hourly_minute(
        context in context_strategy(),
        minute in FIRST_BAD_MINUTE..LARGEST_TIME_PART,
    ) {
        let problem = schedule_problem(&context, Schedule::Hour { minute })?;

        let named = format!("minute {minute} is not between 0 and 59");
        prop_assert!(problem.contains(&named), "{}", problem);
    }

    #[test]
    fn test_describe_invalid_schedule_property_is_one_clear_sentence(
        context in context_strategy(),
        schedule in invalid_schedule_strategy(),
    ) {
        let problem = schedule_problem(&context, schedule)?;

        let is_clear = is_clear_sentence(&problem, SCHEDULE_LABEL);
        prop_assert!(is_clear, "{}", problem);
    }
}
