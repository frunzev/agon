import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_scopes.dart';

import 'project_rules_section_inputs.dart';

void main() {
  testWidgets('test_project_rules_section_build_property_one_row_per_'
      'applying_rule', (WidgetTester tester) async {
    final Random random = seededRandom(1050904);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final (_, Project project, List<Rule> rules) =
          await pumpRandomRulesSection(tester, random);
      final List<Rule> applying = listApplyingRules(rules, project);

      expect(tester.takeException(), isNull);
      for (final Rule rule in rules) {
        expect(
          find.text(rule.title),
          applying.contains(rule) ? findsOneWidget : findsNothing,
        );
      }
      expect(
        find.text('No rules apply to this project yet.'),
        applying.isEmpty ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_project_rules_section_build_property_add_rule_presets_'
      'the_project', (WidgetTester tester) async {
    final Random random = seededRandom(1050905);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final (AppNavigation navigation, Project project, _) =
          await pumpRandomRulesSection(tester, random);

      await tester.tap(find.text('Add rule'));
      await tester.pump();

      expect(
        navigation.currentRoute,
        NewRuleRoute(presetProjectId: project.id),
      );
    }
  });

  testWidgets('test_project_rules_section_build_row_property_reach_and_'
      'state_shown', (WidgetTester tester) async {
    final Random random = seededRandom(1050906);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final (_, Project project, List<Rule> rules) =
          await pumpRandomRulesSection(tester, random);
      final List<Rule> applying = listApplyingRules(rules, project);
      final int enabledCount = applying
          .where((Rule rule) => rule.enabled)
          .length;

      for (final Rule rule in applying) {
        final String reach = describeRuleReach(
          scope: rule.scope,
          project: project,
          catalog: galleryCatalog,
        );
        expect(reach, isNot('Nowhere'));
        expect(find.textContaining(reach), findsWidgets);
      }
      expect(find.text('On'), findsNWidgets(enabledCount));
      expect(find.text('Off'), findsNWidgets(applying.length - enabledCount));
    }
  });

  testWidgets('test_project_rules_section_build_row_property_tap_opens_'
      'rules', (WidgetTester tester) async {
    final Random random = seededRandom(1050907);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final (AppNavigation navigation, Project project, List<Rule> rules) =
          await pumpRandomRulesSection(tester, random);
      final List<Rule> applying = listApplyingRules(rules, project);
      if (applying.isEmpty) {
        continue;
      }

      await tester.tap(find.text(pickOne(random, applying).title));
      await tester.pump();

      expect(navigation.currentRoute, const SectionRoute(AppSection.rules));
      expect(navigation.routes, hasLength(1));
    }
  });

  testWidgets('test_project_rules_section_build_row_property_keyed_by_'
      'rule', (WidgetTester tester) async {
    final Random random = seededRandom(1050908);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final (_, Project project, List<Rule> rules) =
          await pumpRandomRulesSection(tester, random);

      final List<Rule> applying = listApplyingRules(rules, project);
      final Finder lists = find.byType(ResponsiveList);
      final List<LocalKey?> keys = <LocalKey?>[
        if (applying.isNotEmpty)
          for (final ListRowData row
              in tester.widget<ResponsiveList>(lists).rows)
            row.key,
      ];

      expect(keys, <LocalKey>[
        for (final Rule rule in applying) ValueKey<String>(rule.id.value),
      ]);
    }
  });

  testWidgets('test_project_rules_section_build_property_title_and_action_'
      'always_shown', (WidgetTester tester) async {
    final Random random = seededRandom(1050912);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRandomRulesSection(tester, random);

      expect(tester.takeException(), isNull);
      expect(find.text('Rules'), findsOneWidget);
      expect(find.text('Add rule'), findsOneWidget);
    }
  });
}
