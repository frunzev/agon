import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/screens/skills/skill_form.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/random_nowhere_scopes.dart';
import '../../support/sample_scopes.dart';
import '../../support/widget_harness.dart';
import '../support/planned_refusal.dart';

const String _saveSkillLabel = 'Save skill';
const String _cancelLabel = 'Cancel';
const int _largestNameNumber = 100000;

final class _SkillFormProbe {
  _SkillFormProbe({required this.initialSkill});

  final SkillDraft initialSkill;
  final List<SkillDraft> submitted = <SkillDraft>[];
  final PlannedRefusal refusal = PlannedRefusal();
  Completer<void>? pendingSave;

  Widget build() {
    return SkillForm(
      key: UniqueKey(),
      initialSkill: initialSkill,
      otherSkills: const <Skill>[],
      catalog: galleryCatalog,
      actions: <FormAction<SkillDraft>>[
        LeaveFormAction<SkillDraft>(label: _cancelLabel, onPressed: () {}),
        SubmitFormAction<SkillDraft>(
          label: _saveSkillLabel,
          tone: ButtonTone.primary,
          onSubmitted: _save,
        ),
      ],
    );
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

SkillDraft _randomValidSkill(Random random) {
  return SkillDraft(
    name: 'skill-${random.nextInt(_largestNameNumber)}',
    summary: 'Summary ${randomText(random)}'.trim(),
    instructions: 'Steps ${randomText(random)}',
    scope: randomScopeOrNowhere(random),
    usage: pickOne(random, SkillUsage.values),
    improvement: pickOne(random, SkillImprovement.values),
  );
}

Future<_SkillFormProbe> _pumpValidForm(
  WidgetTester tester,
  Random random,
) async {
  final _SkillFormProbe probe = _SkillFormProbe(
    initialSkill: _randomValidSkill(random),
  );
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(tester, width: width, child: probe.build());
  await tester.pump(settleTime);
  return probe;
}

Finder _findSaveButton() {
  return find.widgetWithText(AppButton, _saveSkillLabel);
}

List<VoidCallback?> _readButtonCallbacks(WidgetTester tester) {
  final List<VoidCallback?> callbacks = <VoidCallback?>[];
  for (final AppButton button in tester.widgetList<AppButton>(
    find.byType(AppButton),
  )) {
    callbacks.add(button.onPressed);
  }
  return callbacks;
}

List<Object?> _describeSkill(SkillDraft skill) {
  return <Object?>[
    skill.name,
    skill.summary,
    skill.instructions,
    skill.usage,
    skill.improvement,
  ];
}

void main() {
  testWidgets('test_skill_form_submit_property_a_double_tap_saves_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(110301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _SkillFormProbe probe = await _pumpValidForm(tester, random);
      final Completer<void> pending = Completer<void>();
      probe.pendingSave = pending;
      await tester.ensureVisible(_findSaveButton());
      await tester.pump();

      await tester.tap(_findSaveButton());
      await tester.tap(_findSaveButton());
      pending.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(probe.submitted, hasLength(1));
    }
  });

  testWidgets('test_skill_form_submit_property_buttons_wait_while_saving', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(110302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _SkillFormProbe probe = await _pumpValidForm(tester, random);
      final Completer<void> pending = Completer<void>();
      probe.pendingSave = pending;

      await tapVisible(tester, _findSaveButton());
      await tester.pump();
      final List<VoidCallback?> whileSaving = _readButtonCallbacks(tester);
      pending.complete();
      await tester.pump();

      expect(whileSaving, everyElement(isNull));
      expect(_readButtonCallbacks(tester), everyElement(isNotNull));
      expect(probe.submitted, hasLength(1));
    }
  });

  testWidgets('test_skill_form_submit_property_a_save_after_a_refusal_'
      'sends_the_same_skill', (WidgetTester tester) async {
    final Random random = seededRandom(110303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _SkillFormProbe probe = await _pumpValidForm(tester, random);
      final ExplainedRefusal planned = randomExplainedRefusal(random);
      probe.refusal.problem = planned.problem;
      await tapVisible(tester, _findSaveButton());
      await tester.pump();
      expect(find.text(planned.explanation), findsOneWidget);
      probe.refusal.problem = null;

      await tapVisible(tester, _findSaveButton());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(probe.submitted, hasLength(2));
      expect(
        _describeSkill(probe.submitted.last),
        _describeSkill(probe.submitted.first),
      );
      expect(
        _describeSkill(probe.submitted.first),
        _describeSkill(probe.initialSkill),
      );
    }
  });
}
