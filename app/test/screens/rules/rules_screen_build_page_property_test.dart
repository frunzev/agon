import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/rules/agents_markdown_preview.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';

import '../../support/random_inputs.dart';
import 'rules_screen_page.dart';

const String _emptyTitle = 'No rules yet';
const String _emptyMessage =
    'Write what every agent must follow, like never pushing to '
    "main, and each run's AGENTS.md gets it.";
const String _listSummary =
    "Each run's AGENTS.md gets the rules for its project.";

void main() {
  testWidgets('test_rules_screen_build_page_property_no_rules_shows_the_'
      'empty_state', (WidgetTester tester) async {
    final Random random = seededRandom(107707);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRulesScreen(
        tester,
        random,
        dependencies: buildRulesScreenDependencies(
          rules: const <Rule>[],
          hasProjects: random.nextBool(),
        ),
      );

      expect(find.text(_emptyTitle), findsOneWidget);
      expect(find.text(_emptyMessage), findsOneWidget);
      expect(find.text('New rule'), findsOneWidget);
      expect(find.text(_listSummary), findsNothing);
      expect(find.byType(AgentsMarkdownPreview), findsNothing);
      expect(find.byType(SwitchToggle), findsNothing);
    }
  });

  testWidgets('test_rules_screen_build_page_property_previews_the_first_'
      'project', (WidgetTester tester) async {
    final Random random = seededRandom(107708);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RulesScreenPage page = await pumpRulesScreen(
        tester,
        random,
        dependencies: buildRulesScreenDependencies(
          rules: randomNonEmptyListedRules(random, hasProjects: true),
          hasProjects: true,
        ),
      );

      final AppDependencies dependencies = page.dependencies;
      final WorkspaceId workspaceId = dependencies.workspaceRepository
          .currentWorkspace()
          .id;
      final List<Project> projects = dependencies.projectRepository
          .listProjects(workspaceId);
      final AgentsMarkdownPreview preview = tester
          .widget<AgentsMarkdownPreview>(find.byType(AgentsMarkdownPreview));
      expect(find.text(_listSummary), findsOneWidget);
      final String previewTitle = 'AGENTS.md for ${projects.first.name}';
      expect(find.text(previewTitle), findsOneWidget);
      expect(preview.project.id, projects.first.id);
      expect(preview.workspaceId, workspaceId);
      expect(preview.rules, dependencies.ruleRepository.listRules());
    }
  });

  testWidgets('test_rules_screen_build_page_property_without_projects_'
      'only_the_list_shows', (WidgetTester tester) async {
    final Random random = seededRandom(107709);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Rule> rules = randomNonEmptyListedRules(
        random,
        hasProjects: false,
      );
      await pumpRulesScreen(
        tester,
        random,
        dependencies: buildRulesScreenDependencies(
          rules: rules,
          hasProjects: false,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AgentsMarkdownPreview), findsNothing);
      expect(find.text(_listSummary), findsOneWidget);
      expect(find.byType(SwitchToggle), findsNWidgets(rules.length));
    }
  });
}
