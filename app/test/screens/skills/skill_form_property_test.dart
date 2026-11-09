import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/screens/skills/skill_form.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_scopes.dart';
import '../../support/widget_harness.dart';
import '../support/planned_refusal.dart';
import 'random_skills.dart';
import 'skill_form_probe.dart';

const List<String> _choiceTitles = <String>[
  'Automatic',
  'Only when chosen',
  'Never',
  'Ask me',
  'Auto',
];

void _ignoreSkill(SkillDraft _) {}

List<String> _readShownFieldTexts(WidgetTester tester) {
  return <String>[
    for (final String label in <String>[
      skillNameLabel,
      skillSummaryLabel,
      skillInstructionsLabel,
    ])
      tester.widget<TextField>(findFieldInput(label)).controller!.text,
  ];
}

List<String> _readButtonLabels(WidgetTester tester) {
  return <String>[
    for (final AppButton button in tester.widgetList<AppButton>(
      find.byType(AppButton),
    ))
      button.label,
  ];
}

void main() {
  test('test_skill_form_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(1120501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillDraft initialSkill = randomValidSkillDraft(random);
      final List<Skill> otherSkills = randomSkills(random);
      final List<FormAction<SkillDraft>> actions = <FormAction<SkillDraft>>[
        LeaveFormAction<SkillDraft>(
          label: randomText(random),
          onPressed: () {},
        ),
      ];
      final ValueChanged<SkillDraft>? onChanged = random.nextBool()
          ? _ignoreSkill
          : null;

      final SkillForm form = SkillForm(
        initialSkill: initialSkill,
        otherSkills: otherSkills,
        catalog: galleryCatalog,
        actions: actions,
        onChanged: onChanged,
      );

      expect(form.initialSkill, same(initialSkill));
      expect(form.otherSkills, same(otherSkills));
      expect(form.catalog, same(galleryCatalog));
      expect(form.actions, same(actions));
      expect(form.onChanged, same(onChanged));
    }
  });

  testWidgets('test_skill_form_constructor_property_editing_without_a_'
      'listener_is_safe', (WidgetTester tester) async {
    final Random random = seededRandom(1120502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: randomValidSkillDraft(random),
        otherSkills: const <Skill>[],
      );
      final SkillForm withListener = probe.build();
      final SkillForm quiet = SkillForm(
        key: UniqueKey(),
        initialSkill: withListener.initialSkill,
        otherSkills: withListener.otherSkills,
        catalog: withListener.catalog,
        actions: withListener.actions,
      );
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: quiet,
      );

      await enterFieldText(tester, label: skillNameLabel, text: 'x');
      await tapVisible(tester, find.text(pickOne(random, _choiceTitles)));
      await tester.pump();
      await tapSaveSkill(tester);

      expect(tester.takeException(), isNull);
      expect(probe.reported, isEmpty);
      expect(probe.submitted, hasLength(1));
    }
  });

  testWidgets('test_skill_form_constructor_property_actions_become_the_'
      'buttons_in_order', (WidgetTester tester) async {
    final Random random = seededRandom(1120503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: randomValidSkillDraft(random),
        otherSkills: const <Skill>[],
      );
      await pumpSkillFormProbe(tester, random, probe);

      expect(_readButtonLabels(tester), <String>[
        cancelSkillLabel,
        saveSkillLabel,
      ]);
      await tapVisible(tester, findSkillFormButton(cancelSkillLabel));
      await tester.pump();
      expect(probe.cancelCount, 1);
      expect(probe.submitted, isEmpty);
    }
  });

  testWidgets('test_skill_form_create_state_property_starts_from_the_'
      'initial_skill', (WidgetTester tester) async {
    final Random random = seededRandom(1120504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillDraft initial = randomValidSkillDraft(random);
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: initial,
        otherSkills: const <Skill>[],
      );
      await pumpSkillFormProbe(tester, random, probe);

      expect(_readShownFieldTexts(tester), <String>[
        initial.name,
        initial.summary,
        initial.instructions,
      ]);
      final ChoiceListField<SkillUsage> usage = tester
          .widget<ChoiceListField<SkillUsage>>(
            find.byType(ChoiceListField<SkillUsage>),
          );
      final ChoiceListField<SkillImprovement> improvement = tester
          .widget<ChoiceListField<SkillImprovement>>(
            find.byType(ChoiceListField<SkillImprovement>),
          );
      expect(usage.selected, initial.usage);
      expect(improvement.selected, initial.improvement);
      expect(readFieldProblems(tester), everyElement(isNull));
    }
  });

  testWidgets('test_skill_form_create_state_property_a_new_form_forgets_'
      'edits_and_problems', (WidgetTester tester) async {
    final Random random = seededRandom(1120505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillDraft initial = randomValidSkillDraft(random);
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: initial,
        otherSkills: const <Skill>[],
      );
      await pumpSkillFormProbe(tester, random, probe);
      await showEveryFieldProblem(tester);

      await pumpSkillFormProbe(tester, random, probe);

      expect(readFieldProblems(tester), everyElement(isNull));
      expect(_readShownFieldTexts(tester).first, initial.name);
    }
  });

  testWidgets('test_skill_form_create_state_property_an_untouched_save_'
      'sends_the_initial_skill', (WidgetTester tester) async {
    final Random random = seededRandom(1120506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillDraft initial = randomValidSkillDraft(random);
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: initial,
        otherSkills: const <Skill>[],
      );
      await pumpSkillFormProbe(tester, random, probe);

      await tapSaveSkill(tester);

      expect(probe.submitted, hasLength(1));
      expect(
        describeSkillDraftFields(probe.submitted.single),
        describeSkillDraftFields(initial),
      );
    }
  });

  testWidgets('test_skill_form_dispose_property_leaving_during_a_save_is_'
      'safe', (WidgetTester tester) async {
    final Random random = seededRandom(1120507);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: randomValidSkillDraft(random),
        otherSkills: const <Skill>[],
      );
      final Completer<void> pending = Completer<void>();
      probe.pendingSave = pending;
      if (random.nextBool()) {
        probe.refusal.problem = randomExplainedRefusal(random).problem;
      }
      await pumpSkillFormProbe(tester, random, probe);
      await tapSaveSkill(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(probe.submitted, hasLength(1));
    }
  });

  testWidgets('test_skill_form_dispose_property_leaving_with_problems_is_'
      'safe', (WidgetTester tester) async {
    final Random random = seededRandom(1120508);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: randomValidSkillDraft(random),
        otherSkills: const <Skill>[],
      );
      await pumpSkillFormProbe(tester, random, probe);
      await showEveryFieldProblem(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SkillForm), findsNothing);
      expect(probe.submitted, isEmpty);
    }
  });

  testWidgets('test_skill_form_dispose_property_a_late_reply_reaches_no_'
      'other_form', (WidgetTester tester) async {
    final Random random = seededRandom(1120509);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe leaving = SkillFormProbe(
        initialSkill: randomValidSkillDraft(random),
        otherSkills: const <Skill>[],
      );
      final Completer<void> pending = Completer<void>();
      leaving.pendingSave = pending;
      final ExplainedRefusal planned = randomExplainedRefusal(random);
      leaving.refusal.problem = planned.problem;
      await pumpSkillFormProbe(tester, random, leaving);
      await tapSaveSkill(tester);
      final SkillFormProbe next = SkillFormProbe(
        initialSkill: randomValidSkillDraft(random),
        otherSkills: const <Skill>[],
      );

      await pumpSkillFormProbe(tester, random, next);
      pending.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(planned.explanation), findsNothing);
      expect(find.text('$saveSkillLabel did not work'), findsNothing);
    }
  });
}
