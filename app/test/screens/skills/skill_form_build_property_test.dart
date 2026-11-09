import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'skill_form_probe.dart';

const List<String> _designTextsInOrder = <String>[
  skillNameLabel,
  skillSummaryLabel,
  'Agents read this to decide when the skill fits.',
  skillInstructionsLabel,
  'Workspaces',
  'All workspaces unless you add some.',
  'Projects',
  'All projects unless you add some, from the workspaces above.',
  'When agents use it',
  'Automatic',
  'Any agent can use it when the work fits.',
  'Only when chosen',
  'A task, job or workflow agent has to add it.',
  'Agents may improve it',
  'Never',
  'Agents never change this skill.',
  'Ask me',
  'An agent that used it may propose a better version for you to approve.',
  'Auto',
  "An agent's better version is saved at once. You can undo it.",
];
const int _designInstructionRows = 6;
const String _nonBlankMark = 'x';

SkillDraft _randomEverywhereDraft(Random random) {
  return copySkillDraft(
    randomValidSkillDraft(random),
    scope: const Scope.everywhere(),
  );
}

void main() {
  testWidgets('test_skill_form_build_property_shows_the_design_wording_in_'
      'order_at_any_width', (WidgetTester tester) async {
    final Random random = seededRandom(1120601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: _randomEverywhereDraft(random),
        otherSkills: const <Skill>[],
      );
      final double width = await pumpSkillFormProbe(tester, random, probe);

      double previousTop = double.negativeInfinity;
      for (final String text in _designTextsInOrder) {
        final Finder shown = find.text(text);
        expect(shown, findsOneWidget, reason: text);
        final double top = tester.getTopLeft(shown).dy;
        expect(top, greaterThanOrEqualTo(previousTop), reason: text);
        expect(tester.getRect(shown).right, lessThanOrEqualTo(width));
        previousTop = top;
      }
      expect(tester.takeException(), isNull, reason: '$width');
    }
  });

  testWidgets('test_skill_form_build_property_hostile_skills_never_overflow', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1120602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillDraft hostile = copySkillDraft(
        randomValidSkillDraft(random),
        name: 'a' * (1 + random.nextInt(200)),
        summary: randomText(random) * (1 + random.nextInt(8)),
        instructions: List<String>.filled(
          1 + random.nextInt(30),
          'line',
        ).join('\n'),
      );
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: hostile,
        otherSkills: const <Skill>[],
      );
      final double width = await pumpSkillFormProbe(tester, random, probe);

      await tapSaveSkill(tester);

      expect(tester.takeException(), isNull, reason: '$width');
      expect(find.text(saveSkillLabel), findsOneWidget);
    }
  });

  testWidgets('test_skill_form_build_property_name_and_instructions_are_'
      'plain_monospace', (WidgetTester tester) async {
    final Random random = seededRandom(1120603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: randomValidSkillDraft(random),
        otherSkills: const <Skill>[],
      );
      await pumpSkillFormProbe(tester, random, probe);

      final TextField name = tester.widget<TextField>(
        findFieldInput(skillNameLabel),
      );
      final TextField instructions = tester.widget<TextField>(
        findFieldInput(skillInstructionsLabel),
      );
      expect(name.autocorrect, isFalse);
      expect(name.style?.fontFamily, AppFontFamilies.monospace);
      expect(instructions.style?.fontFamily, AppFontFamilies.monospace);
      expect(instructions.minLines, _designInstructionRows);
      expect(instructions.maxLines, greaterThan(_designInstructionRows));
    }
  });

  testWidgets('test_describe_empty_problem_property_blank_texts_are_refused', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1120604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: randomValidSkillDraft(random),
        otherSkills: const <Skill>[],
      );
      await pumpSkillFormProbe(tester, random, probe);
      await enterFieldText(
        tester,
        label: skillSummaryLabel,
        text: pickOne(random, blankTexts),
      );
      await enterFieldText(
        tester,
        label: skillInstructionsLabel,
        text: pickOne(random, blankTexts),
      );

      await tapSaveSkill(tester);

      expect(readFieldProblem(tester, skillSummaryLabel), emptySummaryProblem);
      expect(
        readFieldProblem(tester, skillInstructionsLabel),
        emptyInstructionsProblem,
      );
      expect(readFieldProblem(tester, skillNameLabel), isNull);
      expect(probe.submitted, isEmpty);
    }
  });

  testWidgets('test_describe_empty_problem_property_any_visible_text_passes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1120605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: randomValidSkillDraft(random),
        otherSkills: const <Skill>[],
      );
      await pumpSkillFormProbe(tester, random, probe);
      final String summary =
          '${pickOne(random, blankTexts)}$_nonBlankMark'
          '${pickOne(random, blankTexts)}';
      final String instructions =
          '${pickOne(random, blankTexts)}$_nonBlankMark'
          '${pickOne(random, blankTexts)}';
      await enterFieldText(tester, label: skillSummaryLabel, text: summary);
      await enterFieldText(
        tester,
        label: skillInstructionsLabel,
        text: instructions,
      );

      await tapSaveSkill(tester);

      expect(readFieldProblems(tester), everyElement(isNull));
      expect(probe.submitted, hasLength(1));
      expect(probe.submitted.single.summary, summary.trim());
      expect(probe.submitted.single.instructions, instructions);
    }
  });

  testWidgets('test_describe_empty_problem_property_each_field_is_judged_'
      'alone', (WidgetTester tester) async {
    final Random random = seededRandom(1120606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: randomValidSkillDraft(random),
        otherSkills: const <Skill>[],
      );
      await pumpSkillFormProbe(tester, random, probe);
      final bool isSummaryBlank = random.nextBool();
      final bool isInstructionsBlank = random.nextBool();
      if (isSummaryBlank) {
        await enterFieldText(tester, label: skillSummaryLabel, text: ' ');
      }
      if (isInstructionsBlank) {
        await enterFieldText(tester, label: skillInstructionsLabel, text: '');
      }

      await tapSaveSkill(tester);

      final String? summaryProblem = isSummaryBlank
          ? emptySummaryProblem
          : null;
      final String? instructionsProblem = isInstructionsBlank
          ? emptyInstructionsProblem
          : null;
      expect(readFieldProblems(tester), <String?>[
        null,
        summaryProblem,
        instructionsProblem,
      ]);
      final bool isSaved = !isSummaryBlank && !isInstructionsBlank;
      expect(probe.submitted, hasLength(isSaved ? 1 : 0));
    }
  });
}
