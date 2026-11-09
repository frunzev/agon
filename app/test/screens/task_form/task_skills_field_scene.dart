import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_skills_field.dart';

import '../../support/form_finders.dart';
import '../support/random_page_windows.dart';

const String skillsFieldLabel = 'Skills to use';
const SkillId unknownSkillId = SkillId('unknown-skill');

final class SkillsFieldScene {
  final List<List<SkillId>> changedSkills = <List<SkillId>>[];
  final List<bool> changedAutomatic = <bool>[];
}

List<SkillId> randomChosenSkills(Random random, TaskFormOptions options) {
  final List<SkillId> chosen = <SkillId>[
    for (final Skill skill in options.skills)
      if (random.nextBool()) skill.id,
  ];
  if (random.nextBool()) {
    chosen.insert(random.nextInt(chosen.length + 1), unknownSkillId);
  }
  return chosen;
}

Future<SkillsFieldScene> pumpSkillsField(
  WidgetTester tester, {
  required Random random,
  required TaskFormOptions options,
  required List<SkillId> skillIds,
  required bool usesAutomaticSkills,
}) async {
  final SkillsFieldScene scene = SkillsFieldScene();
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SingleChildScrollView(
      child: TaskSkillsField(
        skillIds: skillIds,
        usesAutomaticSkills: usesAutomaticSkills,
        options: options,
        onSkillsChanged: scene.changedSkills.add,
        onAutomaticSkillsChanged: scene.changedAutomatic.add,
      ),
    ),
  );
  return scene;
}

Future<void> tapRemoveSkillTag(WidgetTester tester, Finder tag) async {
  await tapVisible(
    tester,
    find.descendant(of: tag, matching: find.byType(InkWell)),
  );
  await tester.pump();
}
