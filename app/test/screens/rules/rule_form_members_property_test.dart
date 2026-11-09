import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/rules/rule_form.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../../support/sample_scopes.dart';
import '../../support/widget_harness.dart';
import 'rule_form_probe.dart';

void _ignoreDraft(RuleDraft draft) {}

void _ignoreLeave() {}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  test('test_rule_form_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(107201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RuleDraft initialRule = randomInitialRuleDraft(random, table);
      final List<FormAction<RuleDraft>> actions = <FormAction<RuleDraft>>[
        LeaveFormAction<RuleDraft>(
          label: randomText(random),
          onPressed: _ignoreLeave,
        ),
      ];
      final ValueChanged<RuleDraft>? onChanged = random.nextBool()
          ? _ignoreDraft
          : null;

      final RuleForm form = RuleForm(
        initialRule: initialRule,
        catalog: galleryCatalog,
        actions: actions,
        onChanged: onChanged,
      );

      expect(form.initialRule, same(initialRule));
      expect(form.catalog, same(galleryCatalog));
      expect(form.actions, same(actions));
      expect(form.onChanged, onChanged);
    }
  });

  testWidgets('test_rule_form_constructor_property_fields_start_from_the_'
      'initial_rule', (WidgetTester tester) async {
    final Random random = seededRandom(107202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleDraft initialRule = randomInitialRuleDraft(random, table);
      await pumpRuleFormAtRandomWidth(
        tester,
        random,
        initialRule: initialRule,
      );

      final ScopeSelection selection = ScopeSelection.fromScope(
        initialRule.scope,
      );
      expect(readRuleField(tester, ruleTitleLabel), initialRule.title);
      expect(readRuleField(tester, ruleDetailsLabel), initialRule.details);
      expect(readShownScopeTags(tester, 'Workspaces'), <String>[
        for (final WorkspaceId workspaceId in selection.workspaceIds)
          galleryCatalog.nameOfWorkspace(workspaceId),
      ]);
      expect(readShownScopeTags(tester, 'Projects'), <String>[
        for (final ProjectId projectId in selection.projectIds)
          galleryCatalog.nameOfProject(projectId),
      ]);
    }
  });

  testWidgets('test_rule_form_constructor_property_works_without_a_change_'
      'listener', (WidgetTester tester) async {
    final Random random = seededRandom(107203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<RuleDraft> submitted = <RuleDraft>[];
      final String title = 'Rule ${randomWordPhrase(random)}';
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: RuleForm(
          key: UniqueKey(),
          initialRule: const RuleDraft(
            title: '',
            details: '',
            scope: Scope.everywhere(),
          ),
          catalog: galleryCatalog,
          actions: <FormAction<RuleDraft>>[
            SubmitFormAction<RuleDraft>(
              label: ruleSubmitLabel,
              tone: ButtonTone.primary,
              onSubmitted: (RuleDraft draft) async => submitted.add(draft),
            ),
          ],
        ),
      );

      await enterFieldText(tester, label: ruleTitleLabel, text: title);
      await submitRuleForm(tester);

      expect(tester.takeException(), isNull);
      expect(submitted, hasLength(1));
      expect(submitted.single.title, table.trimByModel(title));
    }
  });

  test('test_rule_form_create_state_property_each_call_is_a_fresh_state', () {
    final Random random = seededRandom(107204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RuleForm form = RuleForm(
        initialRule: randomInitialRuleDraft(random, table),
        catalog: galleryCatalog,
        actions: const <FormAction<RuleDraft>>[],
      );

      final State<RuleForm> first = form.createState();
      final State<RuleForm> second = form.createState();

      expect(identical(first, second), isFalse);
      expect(first.mounted, isFalse);
      expect(second.mounted, isFalse);
    }
  });

  testWidgets('test_rule_form_create_state_property_a_new_form_starts_'
      'from_its_own_initial_rule', (WidgetTester tester) async {
    final Random random = seededRandom(107205);

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
      final RuleDraft nextRule = randomInitialRuleDraft(random, table);

      await pumpRuleFormAtRandomWidth(tester, random, initialRule: nextRule);

      expect(readRuleField(tester, ruleTitleLabel), nextRule.title);
      expect(readRuleField(tester, ruleDetailsLabel), nextRule.details);
    }
  });

  testWidgets('test_rule_form_create_state_property_typed_text_survives_'
      'rebuilds', (WidgetTester tester) async {
    final Random random = seededRandom(107206);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RuleFormProbe probe = await pumpRuleFormAtRandomWidth(
        tester,
        random,
        initialRule: randomInitialRuleDraft(random, table),
      );
      final String typed = randomText(random);
      await enterFieldText(tester, label: ruleDetailsLabel, text: typed);
      final String shown = readRuleField(tester, ruleDetailsLabel);

      final StatefulElement element = tester.element(find.byType(RuleForm));
      element.markNeedsBuild();
      await tester.pump();

      expect(readRuleField(tester, ruleDetailsLabel), shown);
      expect(probe.reported.last.details, table.trimByModel(shown));
    }
  });
}
