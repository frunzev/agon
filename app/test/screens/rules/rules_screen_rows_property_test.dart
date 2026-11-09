import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';
import 'package:agent_orchestration/widgets/label_chip.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_scopes.dart';
import 'rules_screen_page.dart';

const String _newRuleLabel = 'New rule';

List<String> _modelScopeChips(Scope scope) {
  final WorkspaceScope workspaces = scope.workspaces;
  final ProjectScope projects = scope.projects;
  final List<String> chips = <String>[];
  if (workspaces is OnlyWorkspaces) {
    if (workspaces.workspaces.isEmpty) {
      return const <String>['Nowhere'];
    }
    for (final WorkspaceId workspaceId in workspaces.workspaces) {
      chips.add(galleryCatalog.nameOfWorkspace(workspaceId));
    }
  }
  if (projects is OnlyProjects) {
    if (projects.projects.isEmpty) {
      return const <String>['Nowhere'];
    }
    for (final ProjectId projectId in projects.projects) {
      chips.add(galleryCatalog.nameOfProject(projectId));
    }
  }
  if (chips.isEmpty) {
    return const <String>['Everywhere'];
  }
  return chips;
}

List<List<String>> _readRowChips(WidgetTester tester) {
  return <List<String>>[
    for (final ChipList chips in tester.widgetList<ChipList>(
      find.byType(ChipList),
    ))
      chips.labels,
  ];
}

List<SwitchToggle> _readSwitches(WidgetTester tester) {
  return tester.widgetList<SwitchToggle>(find.byType(SwitchToggle)).toList();
}

Finder _findSwitchFor(Rule rule) {
  final String label = 'Use "${rule.title}"';
  return find.byWidgetPredicate(
    (Widget widget) => widget is SwitchToggle && widget.semanticLabel == label,
  );
}

List<List<Object?>> _describeStoredRules(RulesScreenPage page) {
  return <List<Object?>>[
    for (final Rule rule in page.dependencies.ruleRepository.listRules())
      <Object?>[rule.id, rule.title, rule.enabled],
  ];
}

Future<RulesScreenPage> _pumpListedRules(WidgetTester tester, Random random) {
  return pumpRulesScreen(
    tester,
    random,
    dependencies: buildRulesScreenDependencies(
      rules: randomNonEmptyListedRules(random, hasProjects: true),
      hasProjects: true,
    ),
  );
}

void main() {
  testWidgets('test_rules_screen_build_new_rule_button_property_opens_a_'
      'new_rule_without_a_preset', (WidgetTester tester) async {
    final Random random = seededRandom(107801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RulesScreenPage page = await pumpRulesScreen(
        tester,
        random,
        dependencies: buildRandomRulesScreenDependencies(
          random,
          hasProjects: random.nextBool(),
        ),
      );

      await tapVisible(tester, find.widgetWithText(AppButton, _newRuleLabel));
      await tester.pump();

      expect(page.navigation.routes, const <AppRoute>[
        rulesRoute,
        NewRuleRoute(presetProjectId: null),
      ]);
    }
  });

  testWidgets('test_rules_screen_build_new_rule_button_property_shown_once_'
      'with_or_without_rules', (WidgetTester tester) async {
    final Random random = seededRandom(107802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRulesScreen(
        tester,
        random,
        dependencies: buildRandomRulesScreenDependencies(
          random,
          hasProjects: random.nextBool(),
        ),
      );

      final Finder button = find.widgetWithText(AppButton, _newRuleLabel);
      expect(button, findsOneWidget);
      expect(tester.widget<AppButton>(button).onPressed, isNotNull);
    }
  });

  testWidgets('test_rules_screen_build_new_rule_button_property_opening_'
      'changes_no_rule', (WidgetTester tester) async {
    final Random random = seededRandom(107803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RulesScreenPage page = await pumpRulesScreen(
        tester,
        random,
        dependencies: buildRandomRulesScreenDependencies(
          random,
          hasProjects: random.nextBool(),
        ),
      );
      final List<List<Object?>> storedBefore = _describeStoredRules(page);

      await tapVisible(tester, find.widgetWithText(AppButton, _newRuleLabel));
      await tester.pump();

      expect(_describeStoredRules(page), storedBefore);
    }
  });

  testWidgets('test_rules_screen_build_row_property_shows_title_details_'
      'and_scope', (WidgetTester tester) async {
    final Random random = seededRandom(107804);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RulesScreenPage page = await _pumpListedRules(tester, random);

      final List<Rule> rules = page.dependencies.ruleRepository.listRules();
      for (final Rule rule in rules) {
        expect(find.text(rule.title), findsOneWidget);
        expect(find.text(rule.details), findsWidgets);
      }
      expect(_readRowChips(tester), <List<String>>[
        for (final Rule rule in rules) _modelScopeChips(rule.scope),
      ]);
    }
  });

  testWidgets('test_rules_screen_build_row_property_a_tap_opens_that_'
      'rule', (WidgetTester tester) async {
    final Random random = seededRandom(107805);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RulesScreenPage page = await _pumpListedRules(tester, random);
      final Rule tapped = pickOne(
        random,
        page.dependencies.ruleRepository.listRules(),
      );

      await tapVisible(tester, find.text(tapped.title));
      await tester.pump();

      expect(page.navigation.routes, <AppRoute>[
        rulesRoute,
        RuleDetailRoute(tapped.id),
      ]);
    }
  });

  testWidgets('test_rules_screen_build_row_property_the_switch_mirrors_'
      'its_rule', (WidgetTester tester) async {
    final Random random = seededRandom(107806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RulesScreenPage page = await _pumpListedRules(tester, random);

      final List<Rule> rules = page.dependencies.ruleRepository.listRules();
      final List<SwitchToggle> switches = _readSwitches(tester);
      expect(switches, hasLength(rules.length));
      for (int index = 0; index < rules.length; index += 1) {
        final Rule rule = rules[index];
        expect(switches[index].semanticLabel, 'Use "${rule.title}"');
        expect(switches[index].value, rule.enabled);
      }
    }
  });

  testWidgets('test_switch_rule_property_flips_only_that_rule', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(107807);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RulesScreenPage page = await _pumpListedRules(tester, random);
      final List<Rule> before = page.dependencies.ruleRepository.listRules();
      final Rule switched = pickOne(random, before);

      await tapVisible(tester, _findSwitchFor(switched));
      await pumpFrames(tester);

      final List<Rule> after = page.dependencies.ruleRepository.listRules();
      expect(after, hasLength(before.length));
      for (int index = 0; index < before.length; index += 1) {
        final bool isSwitched = before[index].id == switched.id;
        final bool expected = isSwitched
            ? !before[index].enabled
            : before[index].enabled;
        expect(after[index].enabled, expected);
      }
    }
  });
}
