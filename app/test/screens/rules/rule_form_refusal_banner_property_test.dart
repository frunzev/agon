import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/screens/task_form/submit_refusal.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../new_items/draft_record_fields.dart';
import '../support/planned_refusal.dart';
import 'rule_form_probe.dart';

const String _refusalTitle = '$ruleSubmitLabel did not work';

Future<RuleFormProbe> _pumpTitledForm(
  WidgetTester tester,
  Random random,
  RuleTitleWhiteSpaceTable table,
) async {
  final RuleFormProbe probe = await pumpRuleFormAtRandomWidth(
    tester,
    random,
    initialRule: randomInitialRuleDraft(random, table),
  );
  await enterFieldText(
    tester,
    label: ruleTitleLabel,
    text: 'Rule ${randomText(random)}',
  );
  return probe;
}

List<Object?> _describeDraft(RuleDraft draft) {
  return describeRuleFields(
    title: draft.title,
    details: draft.details,
    scope: draft.scope,
  );
}

List<VoidCallback?> _readButtonCallbacks(WidgetTester tester) {
  return <VoidCallback?>[
    for (final AppButton button in tester.widgetList<AppButton>(
      find.byType(AppButton),
    ))
      button.onPressed,
  ];
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  testWidgets('test_rule_form_build_refusal_banner_property_no_banner_'
      'without_a_refusal', (WidgetTester tester) async {
    final Random random = seededRandom(107401);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await _pumpTitledForm(tester, random, table);
      expect(find.byType(SubmitRefusalBanner), findsNothing);

      await submitRuleForm(tester);

      expect(probe.submitted, hasLength(1));
      expect(find.byType(SubmitRefusalBanner), findsNothing);
      expect(find.text(_refusalTitle), findsNothing);
    }
  });

  testWidgets('test_rule_form_build_refusal_banner_property_shows_the_'
      'explanation', (WidgetTester tester) async {
    final Random random = seededRandom(107402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await _pumpTitledForm(tester, random, table);
      final ExplainedRefusal planned = randomExplainedRefusal(random);
      probe.plannedProblem = planned.problem;

      await submitRuleForm(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(SubmitRefusalBanner), findsOneWidget);
      expect(find.text(_refusalTitle), findsOneWidget);
      expect(find.text(planned.explanation), findsOneWidget);
    }
  });

  testWidgets('test_rule_form_build_refusal_banner_property_the_next_'
      'submit_clears_it', (WidgetTester tester) async {
    final Random random = seededRandom(107403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await _pumpTitledForm(tester, random, table);
      probe.plannedProblem = randomExplainedRefusal(random).problem;
      await submitRuleForm(tester);
      probe.plannedProblem = null;
      final bool blanksTitle = random.nextBool();
      if (blanksTitle) {
        await enterFieldText(
          tester,
          label: ruleTitleLabel,
          text: table.randomWhiteSpaceRun(random),
        );
      }

      await submitRuleForm(tester);

      final Matcher problemShown = blanksTitle ? findsOneWidget : findsNothing;
      expect(find.byType(SubmitRefusalBanner), findsNothing);
      expect(find.text(emptyRuleTitleProblem), problemShown);
    }
  });

  testWidgets('test_rule_form_submit_property_a_double_tap_saves_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(107404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await _pumpTitledForm(tester, random, table);
      final Completer<void> pending = Completer<void>();
      probe.pendingSave = pending;
      final Finder save = findRuleFormButton(ruleSubmitLabel);
      await tester.pump(settleTime);
      await tester.ensureVisible(save);
      await tester.pump();

      await tester.tap(save);
      await tester.tap(save);
      pending.complete();
      await tester.pump();

      expect(probe.submitted, hasLength(1));
    }
  });

  testWidgets('test_rule_form_submit_property_buttons_wait_while_saving', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(107405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await _pumpTitledForm(tester, random, table);
      final Completer<void> pending = Completer<void>();
      probe.pendingSave = pending;

      await submitRuleForm(tester);
      final List<VoidCallback?> whileSaving = _readButtonCallbacks(tester);
      pending.complete();
      await tester.pump();

      expect(whileSaving, everyElement(isNull));
      expect(_readButtonCallbacks(tester), everyElement(isNotNull));
    }
  });

  testWidgets('test_rule_form_submit_property_a_refused_save_keeps_the_'
      'typed_rule', (WidgetTester tester) async {
    final Random random = seededRandom(107406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await _pumpTitledForm(tester, random, table);
      final String typedTitle = readRuleField(tester, ruleTitleLabel);
      final String typedDetails = readRuleField(tester, ruleDetailsLabel);
      probe.plannedProblem = randomExplainedRefusal(random).problem;
      await submitRuleForm(tester);
      probe.plannedProblem = null;

      await submitRuleForm(tester);

      expect(readRuleField(tester, ruleTitleLabel), typedTitle);
      expect(readRuleField(tester, ruleDetailsLabel), typedDetails);
      expect(probe.submitted, hasLength(2));
      expect(
        _describeDraft(probe.submitted.last),
        _describeDraft(probe.submitted.first),
      );
    }
  });
}
