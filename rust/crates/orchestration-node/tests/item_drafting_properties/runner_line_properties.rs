use orchestration_core::agent_place::AgentPlace;
use orchestration_core::library::SkillUsage;
use orchestration_node::item_drafting::render_drafting_context;
use proptest::prelude::*;
use serde_json::Value;

use crate::drafting_texts::{
    break_every_text, broken_text_strategy, find_line_with,
    has_line_with_every_part, read_section_entries, split_lines,
};
use crate::support::drafting_samples::context_strategy;
use crate::support::test_device::fail;

const LINE_CASES: u32 = 48;
const LIST_SEPARATOR: &str = ", ";
const OFFERS_START: &str = "offers: ";
const NO_OFFERS: &str = "nothing";
const LABELS_START: &str = "labels: ";
const LABEL_PATTERN: &str = "[a-z][a-z0-9-]{0,8}";
const MOST_LABELS: usize = 4;
const MOST_OFFERS: usize = 4;

fn usage_strategy() -> impl Strategy<Value = SkillUsage> {
    prop_oneof![Just(SkillUsage::Automatic), Just(SkillUsage::WhenChosen)]
}

fn place_strategy() -> impl Strategy<Value = AgentPlace> {
    prop_oneof![Just(AgentPlace::LocalProcess), Just(AgentPlace::Container)]
}

fn describe_usage(usage: SkillUsage) -> &'static str {
    match usage {
        SkillUsage::Automatic => "automatic",
        SkillUsage::WhenChosen => "when_chosen",
    }
}

fn find_id_line(rendered: &str, id_text: &str) -> String {
    let marker = format!("(id {id_text})");
    find_line_with(rendered, &marker)
        .unwrap_or_default()
        .to_owned()
}

fn read_offers(line: &str) -> Vec<String> {
    let Some((_, offers_text)) = line.rsplit_once(OFFERS_START) else {
        return Vec::new();
    };
    offers_text
        .split(LIST_SEPARATOR)
        .map(str::to_owned)
        .collect()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LINE_CASES))]

    #[test]
    fn test_describe_skill_property_names_its_usage_and_summary(
        context in context_strategy(),
        usages in proptest::collection::vec(usage_strategy(), 4),
    ) {
        let mut context = context;
        for (skill, usage) in context.skills.iter_mut().zip(&usages) {
            skill.usage = *usage;
        }

        let rendered = render_drafting_context(&context);

        let entries = read_section_entries(&rendered, "Skills");
        prop_assert_eq!(entries.len(), context.skills.len().max(1));
        for (entry, skill) in entries.iter().zip(&context.skills) {
            let expected = format!(
                "{} (id {}), {}: {}",
                skill.name,
                skill.id.0,
                describe_usage(skill.usage),
                skill.summary
            );
            prop_assert_eq!(entry, &expected);
        }
    }

    #[test]
    fn test_describe_skill_property_the_usage_word_is_its_answer_value(
        usage in usage_strategy(),
        context in context_strategy(),
    ) {
        let mut context = context;
        for skill in &mut context.skills {
            skill.usage = usage;
        }

        let rendered = render_drafting_context(&context);

        let wire_value = serde_json::to_value(usage).map_err(fail)?;
        let wire_name = wire_value.as_str().unwrap_or_default().to_owned();
        for skill in &context.skills {
            let line = find_id_line(&rendered, &skill.id.0.to_string());
            let usage_part = format!("), {wire_name}: ");
            prop_assert!(line.contains(&usage_part), "{}", line);
        }
    }

    #[test]
    fn test_describe_skill_property_a_broken_summary_stays_on_its_line(
        context in context_strategy(),
        broken in broken_text_strategy(),
    ) {
        let mut hostile = context.clone();
        for skill in &mut hostile.skills {
            skill.summary = format!("{}{broken}", skill.summary);
        }

        let rendered = render_drafting_context(&hostile);

        for skill in &hostile.skills {
            let marker = format!("(id {})", skill.id.0);
            let is_whole =
                has_line_with_every_part(&rendered, &marker, &broken);
            prop_assert!(is_whole, "{:?}", rendered);
            let line = find_id_line(&rendered, &skill.id.0.to_string());
            let summary_start = split_lines(&skill.summary)[0];
            prop_assert!(line.contains(summary_start), "{:?}", line);
        }
    }

    #[test]
    fn test_describe_runner_property_states_whether_it_is_online(
        context in context_strategy(),
        presences in proptest::collection::vec(any::<bool>(), 4),
    ) {
        let mut context = context;
        for (runner, is_online) in context.runners.iter_mut().zip(&presences) {
            runner.is_online = *is_online;
        }

        let rendered = render_drafting_context(&context);

        for runner in &context.runners {
            let line = find_id_line(&rendered, &runner.device.id.0);
            let presence = if runner.is_online { "online" } else { "offline" };
            let expected_start = format!(
                "- {} (id {}), {presence}, ",
                runner.device.name, runner.device.id.0
            );
            prop_assert!(line.starts_with(&expected_start), "{}", line);
        }
    }

    #[test]
    fn test_describe_runner_property_lists_labels_only_when_it_has_some(
        context in context_strategy(),
        labels in proptest::collection::vec(LABEL_PATTERN, 0..MOST_LABELS),
    ) {
        let mut context = context;
        for runner in &mut context.runners {
            runner.labels.clone_from(&labels);
        }

        let rendered = render_drafting_context(&context);

        for runner in &context.runners {
            let line = find_id_line(&rendered, &runner.device.id.0);
            let labels_part = format!(
                ", {LABELS_START}{}, {OFFERS_START}",
                labels.join(LIST_SEPARATOR)
            );
            prop_assert_eq!(line.contains(&labels_part), !labels.is_empty());
            prop_assert_eq!(line.contains(LABELS_START), !labels.is_empty());
        }
    }

    #[test]
    fn test_describe_runner_property_a_broken_label_stays_on_its_line(
        context in context_strategy(),
        broken in broken_text_strategy(),
    ) {
        let hostile = break_every_text(&context, &broken);

        let rendered = render_drafting_context(&hostile);

        for runner in &hostile.runners {
            let marker = format!("(id {})", runner.device.id.0);
            let is_whole =
                has_line_with_every_part(&rendered, &marker, &broken);
            prop_assert!(is_whole, "{:?}", rendered);
            let line = find_id_line(&rendered, &runner.device.id.0);
            prop_assert!(line.contains(OFFERS_START), "{:?}", line);
        }
    }

    #[test]
    fn test_describe_offers_property_lists_the_offers_in_order(
        context in context_strategy(),
        offers in proptest::collection::vec(place_strategy(), 1..MOST_OFFERS),
    ) {
        let mut context = context;
        for runner in &mut context.runners {
            runner.offers.clone_from(&offers);
        }

        let rendered = render_drafting_context(&context);

        let mut expected = Vec::new();
        for offer in &offers {
            let wire_value = serde_json::to_value(offer).map_err(fail)?;
            expected.push(wire_value.as_str().unwrap_or_default().to_owned());
        }
        for runner in &context.runners {
            let line = find_id_line(&rendered, &runner.device.id.0);
            prop_assert_eq!(read_offers(&line), expected.clone());
        }
    }

    #[test]
    fn test_describe_offers_property_no_offer_says_nothing(
        context in context_strategy(),
    ) {
        let mut context = context;
        for runner in &mut context.runners {
            runner.offers.clear();
        }

        let rendered = render_drafting_context(&context);

        for runner in &context.runners {
            let line = find_id_line(&rendered, &runner.device.id.0);
            let expected_end = format!("{OFFERS_START}{NO_OFFERS}");
            prop_assert!(line.ends_with(&expected_end), "{}", line);
        }
    }

    #[test]
    fn test_describe_offers_property_every_offer_name_parses_as_a_place(
        context in context_strategy(),
    ) {
        let rendered = render_drafting_context(&context);

        for runner in &context.runners {
            let line = find_id_line(&rendered, &runner.device.id.0);
            let offers = read_offers(&line);
            if runner.offers.is_empty() {
                prop_assert_eq!(offers, vec![NO_OFFERS.to_owned()]);
                continue;
            }
            let mut parsed_places = Vec::new();
            for offer in &offers {
                let place: AgentPlace =
                    serde_json::from_value(Value::String(offer.clone()))
                        .map_err(fail)?;
                parsed_places.push(place);
            }
            prop_assert_eq!(&parsed_places, &runner.offers);
        }
    }
}
