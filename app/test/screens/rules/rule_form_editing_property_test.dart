import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../new_items/draft_record_fields.dart';
import 'rule_form_probe.dart';

const RuleDraft _blankRule = RuleDraft(
  title: '',
  details: '',
  scope: Scope.everywhere(),
);

enum _RuleEdit { title, details, scope }

List<Object?> _describeDraft(RuleDraft draft) {
  return describeRuleFields(
    title: draft.title,
    details: draft.details,
    scope: draft.scope,
  );
}

String _randomChangedText(
  WidgetTester tester,
  Random random, {
  required String label,
  required RuleTitleWhiteSpaceTable table,
}) {
  final String shown = readRuleField(tester, label);
  final String exoticText = table.randomExoticTitle(random);
  final String candidate = 'Rule${exoticText.replaceAll('\n', ' ')}';
  if (candidate == shown) {
    return '${candidate}x';
  }
  return candidate;
}

Future<void> _makeEdit(
  WidgetTester tester,
  Random random,
  _RuleEdit edit,
  RuleTitleWhiteSpaceTable table,
) async {
  switch (edit) {
    case _RuleEdit.title:
      final String title = _randomChangedText(
        tester,
        random,
        label: ruleTitleLabel,
        table: table,
      );
      await enterFieldText(tester, label: ruleTitleLabel, text: title);
    case _RuleEdit.details:
      final String details = _randomChangedText(
        tester,
        random,
        label: ruleDetailsLabel,
        table: table,
      );
      await enterFieldText(tester, label: ruleDetailsLabel, text: details);
    case _RuleEdit.scope:
      await chooseRuleScope(tester, randomScopeSelection(random));
  }
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  testWidgets('test_rule_form_report_rule_property_one_report_per_edit', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(107301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await pumpRuleFormAtRandomWidth(
        tester,
        random,
        initialRule: randomInitialRuleDraft(random, table),
      );
      final int editCount = random.nextInt(6);

      for (int edit = 0; edit < editCount; edit += 1) {
        final _RuleEdit chosen = pickOne(random, _RuleEdit.values);
        await _makeEdit(tester, random, chosen, table);
      }

      expect(probe.reported, hasLength(editCount));
      expect(probe.submitted, isEmpty);
    }
  });

  testWidgets('test_rule_form_report_rule_property_last_report_is_what_'
      'submit_sends', (WidgetTester tester) async {
    final Random random = seededRandom(107302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await pumpRuleFormAtRandomWidth(
        tester,
        random,
        initialRule: randomInitialRuleDraft(random, table),
      );
      final int editCount = 1 + random.nextInt(5);
      for (int edit = 0; edit < editCount; edit += 1) {
        final _RuleEdit chosen = pickOne(random, _RuleEdit.values);
        await _makeEdit(tester, random, chosen, table);
      }
      await _makeEdit(tester, random, _RuleEdit.title, table);

      await submitRuleForm(tester);

      expect(probe.submitted, hasLength(1));
      expect(
        _describeDraft(probe.reported.last),
        _describeDraft(probe.submitted.single),
      );
    }
  });

  testWidgets('test_rule_form_report_rule_property_reports_shared_table_'
      'trimmed_text', (WidgetTester tester) async {
    final Random random = seededRandom(107303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await pumpRuleFormAtRandomWidth(
        tester,
        random,
        initialRule: randomInitialRuleDraft(random, table),
      );

      await _makeEdit(tester, random, _RuleEdit.details, table);

      final String shownTitle = readRuleField(tester, ruleTitleLabel);
      final String shownDetails = readRuleField(tester, ruleDetailsLabel);
      expect(probe.reported.last.title, table.trimByModel(shownTitle));
      expect(probe.reported.last.details, table.trimByModel(shownDetails));
    }
  });

  testWidgets('test_rule_form_change_title_property_an_edit_clears_the_'
      'title_problem', (WidgetTester tester) async {
    final Random random = seededRandom(107304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRuleFormAtRandomWidth(tester, random, initialRule: _blankRule);
      await submitRuleForm(tester);
      expect(find.text(emptyRuleTitleProblem), findsOneWidget);

      await enterFieldText(
        tester,
        label: ruleTitleLabel,
        text: '${randomText(random)}x',
      );

      expect(find.text(emptyRuleTitleProblem), findsNothing);
    }
  });

  testWidgets('test_rule_form_change_title_property_a_blank_edit_is_still_'
      'refused', (WidgetTester tester) async {
    final Random random = seededRandom(107305);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await pumpRuleFormAtRandomWidth(
        tester,
        random,
        initialRule: _blankRule,
      );
      await submitRuleForm(tester);

      await enterFieldText(
        tester,
        label: ruleTitleLabel,
        text: '${table.randomWhiteSpaceRun(random)} ',
      );
      expect(find.text(emptyRuleTitleProblem), findsNothing);
      await submitRuleForm(tester);

      expect(find.text(emptyRuleTitleProblem), findsOneWidget);
      expect(probe.submitted, isEmpty);
    }
  });

  testWidgets('test_rule_form_change_title_property_title_edits_never_'
      'submit', (WidgetTester tester) async {
    final Random random = seededRandom(107306);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await pumpRuleFormAtRandomWidth(
        tester,
        random,
        initialRule: randomInitialRuleDraft(random, table),
      );
      final int editCount = 1 + random.nextInt(4);

      for (int edit = 0; edit < editCount; edit += 1) {
        await _makeEdit(tester, random, _RuleEdit.title, table);
      }

      final String shownTitle = readRuleField(tester, ruleTitleLabel);
      expect(probe.submitted, isEmpty);
      expect(probe.reported.last.title, table.trimByModel(shownTitle));
    }
  });
}
