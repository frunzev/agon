import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';

import '../../support/app_harness.dart';
import '../../support/list_harness.dart';
import '../../support/random_unknown_scope_places.dart';
import '../../support/sample_scopes.dart';
import '../support/random_page_windows.dart';
import 'skill_form_screen_page.dart';

typedef SkillsPage = ({
  AppDependencies dependencies,
  AppNavigation navigation,
  Size windowSize,
});

Future<SkillsPage> openSkillsPage(
  WidgetTester tester,
  Random random, {
  required List<Skill> skills,
}) async {
  final AppDependencies dependencies = buildDependenciesWithSkills(skills);
  final Size windowSize = randomPageWindowSize(random);
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: windowSize,
    route: skillsSectionRoute,
    dependencies: dependencies,
  );
  return (
    dependencies: dependencies,
    navigation: navigation,
    windowSize: windowSize,
  );
}

List<String> readShownSkillNames(WidgetTester tester) {
  return <String>[
    for (final ListRowMain row in tester.widgetList<ListRowMain>(
      find.byType(ListRowMain),
    ))
      row.title,
  ];
}

List<String> _nameKnownWorkspaces(WorkspaceScope workspaces) {
  if (workspaces is! OnlyWorkspaces) {
    return const <String>[];
  }
  return <String>[
    for (final WorkspaceId workspaceId in workspaces.workspaces)
      for (final Workspace workspace in galleryCatalog.workspaces)
        if (workspace.id == workspaceId) workspace.name,
  ];
}

List<String> _nameKnownProjects(ProjectScope projects) {
  if (projects is! OnlyProjects) {
    return const <String>[];
  }
  return <String>[
    for (final ProjectId projectId in projects.projects)
      for (final Project project in galleryCatalog.projects)
        if (project.id == projectId) project.name,
  ];
}

String modelSkillReach(Skill skill) {
  if (skill.source == SkillSource.builtIn) {
    return 'Built in';
  }
  final Scope known = pruneUnknownPlacesByHand(skill.scope, galleryCatalog);
  if (listsNoPlace(known)) {
    return 'Nowhere';
  }

  final List<String> workspaceNames = _nameKnownWorkspaces(known.workspaces);
  final List<String> projectNames = _nameKnownProjects(known.projects);
  if (workspaceNames.isEmpty && projectNames.isEmpty) {
    return 'Everywhere';
  }
  final List<String> parts = <String>[
    if (workspaceNames.isNotEmpty) workspaceNames.join(', '),
    if (projectNames.isNotEmpty) projectNames.join(', '),
    if (projectNames.isEmpty) 'all projects',
  ];
  return parts.join(' · ');
}
