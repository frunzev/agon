import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/rules/agents_markdown_preview.dart';
import 'package:agent_orchestration/widgets/code_block.dart';

import '../../support/random_inputs.dart';
import '../../support/random_scope_catalogs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../../support/sample_scopes.dart';
import '../../support/widget_harness.dart';

const String blankCodeLine = ' ';
const WorkspaceId shownWorkspaceId = WorkspaceId('shown-workspace');
const ProjectId shownProjectId = ProjectId('shown-project');
const List<WorkspaceId> nearbyWorkspaceIds = <WorkspaceId>[
  shownWorkspaceId,
  WorkspaceId('other-workspace'),
];
const List<ProjectId> _nearbyProjectIds = <ProjectId>[
  shownProjectId,
  ProjectId('other-project'),
];
const List<String> _sentenceEndings = <String>['.', '!', '?'];
const int _mostRules = 6;

Project buildShownProject(String name) {
  return buildNamedProject(
    projectId: shownProjectId,
    workspaceId: shownWorkspaceId,
    name: name,
  );
}

Scope _randomNearbyScope(Random random) {
  final WorkspaceScope workspaces = random.nextBool()
      ? const AllWorkspaces()
      : OnlyWorkspaces(pickSome(random, nearbyWorkspaceIds));
  final ProjectScope projects = random.nextBool()
      ? const AllProjects()
      : OnlyProjects(pickSome(random, _nearbyProjectIds));
  return Scope(workspaces: workspaces, projects: projects);
}

List<Rule> randomNearbyRules(Random random, RuleTitleWhiteSpaceTable table) {
  final int count = random.nextInt(_mostRules);
  return <Rule>[
    for (int index = 0; index < count; index += 1)
      Rule(
        id: RuleId('rule-$index'),
        title: table.randomExoticTitle(random),
        details: '${table.randomExoticTitle(random)}\n${randomText(random)}',
        scope: _randomNearbyScope(random),
        enabled: random.nextBool(),
        addedAt: galleryNow,
      ),
  ];
}

bool _coversWorkspace(WorkspaceScope workspaces, WorkspaceId workspaceId) {
  return switch (workspaces) {
    AllWorkspaces() => true,
    OnlyWorkspaces(:final List<WorkspaceId> workspaces) => workspaces.contains(
      workspaceId,
    ),
  };
}

bool _coversShownProject(ProjectScope projects) {
  return switch (projects) {
    AllProjects() => true,
    OnlyProjects(:final List<ProjectId> projects) => projects.contains(
      shownProjectId,
    ),
  };
}

bool _isShownByModel(
  Rule rule,
  RuleTitleWhiteSpaceTable table,
  WorkspaceId workspaceId,
) {
  final bool coversWorkspace = _coversWorkspace(
    rule.scope.workspaces,
    workspaceId,
  );
  final bool coversProject = _coversShownProject(rule.scope.projects);
  final bool hasTitle = table.trimByModel(rule.title).isNotEmpty;
  return rule.enabled && coversWorkspace && coversProject && hasTitle;
}

List<String> modelAgentsMarkdownLines({
  required List<Rule> rules,
  required RuleTitleWhiteSpaceTable table,
  required WorkspaceId workspaceId,
}) {
  final List<String> ruleLines = <String>[];
  for (final Rule rule in rules) {
    if (!_isShownByModel(rule, table, workspaceId)) {
      continue;
    }
    final String title = table.collapseByModel(rule.title);
    final bool endsSentence = _sentenceEndings.any(title.endsWith);
    ruleLines.add(endsSentence ? '- $title' : '- $title.');
    for (final String detailLine in rule.details.split('\n')) {
      final String trimmedLine = table.trimByModel(detailLine);
      if (trimmedLine.isNotEmpty) {
        ruleLines.add('  $trimmedLine');
      }
    }
  }
  if (ruleLines.isEmpty) {
    return const <String>[];
  }
  return <String>['# Rules', blankCodeLine, ...ruleLines];
}

List<String> readCodeLineTexts(List<CodeBlockLine> lines) {
  return <String>[for (final CodeBlockLine line in lines) line.text];
}

List<String> readShownCodeLines(WidgetTester tester) {
  final Finder block = find.byType(CodeBlock);
  if (block.evaluate().isEmpty) {
    return const <String>[];
  }
  return readCodeLineTexts(tester.widget<CodeBlock>(block).lines);
}

Future<void> pumpPreviewAtRandomWidth(
  WidgetTester tester,
  Random random, {
  required List<Rule> rules,
  required Project project,
  required WorkspaceId workspaceId,
}) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: AgentsMarkdownPreview(
      rules: rules,
      workspaceId: workspaceId,
      project: project,
    ),
  );
}
