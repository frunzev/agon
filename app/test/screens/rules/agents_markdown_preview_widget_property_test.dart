import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/rules/agents_markdown_preview.dart';
import 'package:agent_orchestration/widgets/code_block.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import 'agents_markdown_preview_model.dart';

const String _keptNote =
    "A project's own AGENTS.md is kept. These rules are added on top.";
const String _emptyAppText = 'No rules apply to app yet.';
const String _generatedLabel = 'Generated AGENTS.md';

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  testWidgets('test_agents_markdown_preview_build_property_matches_an_'
      'independent_model', (WidgetTester tester) async {
    final Random random = seededRandom(107105);
    final Project project = buildShownProject('app');

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Rule> rules = randomNearbyRules(random, table);
      await pumpPreviewAtRandomWidth(
        tester,
        random,
        rules: rules,
        project: project,
        workspaceId: shownWorkspaceId,
      );

      final List<String> expected = modelAgentsMarkdownLines(
        rules: rules,
        table: table,
        workspaceId: shownWorkspaceId,
      );
      final Matcher emptyShown = expected.isEmpty
          ? findsOneWidget
          : findsNothing;
      final Matcher codeShown = expected.isEmpty
          ? findsNothing
          : findsOneWidget;
      expect(readShownCodeLines(tester), expected);
      expect(find.text(_emptyAppText), emptyShown);
      expect(find.bySemanticsLabel(_generatedLabel), codeShown);
    }
  });

  testWidgets('test_agents_markdown_preview_build_property_names_the_'
      'project_at_any_width', (WidgetTester tester) async {
    final Random random = seededRandom(107106);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String name = randomHostileText(random);
      await pumpPreviewAtRandomWidth(
        tester,
        random,
        rules: randomNearbyRules(random, table),
        project: buildShownProject(name),
        workspaceId: shownWorkspaceId,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('AGENTS.md for $name'), findsOneWidget);
      expect(find.text(_keptNote), findsOneWidget);
      final Finder codeTexts = find.descendant(
        of: find.byType(CodeBlock),
        matching: find.byType(Text),
      );
      expect(codeTexts, findsNWidgets(readShownCodeLines(tester).length));
    }
  });

  test('test_agents_markdown_preview_constructor_property_keeps_'
      'every_field', () {
    final Random random = seededRandom(107107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> rules = randomNearbyRules(random, table);
      final Project project = buildShownProject(randomText(random));
      final WorkspaceId workspaceId = pickOne(random, nearbyWorkspaceIds);
      final Key key = ValueKey<int>(i);

      final AgentsMarkdownPreview preview = AgentsMarkdownPreview(
        rules: rules,
        workspaceId: workspaceId,
        project: project,
        key: key,
      );

      expect(preview.rules, same(rules));
      expect(preview.workspaceId, workspaceId);
      expect(preview.project, same(project));
      expect(preview.key, key);
    }
  });

  testWidgets('test_agents_markdown_preview_constructor_property_same_'
      'inputs_show_the_same_lines', (WidgetTester tester) async {
    final Random random = seededRandom(107108);
    final Project project = buildShownProject('app');

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Rule> rules = randomNearbyRules(random, table);
      await pumpPreviewAtRandomWidth(
        tester,
        random,
        rules: rules,
        project: project,
        workspaceId: shownWorkspaceId,
      );
      final List<String> firstLines = readShownCodeLines(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpPreviewAtRandomWidth(
        tester,
        random,
        rules: rules,
        project: project,
        workspaceId: shownWorkspaceId,
      );

      expect(readShownCodeLines(tester), firstLines);
    }
  });

  testWidgets('test_agents_markdown_preview_constructor_property_honours_'
      'the_given_workspace', (WidgetTester tester) async {
    final Random random = seededRandom(107109);
    final Project project = buildShownProject('app');

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Rule> rules = randomNearbyRules(random, table);
      final WorkspaceId workspaceId = pickOne(random, nearbyWorkspaceIds);
      await pumpPreviewAtRandomWidth(
        tester,
        random,
        rules: rules,
        project: project,
        workspaceId: workspaceId,
      );

      final List<String> expected = modelAgentsMarkdownLines(
        rules: rules,
        table: table,
        workspaceId: workspaceId,
      );
      expect(readShownCodeLines(tester), expected);
    }
  });
}
