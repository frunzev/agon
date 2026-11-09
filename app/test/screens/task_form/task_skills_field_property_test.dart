import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/widgets/forms/check_field.dart';
import 'package:agent_orchestration/widgets/forms/removable_tag.dart';
import 'package:agent_orchestration/widgets/forms/tag_input_field.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'task_form_scene.dart';
import 'task_skills_field_scene.dart';

const String _skillsHint = 'A workflow sets the skills of each of its agents.';
const String _automaticLabel = 'Also let the agent pick automatic skills';

void main() {
  testWidgets('test_task_skills_field_build_property_shows_known_choices', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1140601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final List<SkillId> chosen = randomChosenSkills(random, options);

      await pumpSkillsField(
        tester,
        random: random,
        options: options,
        skillIds: chosen,
        usesAutomaticSkills: random.nextBool(),
      );

      final TagInputField field = tester.widget(find.byType(TagInputField));
      expect(tester.takeException(), isNull);
      expect(field.tags, <String>[
        for (final Skill skill in options.skills)
          if (chosen.contains(skill.id)) skill.name,
      ]);
      expect(field.suggestions, <String>[
        for (final Skill skill in options.skills) skill.name,
      ]);
      expect(find.byType(RemovableTag), findsNWidgets(field.tags.length));
    }
  });

  testWidgets('test_task_skills_field_build_property_names_the_field', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1140602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool usesAutomaticSkills = random.nextBool();

      await pumpSkillsField(
        tester,
        random: random,
        options: buildRandomTaskFormOptions(random),
        skillIds: const <SkillId>[],
        usesAutomaticSkills: usesAutomaticSkills,
      );

      final CheckField check = tester.widget(find.byType(CheckField));
      expect(find.text(skillsFieldLabel), findsOneWidget);
      expect(find.text(_skillsHint), findsOneWidget);
      expect(check.label, _automaticLabel);
      expect(check.value, usesAutomaticSkills);
    }
  });

  testWidgets('test_task_skills_field_build_property_toggle_reports_the_'
      'opposite', (WidgetTester tester) async {
    final Random random = seededRandom(1140603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool usesAutomaticSkills = random.nextBool();
      final SkillsFieldScene scene = await pumpSkillsField(
        tester,
        random: random,
        options: buildRandomTaskFormOptions(random),
        skillIds: const <SkillId>[],
        usesAutomaticSkills: usesAutomaticSkills,
      );

      await tapVisible(tester, find.byType(CheckField));
      await tester.pump();

      expect(scene.changedAutomatic, <bool>[!usesAutomaticSkills]);
      expect(scene.changedSkills, isEmpty);
    }
  });

  testWidgets('test_add_skill_property_appends_the_named_skill_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1140604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final List<SkillId> chosen = randomChosenSkills(random, options);
      final List<Skill> free = <Skill>[
        for (final Skill skill in options.skills)
          if (!chosen.contains(skill.id)) skill,
      ];
      if (free.isEmpty) {
        continue;
      }
      final Skill added = pickOne(random, free);
      final List<SkillId> before = List<SkillId>.of(chosen);
      final SkillsFieldScene scene = await pumpSkillsField(
        tester,
        random: random,
        options: options,
        skillIds: chosen,
        usesAutomaticSkills: random.nextBool(),
      );

      await addFieldTag(tester, label: skillsFieldLabel, tag: added.name);

      expect(scene.changedSkills, <List<SkillId>>[
        <SkillId>[...before, added.id],
      ]);
      expect(chosen, before);
    }
  });

  testWidgets('test_add_skill_property_chosen_or_unknown_names_add_'
      'nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1140605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final Skill chosenSkill = pickOne(random, options.skills);
      final String typed = random.nextBool()
          ? chosenSkill.name
          : 'not-a-skill-${randomText(random)}';
      final SkillsFieldScene scene = await pumpSkillsField(
        tester,
        random: random,
        options: options,
        skillIds: <SkillId>[chosenSkill.id],
        usesAutomaticSkills: random.nextBool(),
      );

      await addFieldTag(tester, label: skillsFieldLabel, tag: typed);

      expect(scene.changedSkills, isEmpty);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_add_skill_property_keeps_hidden_choices', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1140606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final Skill added = pickOne(random, options.skills);
      final SkillsFieldScene scene = await pumpSkillsField(
        tester,
        random: random,
        options: options,
        skillIds: const <SkillId>[unknownSkillId],
        usesAutomaticSkills: random.nextBool(),
      );

      await addFieldTag(tester, label: skillsFieldLabel, tag: added.name);

      expect(scene.changedSkills.single, <SkillId>[unknownSkillId, added.id]);
    }
  });
}
