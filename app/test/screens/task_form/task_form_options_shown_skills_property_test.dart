import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/shell/task_route_screens.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../../support/sample_scopes.dart';

TaskFormOptions _buildGalleryOptions() {
  final AppDependencies dependencies = buildGalleryDependencies();
  return buildTaskFormOptionsFor(
    dependencies: dependencies,
    chosenTarget: const AnyFreeRunner(),
  );
}

List<SkillId> _randomSkillIds(Random random) {
  final List<SkillId> skillIds = <SkillId>[];
  for (int i = 0; i < random.nextInt(6); i += 1) {
    skillIds.add(
      random.nextBool()
          ? pickOne(random, sampleSkillIds)
          : SkillId('skill-${randomHostileText(random)}'),
    );
  }
  return skillIds;
}

Set<SkillId> _listShownIds(TaskFormOptions options) {
  return <SkillId>{for (final Skill skill in options.skills) skill.id};
}

void main() {
  final TaskFormOptions options = _buildGalleryOptions();

  test('test_pick_shown_skills_property_keeps_only_listed_skills', () {
    final Random random = seededRandom(11501);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SkillId> drafted = _randomSkillIds(random);

      final List<SkillId> shown = options.pickShownSkills(drafted);

      expect(_listShownIds(options).containsAll(shown), isTrue);
      expect(drafted.toSet().containsAll(shown), isTrue);
    }
  });

  test('test_pick_shown_skills_property_listed_skills_keep_their_order', () {
    final Random random = seededRandom(11502);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SkillId> listed = pickSome(random, sampleSkillIds);
      final List<SkillId> drafted = <SkillId>[
        for (final SkillId skillId in listed) ...<SkillId>[
          if (random.nextBool()) SkillId('skill-nowhere-$i'),
          skillId,
        ],
      ];

      expect(options.pickShownSkills(drafted), listed);
      expect(options.pickShownSkills(listed), listed);
    }
  });

  test('test_pick_shown_skills_property_is_idempotent', () {
    final Random random = seededRandom(11503);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SkillId> once = options.pickShownSkills(
        _randomSkillIds(random),
      );

      expect(options.pickShownSkills(once), once);
    }
  });
}
