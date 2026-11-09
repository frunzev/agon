import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../new_items/draft_record_fields.dart';
import 'rule_form_probe.dart';

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  testWidgets('test_rule_form_change_scope_property_reports_the_chosen_'
      'scope', (WidgetTester tester) async {
    final Random random = seededRandom(107307);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await pumpRuleFormAtRandomWidth(
        tester,
        random,
        initialRule: randomInitialRuleDraft(random, table),
      );
      final ScopeSelection selection = randomScopeSelection(random);

      await chooseRuleScope(tester, selection);

      expect(
        describeScopeFields(probe.reported.last.scope),
        describeScopeFields(selection.toScope()),
      );
    }
  });

  testWidgets('test_rule_form_change_scope_property_submits_the_last_'
      'chosen_scope', (WidgetTester tester) async {
    final Random random = seededRandom(107308);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
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
      ScopeSelection lastSelection = randomScopeSelection(random);
      final int choiceCount = 1 + random.nextInt(3);
      for (int choice = 0; choice < choiceCount; choice += 1) {
        lastSelection = randomScopeSelection(random);
        await chooseRuleScope(tester, lastSelection);
      }

      await submitRuleForm(tester);

      expect(
        describeScopeFields(probe.submitted.single.scope),
        describeScopeFields(lastSelection.toScope()),
      );
    }
  });

  testWidgets('test_rule_form_change_scope_property_keeps_title_and_'
      'details', (WidgetTester tester) async {
    final Random random = seededRandom(107309);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleDraft initialRule = randomInitialRuleDraft(random, table);
      final RuleFormProbe probe = await pumpRuleFormAtRandomWidth(
        tester,
        random,
        initialRule: initialRule,
      );

      await chooseRuleScope(tester, randomScopeSelection(random));

      expect(readRuleField(tester, ruleTitleLabel), initialRule.title);
      expect(readRuleField(tester, ruleDetailsLabel), initialRule.details);
      expect(probe.reported.last.title, table.trimByModel(initialRule.title));
      expect(
        probe.reported.last.details,
        table.trimByModel(initialRule.details),
      );
    }
  });
}
