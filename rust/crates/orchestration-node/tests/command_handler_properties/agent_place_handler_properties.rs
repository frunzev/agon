use std::time::Duration;

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::handler_desk::{
    NOT_A_RUNNER_PROBLEM, read_error_kind, read_reply_problem,
    shared_fresh_device,
};
use crate::support::fake_engine::{
    EngineAnswers, EngineRunner, local_sandbox,
};
use crate::support::test_device::fail;
use crate::support::waiting::wait_for;

const RUNNER_CASES: u32 = 2;
const PLACE_ORDER: [&str; 2] = ["local_process", "container"];
const NO_OFFERS_PROBLEM: &str =
    "a runner offers at least one place for agents to run";
const MOST_OFFERS: usize = 5;
const MOST_CHOICES: usize = 3;
const OFFERS_LIMIT: Duration = Duration::from_secs(20);
const READY_ENGINE: EngineAnswers = EngineAnswers {
    info_exit_code: 0,
    image_exit_code: 0,
};

fn offers_strategy() -> impl Strategy<Value = Vec<&'static str>> {
    prop::collection::vec(
        prop::sample::select(PLACE_ORDER.to_vec()),
        1..MOST_OFFERS,
    )
}

fn expected_offer_views(offers: &[&str]) -> Value {
    let mut views = Vec::new();
    for place in PLACE_ORDER {
        if offers.contains(&place) {
            views.push(json!({ "place": place, "problem": null }));
        }
    }
    Value::Array(views)
}

fn wait_for_listed_offers(
    runner: &EngineRunner,
    expected: &Value,
) -> Result<(), String> {
    wait_for(OFFERS_LIMIT, "the chosen offers to be listed", || {
        let runners = runner.list_runners()?;
        let is_listed = &runners["this_device_offers"] == expected;
        Ok(is_listed.then_some(()))
    })
}

fn start_ready_runner() -> Result<EngineRunner, String> {
    EngineRunner::start(&local_sandbox(), READY_ENGINE)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RUNNER_CASES))]

    #[test]
    fn test_handle_agent_place_command_property_needs_a_runner(
        offers in prop::collection::vec(
            prop::sample::select(PLACE_ORDER.to_vec()),
            0..MOST_OFFERS,
        ),
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&json!({
            "command": "choose_agent_offers",
            "offers": offers,
        }));

        prop_assert_eq!(read_reply_problem(&reply), NOT_A_RUNNER_PROBLEM);
        prop_assert_eq!(read_error_kind(&reply), None);
    }

    #[test]
    fn test_handle_agent_place_command_property_keeps_each_place_once(
        choices in prop::collection::vec(offers_strategy(), 1..MOST_CHOICES),
    ) {
        let runner = start_ready_runner().map_err(fail)?;

        for offers in &choices {
            let chosen = runner.choose_offers(&json!(offers));
            prop_assert_eq!(chosen, Ok(Value::Null));
            let expected = expected_offer_views(offers);
            wait_for_listed_offers(&runner, &expected).map_err(fail)?;
        }
    }

    #[test]
    fn test_handle_agent_place_command_property_empty_offers_change_nothing(
        offers in offers_strategy(),
    ) {
        let runner = start_ready_runner().map_err(fail)?;
        runner.choose_offers(&json!(offers)).map_err(fail)?;
        let expected = expected_offer_views(&offers);
        wait_for_listed_offers(&runner, &expected).map_err(fail)?;

        let emptied = runner.choose_offers(&json!([]));

        prop_assert_eq!(emptied, Err(NO_OFFERS_PROBLEM.to_owned()));
        wait_for_listed_offers(&runner, &expected).map_err(fail)?;
    }
}
