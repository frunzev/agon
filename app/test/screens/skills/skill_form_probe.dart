import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/skills/skill_form.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_scopes.dart';
import '../../support/widget_harness.dart';
import '../support/planned_refusal.dart';
import 'random_skills.dart';

const String saveSkillLabel = 'Save skill';
const String cancelSkillLabel = 'Cancel';
const String skillNameLabel = 'Name';
const String skillSummaryLabel = 'What it does';
const String skillInstructionsLabel = 'Instructions';
const String emptySummaryProblem = 'Say what the skill does';
const String emptyInstructionsProblem = 'Write the instructions';
const List<String> blankTexts = <String>[
  '',
  ' ',
  '\t',
  '\n',
  '  \n ',
  ' ',
  '　',
];

final class SkillFormProbe {
  SkillFormProbe({required this.initialSkill, required this.otherSkills});

  final SkillDraft initialSkill;
  final List<Skill> otherSkills;
  final List<SkillDraft> submitted = <SkillDraft>[];
  final List<SkillDraft> reported = <SkillDraft>[];
  final PlannedRefusal refusal = PlannedRefusal();
  int cancelCount = 0;
  Completer<void>? pendingSave;

  SkillForm build() {
    return SkillForm(
      key: UniqueKey(),
      initialSkill: initialSkill,
      otherSkills: otherSkills,
      catalog: galleryCatalog,
      onChanged: reported.add,
      actions: <FormAction<SkillDraft>>[
        LeaveFormAction<SkillDraft>(
          label: cancelSkillLabel,
          onPressed: _countCancel,
        ),
        SubmitFormAction<SkillDraft>(
          label: saveSkillLabel,
          tone: ButtonTone.primary,
          onSubmitted: _save,
        ),
      ],
    );
  }

  void _countCancel() {
    cancelCount += 1;
  }

  Future<void> _save(SkillDraft skill) async {
    submitted.add(skill);
    final Completer<void>? pending = pendingSave;
    if (pending != null) {
      await pending.future;
    }
    await refusal.refuseOr(Future<void>.value);
  }
}

SkillDraft randomValidSkillDraft(Random random) {
  return SkillDraft(
    name: randomValidSkillName(random),
    summary: 'Summary ${randomText(random)}'.trim(),
    instructions: randomInstructions(random),
    scope: randomSkillScope(random),
    usage: pickOne(random, SkillUsage.values),
    improvement: pickOne(random, SkillImprovement.values),
  );
}

SkillDraft copySkillDraft(
  SkillDraft draft, {
  String? name,
  String? summary,
  String? instructions,
  Scope? scope,
}) {
  return SkillDraft(
    name: name ?? draft.name,
    summary: summary ?? draft.summary,
    instructions: instructions ?? draft.instructions,
    scope: scope ?? draft.scope,
    usage: draft.usage,
    improvement: draft.improvement,
  );
}

Future<double> pumpSkillFormProbe(
  WidgetTester tester,
  Random random,
  SkillFormProbe probe,
) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(tester, width: width, child: probe.build());
  return width;
}

Finder findSkillFormButton(String label) {
  return find.widgetWithText(AppButton, label);
}

Future<void> tapSaveSkill(WidgetTester tester) async {
  await tapVisible(tester, findSkillFormButton(saveSkillLabel));
  await tester.pump();
}

String? readFieldProblem(WidgetTester tester, String label) {
  final TextField field = tester.widget<TextField>(findFieldInput(label));
  return field.decoration?.errorText;
}

List<String?> readFieldProblems(WidgetTester tester) {
  return <String?>[
    readFieldProblem(tester, skillNameLabel),
    readFieldProblem(tester, skillSummaryLabel),
    readFieldProblem(tester, skillInstructionsLabel),
  ];
}

Future<void> showEveryFieldProblem(WidgetTester tester) async {
  await enterFieldText(tester, label: skillNameLabel, text: '');
  await enterFieldText(tester, label: skillSummaryLabel, text: ' ');
  await enterFieldText(tester, label: skillInstructionsLabel, text: ' ');
  await tapSaveSkill(tester);
  expect(readFieldProblems(tester), everyElement(isNotNull));
}
