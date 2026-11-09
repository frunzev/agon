import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/widgets/forms/removable_tag.dart';

import '../../support/random_inputs.dart';
import 'task_form_scene.dart';
import 'task_skills_field_scene.dart';

void main() {
  testWidgets('test_remove_skill_property_drops_only_that_skill', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1140607);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final List<SkillId> chosen = randomChosenSkills(random, options);
      final List<Skill> shown = <Skill>[
        for (final Skill skill in options.skills)
          if (chosen.contains(skill.id)) skill,
      ];
      if (shown.isEmpty) {
        continue;
      }
      final Skill removed = pickOne(random, shown);
      final SkillsFieldScene scene = await pumpSkillsField(
        tester,
        random: random,
        options: options,
        skillIds: chosen,
        usesAutomaticSkills: random.nextBool(),
      );

      await tapRemoveSkillTag(
        tester,
        find.widgetWithText(RemovableTag, removed.name),
      );

      expect(scene.changedSkills, <List<SkillId>>[
        <SkillId>[
          for (final SkillId skillId in chosen)
            if (skillId != removed.id) skillId,
        ],
      ]);
    }
  });

  testWidgets('test_remove_skill_property_removes_every_copy', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1140608);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final Skill removed = pickOne(random, options.skills);
      final int copies = 2 + random.nextInt(3);
      final SkillsFieldScene scene = await pumpSkillsField(
        tester,
        random: random,
        options: options,
        skillIds: <SkillId>[for (int j = 0; j < copies; j += 1) removed.id],
        usesAutomaticSkills: random.nextBool(),
      );

      expect(find.byType(RemovableTag), findsOneWidget);
      await tapRemoveSkillTag(tester, find.byType(RemovableTag));

      expect(scene.changedSkills, <List<SkillId>>[<SkillId>[]]);
    }
  });

  testWidgets('test_remove_skill_property_never_touches_the_toggle', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1140609);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final Skill removed = pickOne(random, options.skills);
      final SkillsFieldScene scene = await pumpSkillsField(
        tester,
        random: random,
        options: options,
        skillIds: <SkillId>[removed.id, unknownSkillId],
        usesAutomaticSkills: random.nextBool(),
      );

      await tapRemoveSkillTag(tester, find.byType(RemovableTag));

      expect(scene.changedSkills.single, <SkillId>[unknownSkillId]);
      expect(scene.changedAutomatic, isEmpty);
    }
  });
}
