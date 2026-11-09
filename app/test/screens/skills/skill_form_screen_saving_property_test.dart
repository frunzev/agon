import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'random_skills.dart';
import 'skill_form_probe.dart';
import 'skill_form_screen_page.dart';

Future<void> _tapSave(WidgetTester tester) async {
  await pumpFrames(tester);
  await tapVisible(tester, findSkillFormButton(saveSkillLabel));
  await pumpFrames(tester);
}

Skill _findStored(SkillFormScreenPage page, Skill skill) {
  return page.skillRepository.findSkill(skill.id);
}

Future<void> _moveOn(
  WidgetTester tester,
  Random random,
  SkillFormScreenPage page,
) async {
  if (random.nextBool()) {
    await tapVisible(tester, find.byType(BackLinkButton));
  } else {
    page.navigation.openSection(const SectionRoute(AppSection.rules));
  }
  await tester.pump();
}

void main() {
  testWidgets('test_save_skill_property_a_new_skill_is_listed_and_the_form_'
      'closes', (WidgetTester tester) async {
    final Random random = seededRandom(1121101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final SkillFormScreenPage page = await pumpSkillFormScreen(
        tester,
        random,
        existingSkill: null,
        storedSkills: skills,
      );
      final String name = 'new-$i-${randomValidSkillName(random)}';
      final String shortName = name.substring(0, min(name.length, 40));
      await enterFieldText(tester, label: skillNameLabel, text: shortName);
      await enterFieldText(tester, label: skillSummaryLabel, text: ' Sum ');
      await enterFieldText(tester, label: skillInstructionsLabel, text: 'Do');

      await _tapSave(tester);

      final List<Skill> listed = page.skillRepository.listSkills();
      expect(listed, hasLength(skills.length + 1));
      expect(listed.last.name, shortName);
      expect(listed.last.summary, 'Sum');
      expect(listed.last.history, isEmpty);
      expect(page.navigation.routes, const <AppRoute>[skillsSectionRoute]);
    }
  });

  testWidgets('test_save_skill_property_an_edit_returns_to_the_skill_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1121102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final Skill edited = pickOne(random, skills);
      final SkillFormScreenPage page = await pumpSkillFormScreen(
        tester,
        random,
        existingSkill: edited,
        storedSkills: skills,
      );
      final String changed = 'Changed ${randomText(random)}';
      await enterFieldText(
        tester,
        label: skillInstructionsLabel,
        text: changed,
      );

      await _tapSave(tester);

      final Skill stored = _findStored(page, edited);
      expect(stored.instructions, changed);
      expect(stored.history.last.origin, isA<PersonEdit>());
      expect(stored.history.last.replacedInstructions, edited.instructions);
      expect(stored.history.length, lessThanOrEqualTo(keptSkillChangeCount));
      expect(page.navigation.routes, <AppRoute>[
        skillsSectionRoute,
        SkillDetailRoute(edited.id),
      ]);
    }
  });

  testWidgets('test_save_skill_property_a_person_who_moved_on_stays_where_'
      'they_went', (WidgetTester tester) async {
    final Random random = seededRandom(1121103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final Skill? edited = random.nextBool() ? pickOne(random, skills) : null;
      final SkillFormScreenPage page = await pumpSkillFormScreen(
        tester,
        random,
        existingSkill: edited,
        storedSkills: skills,
      );
      if (edited == null) {
        await enterFieldText(tester, label: skillNameLabel, text: 'held-$i');
        await enterFieldText(tester, label: skillSummaryLabel, text: 'Sum');
        await enterFieldText(tester, label: skillInstructionsLabel, text: 'D');
      }
      final Completer<void> held = Completer<void>();
      page.skillRepository.heldSave = held;
      await pumpFrames(tester);
      await tapVisible(tester, findSkillFormButton(saveSkillLabel));
      await tester.pump();

      await _moveOn(tester, random, page);
      final List<AppRoute> wentTo = page.navigation.routes;
      held.complete();
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(page.navigation.routes, wentTo);
      expect(page.skillRepository.saveCount, 1);
    }
  });

  testWidgets('test_describe_skill_draft_property_an_untouched_edit_keeps_'
      'every_field_and_the_history', (WidgetTester tester) async {
    final Random random = seededRandom(1121104);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final Skill edited = pickOne(random, skills);
      final SkillFormScreenPage page = await pumpSkillFormScreen(
        tester,
        random,
        existingSkill: edited,
        storedSkills: skills,
      );

      await _tapSave(tester);

      final Skill stored = _findStored(page, edited);
      expect(
        describeSkillDraftFields(describeSkillAsDraft(stored)),
        describeSkillDraftFields(describeSkillAsDraft(edited)),
      );
      expect(stored.source, edited.source);
      expect(stored.history, edited.history);
    }
  });

  testWidgets('test_describe_skill_draft_property_the_form_shows_the_'
      'edited_skill', (WidgetTester tester) async {
    final Random random = seededRandom(1121105);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final Skill edited = pickOne(random, skills);
      await pumpSkillFormScreen(
        tester,
        random,
        existingSkill: edited,
        storedSkills: skills,
      );

      for (final (String label, String text) in <(String, String)>[
        (skillNameLabel, edited.name),
        (skillSummaryLabel, edited.summary),
        (skillInstructionsLabel, edited.instructions),
      ]) {
        final TextField field = tester.widget<TextField>(
          findFieldInput(label),
        );
        expect(field.controller!.text, text, reason: label);
      }
      final ChoiceListField<SkillImprovement> improvement = tester
          .widget<ChoiceListField<SkillImprovement>>(
            find.byType(ChoiceListField<SkillImprovement>),
          );
      expect(improvement.selected, edited.improvement);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_describe_skill_draft_property_a_summary_edit_keeps_'
      'the_rest', (WidgetTester tester) async {
    final Random random = seededRandom(1121106);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final Skill edited = pickOne(random, skills);
      final SkillFormScreenPage page = await pumpSkillFormScreen(
        tester,
        random,
        existingSkill: edited,
        storedSkills: skills,
      );
      final String summary = 'Other ${randomText(random)}'.trim();
      await enterFieldText(tester, label: skillSummaryLabel, text: summary);

      await _tapSave(tester);

      final Skill stored = _findStored(page, edited);
      final SkillDraft expected = SkillDraft(
        name: edited.name,
        summary: summary,
        instructions: edited.instructions,
        scope: edited.scope,
        usage: edited.usage,
        improvement: edited.improvement,
      );
      expect(
        describeSkillDraftFields(describeSkillAsDraft(stored)),
        describeSkillDraftFields(expected),
      );
      expect(stored.history, edited.history);
    }
  });
}
