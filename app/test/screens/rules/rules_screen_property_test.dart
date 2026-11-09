import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/rules/rules_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';

import '../../support/random_inputs.dart';
import 'rules_screen_page.dart';

const String _emptyTitle = 'No rules yet';

List<bool> _readSwitchValues(WidgetTester tester) {
  return <bool>[
    for (final SwitchToggle toggle in tester.widgetList<SwitchToggle>(
      find.byType(SwitchToggle),
    ))
      toggle.value,
  ];
}

List<bool> _readEnabledStates(AppDependencies dependencies) {
  return <bool>[
    for (final Rule rule in dependencies.ruleRepository.listRules())
      rule.enabled,
  ];
}

void main() {
  test('test_rules_screen_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(107701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildRandomRulesScreenDependencies(
        random,
        hasProjects: random.nextBool(),
      );
      final AppNavigation navigation = AppNavigation(initialRoute: rulesRoute);

      final RulesScreen screen = RulesScreen(
        ruleRepository: dependencies.ruleRepository,
        workspaceRepository: dependencies.workspaceRepository,
        projectRepository: dependencies.projectRepository,
        navigation: navigation,
      );

      expect(screen.ruleRepository, same(dependencies.ruleRepository));
      expect(
        screen.workspaceRepository,
        same(dependencies.workspaceRepository),
      );
      expect(screen.projectRepository, same(dependencies.projectRepository));
      expect(screen.navigation, same(navigation));
    }
  });

  testWidgets('test_rules_screen_constructor_property_shows_the_given_'
      'rules_in_order', (WidgetTester tester) async {
    final Random random = seededRandom(107702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool hasProjects = random.nextBool();
      final List<Rule> rules = randomListedRules(
        random,
        knownProjectIds: listKnownProjectIds(hasProjects: hasProjects),
      );
      final RulesScreenPage page = await pumpRulesScreen(
        tester,
        random,
        dependencies: buildRulesScreenDependencies(
          rules: rules,
          hasProjects: hasProjects,
        ),
      );

      final List<String> labels = <String>[
        for (final SwitchToggle toggle in tester.widgetList<SwitchToggle>(
          find.byType(SwitchToggle),
        ))
          toggle.semanticLabel,
      ];
      expect(labels, <String>[
        for (final Rule rule in page.dependencies.ruleRepository.listRules())
          'Use "${rule.title}"',
      ]);
      expect(labels, hasLength(rules.length));
    }
  });

  testWidgets('test_rules_screen_constructor_property_routes_go_to_the_'
      'given_navigation', (WidgetTester tester) async {
    final Random random = seededRandom(107703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RulesScreenPage page = await pumpRulesScreen(
        tester,
        random,
        dependencies: buildRandomRulesScreenDependencies(
          random,
          hasProjects: true,
        ),
      );

      await tester.tap(find.text('New rule'));
      await tester.pump();

      expect(page.navigation.routes, hasLength(2));
      expect(page.navigation.routes.first, rulesRoute);
    }
  });

  testWidgets('test_rules_screen_build_property_follows_switches_made_'
      'elsewhere', (WidgetTester tester) async {
    final Random random = seededRandom(107704);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool hasProjects = random.nextBool();
      final RulesScreenPage page = await pumpRulesScreen(
        tester,
        random,
        dependencies: buildRulesScreenDependencies(
          rules: randomNonEmptyListedRules(random, hasProjects: hasProjects),
          hasProjects: hasProjects,
        ),
      );
      final Rule switched = pickOne(
        random,
        page.dependencies.ruleRepository.listRules(),
      );

      if (switched.enabled) {
        await page.dependencies.ruleRepository.turnRuleOff(switched.id);
      } else {
        await page.dependencies.ruleRepository.turnRuleOn(switched.id);
      }
      await tester.pump();

      expect(_readSwitchValues(tester), _readEnabledStates(page.dependencies));
    }
  });

  testWidgets('test_rules_screen_build_property_rows_follow_added_and_'
      'deleted_rules', (WidgetTester tester) async {
    final Random random = seededRandom(107705);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RulesScreenPage page = await pumpRulesScreen(
        tester,
        random,
        dependencies: buildRandomRulesScreenDependencies(
          random,
          hasProjects: random.nextBool(),
        ),
      );
      final FakeRuleRepository rules =
          page.dependencies.ruleRepository as FakeRuleRepository;
      final List<Rule> listed = rules.listRules();

      if (listed.isNotEmpty && random.nextBool()) {
        await rules.deleteRule(pickOne(random, listed).id);
      } else {
        await rules.createRule(
          RuleDraft(
            title: 'Added ${randomText(random)}',
            details: randomText(random),
            scope: const Scope.everywhere(),
          ),
        );
      }
      await tester.pump();

      final int shownCount = find.byType(SwitchToggle).evaluate().length;
      final Matcher emptyShown = rules.listRules().isEmpty
          ? findsOneWidget
          : findsNothing;
      expect(shownCount, rules.listRules().length);
      expect(find.text(_emptyTitle), emptyShown);
    }
  });

  testWidgets('test_rules_screen_build_property_renders_hostile_rules_at_'
      'any_size', (WidgetTester tester) async {
    final Random random = seededRandom(107706);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRulesScreen(
        tester,
        random,
        dependencies: buildRandomRulesScreenDependencies(
          random,
          hasProjects: random.nextBool(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Rules'), findsWidgets);
    }
  });
}
