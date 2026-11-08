use chrono::{DateTime, TimeDelta, Utc};
use proptest::prelude::*;
use proptest::sample::select;
use serde_json::{Value, json};

use crate::work_desk::{TITLE_PATTERN, WorkPlace};

const AGENT_KINDS: [&str; 3] = ["claude_code", "codex", "gemini_cli"];
const AGENT_PLACES: [&str; 2] = ["local_process", "container"];
const APPROVAL_POLICIES: [Option<&str>; 3] =
    [None, Some("never_ask"), Some("ask_before_risky_actions")];
const WEEKDAYS: [&str; 7] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const MINUTES_PER_HOUR: u32 = 60;
const HOURS_PER_DAY: u32 = 24;
const HOUR_PERIOD: &str = "hour";
const DAY_PERIOD: &str = "day";

#[derive(Clone, Debug)]
pub struct TaskSample {
    pub title: String,
    pub details: String,
    pub agent: &'static str,
    pub agent_place: &'static str,
    pub uses_automatic_skills: bool,
    pub approval_policy: Option<&'static str>,
}

impl TaskSample {
    pub fn build_arguments(&self, place: &WorkPlace) -> Value {
        json!({
            "workspace_id": place.workspace_id,
            "project_id": place.project_id,
            "title": self.title,
            "details": self.details,
            "doer": { "kind": "one_agent", "agent": self.agent },
            "runs_on": { "kind": "any_free_runner" },
            "agent_place": self.agent_place,
            "skills": [],
            "uses_automatic_skills": self.uses_automatic_skills,
            "approval_policy": self.approval_policy,
        })
    }
}

pub fn task_sample() -> impl Strategy<Value = TaskSample> {
    (
        TITLE_PATTERN,
        "[a-z ]{0,30}",
        select(AGENT_KINDS.to_vec()),
        select(AGENT_PLACES.to_vec()),
        any::<bool>(),
        select(APPROVAL_POLICIES.to_vec()),
    )
        .prop_map(
            |(title, details, agent, agent_place, automatic, policy)| {
                TaskSample {
                    title,
                    details,
                    agent,
                    agent_place,
                    uses_automatic_skills: automatic,
                    approval_policy: policy,
                }
            },
        )
}

fn time_of_day() -> impl Strategy<Value = Value> {
    (0..HOURS_PER_DAY, 0..MINUTES_PER_HOUR)
        .prop_map(|(hour, minute)| json!({ "hour": hour, "minute": minute }))
}

pub fn schedule_sample() -> impl Strategy<Value = Value> {
    prop_oneof![
        (0..MINUTES_PER_HOUR)
            .prop_map(|minute| json!({ "every": "hour", "minute": minute })),
        time_of_day().prop_map(|at| json!({ "every": "day", "at": at })),
        (select(WEEKDAYS.to_vec()), time_of_day()).prop_map(|(on, at)| {
            json!({ "every": "week", "on": on, "at": at })
        }),
    ]
}

pub fn measure_schedule_period(schedule: &Value) -> TimeDelta {
    let period = schedule["every"].as_str().unwrap_or_default();
    if period == HOUR_PERIOD {
        return TimeDelta::hours(1);
    }
    if period == DAY_PERIOD {
        return TimeDelta::days(1);
    }
    TimeDelta::weeks(1)
}

pub fn read_moment(value: &Value) -> Result<DateTime<Utc>, String> {
    let text = value.as_str().ok_or("the moment is not text")?;
    let moment = DateTime::parse_from_rfc3339(text)
        .map_err(|error| error.to_string())?;
    Ok(moment.with_timezone(&Utc))
}
