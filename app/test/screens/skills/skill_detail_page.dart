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
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';

import '../../support/app_harness.dart';
import '../../support/list_harness.dart';
import '../../support/random_unknown_scope_places.dart';
import '../../support/sample_scopes.dart';
import '../support/random_page_windows.dart';
import 'skill_form_screen_page.dart';

const String everywhereChip = 'Everywhere';
const String nowhereChip = 'Nowhere';

typedef SkillDetailPage = ({
  AppDependencies dependencies,
  AppNavigation navigation,
  Skill skill,
});

Future<SkillDetailPage> openSkillDetail(
  WidgetTester tester,
  Random random, {
  required List<Skill> skills,
  required Skill skill,
}) {
  return openSkillDetailOver(
    tester,
    random,
    dependencies: buildDependenciesWithSkills(skills),
    skill: skill,
  );
}

Future<SkillDetailPage> openSkillDetailOver(
  WidgetTester tester,
  Random random, {
  required AppDependencies dependencies,
  required Skill skill,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: randomPageWindowSize(random),
    route: skillsSectionRoute,
    dependencies: dependencies,
  );
  navigation.openRoute(SkillDetailRoute(skill.id));
  await pumpFrames(tester);
  return (dependencies: dependencies, navigation: navigation, skill: skill);
}

List<String> modelScopeChips(Scope scope) {
  final Scope known = pruneUnknownPlacesByHand(scope, galleryCatalog);
  if (listsNoPlace(known)) {
    return const <String>[nowhereChip];
  }

  final List<String> chips = <String>[];
  final WorkspaceScope workspaces = known.workspaces;
  if (workspaces is OnlyWorkspaces) {
    for (final WorkspaceId workspaceId in workspaces.workspaces) {
      for (final Workspace workspace in galleryCatalog.workspaces) {
        if (workspace.id == workspaceId) {
          chips.add(workspace.name);
        }
      }
    }
  }
  final ProjectScope projects = known.projects;
  if (projects is OnlyProjects) {
    for (final ProjectId projectId in projects.projects) {
      for (final Project project in galleryCatalog.projects) {
        if (project.id == projectId) {
          chips.add(project.name);
        }
      }
    }
  }
  if (chips.isEmpty) {
    return const <String>[everywhereChip];
  }
  return chips;
}

Fact readShownFact(WidgetTester tester, String term) {
  final FactList list = tester.widget<FactList>(find.byType(FactList).first);
  return list.facts.singleWhere((Fact fact) => fact.term == term);
}
