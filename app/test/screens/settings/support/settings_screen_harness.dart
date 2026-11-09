import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/tab_strip.dart';

import '../../../support/app_harness.dart';
import '../../../support/random_inputs.dart';
import '../../../support/widget_harness.dart';

const String deleteWorkspaceLabel = 'Delete workspace';
const String keepWorkspaceLabel = 'Keep workspace';
const String settingsTitle = 'Settings';
const SectionRoute settingsRoute = SectionRoute(AppSection.settings);
const SectionRoute projectsRoute = SectionRoute(AppSection.projects);
const double _shortestWindowHeight = 600;
const double _tallestWindowHeight = 1100;
const int _mostCreatedWorkspaces = 4;

Size randomWindowSize(Random random) {
  return Size(
    randomWidth(random, least: narrowestWidth, most: widestWidth),
    randomWidth(
      random,
      least: _shortestWindowHeight,
      most: _tallestWindowHeight,
    ),
  );
}

Finder findInSettingsScreen(Finder matching) {
  return find.descendant(
    of: find.byType(WorkspaceSettingsScreen),
    matching: matching,
  );
}

Finder findSettingsDeleteButton() {
  return findInSettingsScreen(
    find.widgetWithText(AppButton, deleteWorkspaceLabel),
  );
}

String describeWorkspaceSummary(String workspaceName) {
  return 'For the $workspaceName workspace.';
}

Future<List<Workspace>> createRandomWorkspaces(
  Random random,
  AppDependencies dependencies,
) async {
  final int createdCount = random.nextInt(_mostCreatedWorkspaces);
  for (int i = 0; i < createdCount; i += 1) {
    await dependencies.workspaceRepository.createWorkspace(
      name: 'team-${random.nextInt(1000)}-$i',
    );
  }
  return dependencies.workspaceRepository.listWorkspaces();
}

Future<AppNavigation> pumpSettingsScreen(
  WidgetTester tester, {
  required Size size,
  required AppDependencies dependencies,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  return pumpApp(
    tester,
    size: size,
    route: settingsRoute,
    dependencies: dependencies,
  );
}

Future<void> selectSettingsTab(WidgetTester tester, SettingsTab tab) async {
  final Finder label = find.descendant(
    of: find.byType(TabStrip),
    matching: find.text(tab.label),
  );
  await tester.ensureVisible(label);
  await tester.pump();
  await tester.tap(label);
  await pumpFrames(tester);
}

Future<void> tapLastButton(WidgetTester tester, String label) async {
  final Finder button = find.widgetWithText(AppButton, label).last;
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await pumpFrames(tester);
}

Type sectionTypeOfTab(SettingsTab tab) {
  switch (tab) {
    case SettingsTab.server:
      return AppServerSection;
    case SettingsTab.commandsAndPushes:
      return WorkspaceApprovalPolicySection;
    case SettingsTab.protectedFiles:
      return ProtectedFilesSection;
    case SettingsTab.auditLog:
      return AuditLogTab;
  }
}
