import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/rules/rule_form.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../support/planned_refusal.dart';
import 'rule_form_probe.dart';

const String _detailsHint =
    'Agents read the rule and its details in AGENTS.md.';
const List<String> _shownLabels = <String>[
  ruleTitleLabel,
  ruleDetailsLabel,
  'Workspaces',
  'Projects',
  _detailsHint,
  ruleLeaveLabel,
  ruleSubmitLabel,
];

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  testWidgets('test_rule_form_dispose_property_removing_the_form_is_'
      'quiet', (WidgetTester tester) async {
    final Random random = seededRandom(107207);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRuleFormAtRandomWidth(
        tester,
        random,
        initialRule: randomInitialRuleDraft(random, table),
      );
      await enterFieldText(
        tester,
        label: ruleTitleLabel,
        text: randomText(random),
      );

      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isNull);
      expect(find.byType(RuleForm), findsNothing);
    }
  });

  testWidgets('test_rule_form_dispose_property_a_save_ending_after_removal_'
      'is_quiet', (WidgetTester tester) async {
    final Random random = seededRandom(107208);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await pumpRuleFormAtRandomWidth(
        tester,
        random,
        initialRule: const RuleDraft(
          title: 'Keep tests green',
          details: '',
          scope: Scope.everywhere(),
        ),
      );
      final Completer<void> pending = Completer<void>();
      probe.pendingSave = pending;
      probe.plannedProblem = random.nextBool()
          ? randomExplainedRefusal(random).problem
          : null;
      await submitRuleForm(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(probe.submitted, hasLength(1));
    }
  });

  testWidgets('test_rule_form_dispose_property_removal_stops_reports', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(107209);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await pumpRuleFormAtRandomWidth(
        tester,
        random,
        initialRule: randomInitialRuleDraft(random, table),
      );
      await enterFieldText(
        tester,
        label: ruleTitleLabel,
        text: randomText(random),
      );
      final int reportsBeforeRemoval = probe.reported.length;

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(probe.reported, hasLength(reportsBeforeRemoval));
    }
  });

  testWidgets('test_rule_form_build_property_shows_every_part_at_any_'
      'width', (WidgetTester tester) async {
    final Random random = seededRandom(107210);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRuleFormAtRandomWidth(
        tester,
        random,
        initialRule: randomInitialRuleDraft(random, table),
      );

      expect(tester.takeException(), isNull);
      for (final String label in _shownLabels) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text(emptyRuleTitleProblem), findsNothing);
    }
  });

  testWidgets('test_rule_form_build_property_leaving_never_submits', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(107211);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await pumpRuleFormAtRandomWidth(
        tester,
        random,
        initialRule: randomInitialRuleDraft(random, table),
      );
      final int taps = 1 + random.nextInt(3);

      for (int tap = 0; tap < taps; tap += 1) {
        await tapVisible(tester, findRuleFormButton(ruleLeaveLabel));
        await tester.pump();
      }

      expect(probe.leaveTaps, taps);
      expect(probe.submitted, isEmpty);
    }
  });

  testWidgets('test_rule_form_build_property_details_grow_but_title_stays_'
      'one_line', (WidgetTester tester) async {
    final Random random = seededRandom(107212);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRuleFormAtRandomWidth(
        tester,
        random,
        initialRule: randomInitialRuleDraft(random, table),
      );

      final TextField title = tester.widget<TextField>(
        findFieldInput(ruleTitleLabel),
      );
      final TextField details = tester.widget<TextField>(
        findFieldInput(ruleDetailsLabel),
      );
      expect(title.maxLines, 1);
      expect(details.minLines, 3);
      expect(details.maxLines, greaterThan(3));
    }
  });
}
