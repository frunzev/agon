import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import 'rules_screen_page.dart';

const String _explanation =
    'Agents stop getting it in AGENTS.md from their next run.';
const String _keepLabel = 'Keep rule';
const String _deleteLabel = 'Delete rule';

final class _DeletionRefusingRuleRepository implements RuleRepository {
  _DeletionRefusingRuleRepository({
    required this.stored,
    required this.refusal,
  });

  final RuleRepository stored;
  final PlannedRefusal refusal;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Rule> listRules() => stored.listRules();

  @override
  Rule findRule(RuleId ruleId) => stored.findRule(ruleId);

  @override
  Future<Rule> createRule(RuleDraft draft) => stored.createRule(draft);

  @override
  Future<Rule> updateRule(RuleId ruleId, RuleDraft draft) {
    return stored.updateRule(ruleId, draft);
  }

  @override
  Future<Rule> turnRuleOn(RuleId ruleId) => stored.turnRuleOn(ruleId);

  @override
  Future<Rule> turnRuleOff(RuleId ruleId) => stored.turnRuleOff(ruleId);

  @override
  Future<void> deleteRule(RuleId ruleId) {
    return refusal.refuseOr(() => stored.deleteRule(ruleId));
  }
}

typedef _DeletionPage = ({
  RuleRepository rules,
  AppNavigation navigation,
  PlannedRefusal refusal,
  Rule rule,
});

Future<_DeletionPage> _openDeletion(WidgetTester tester, Random random) async {
  final AppDependencies listed = buildRulesScreenDependencies(
    rules: randomNonEmptyListedRules(random, hasProjects: true),
    hasProjects: true,
  );
  final PlannedRefusal refusal = PlannedRefusal();
  final RuleRepository rules = _DeletionRefusingRuleRepository(
    stored: listed.ruleRepository,
    refusal: refusal,
  );
  final Rule rule = pickOne(random, rules.listRules());
  final AppNavigation navigation = await openRuleDetailPage(
    tester,
    random,
    dependencies: replaceRepositories(listed, ruleRepository: rules),
    ruleId: rule.id,
  );
  await tapVisible(tester, find.widgetWithText(AppButton, 'Delete'));
  await pumpFrames(tester);
  return (rules: rules, navigation: navigation, refusal: refusal, rule: rule);
}

List<RuleId> _listRuleIds(RuleRepository rules) {
  return <RuleId>[for (final Rule rule in rules.listRules()) rule.id];
}

void main() {
  testWidgets('test_rule_detail_screen_review_deletion_property_deleting_'
      'leaves_for_the_rules', (WidgetTester tester) async {
    final Random random = seededRandom(108001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeletionPage page = await _openDeletion(tester, random);
      final List<RuleId> idsBefore = _listRuleIds(page.rules);
      expect(find.text('Delete "${page.rule.title}"?'), findsOneWidget);
      expect(find.text(_explanation), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(AppButton, _deleteLabel));
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(page.navigation.routes, const <AppRoute>[rulesRoute]);
      expect(_listRuleIds(page.rules), <RuleId>[
        for (final RuleId ruleId in idsBefore)
          if (ruleId != page.rule.id) ruleId,
      ]);
    }
  });

  testWidgets('test_rule_detail_screen_review_deletion_property_keeping_'
      'changes_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(108002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeletionPage page = await _openDeletion(tester, random);
      final List<RuleId> idsBefore = _listRuleIds(page.rules);

      await tapVisible(tester, find.widgetWithText(AppButton, _keepLabel));
      await pumpFrames(tester);

      expect(page.refusal.attempts, 0);
      expect(_listRuleIds(page.rules), idsBefore);
      expect(page.navigation.routes, <AppRoute>[
        rulesRoute,
        RuleDetailRoute(page.rule.id),
      ]);
      expect(find.text(_explanation), findsNothing);
    }
  });

  testWidgets('test_rule_detail_screen_review_deletion_property_a_refusal_'
      'comes_back_with_the_reason', (WidgetTester tester) async {
    final Random random = seededRandom(108003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeletionPage page = await _openDeletion(tester, random);
      final List<RuleId> idsBefore = _listRuleIds(page.rules);
      final ExplainedRefusal planned = randomExplainedRefusal(random);
      page.refusal.problem = planned.problem;

      await tapVisible(tester, find.widgetWithText(AppButton, _deleteLabel));
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(page.refusal.attempts, 1);
      expect(find.text('$_deleteLabel did not work'), findsOneWidget);
      expect(find.text(planned.explanation), findsOneWidget);
      expect(_listRuleIds(page.rules), idsBefore);
      expect(page.navigation.routes, <AppRoute>[
        rulesRoute,
        RuleDetailRoute(page.rule.id),
      ]);
    }
  });
}
