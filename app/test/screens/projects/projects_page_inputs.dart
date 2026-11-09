import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/app_harness.dart';
import '../../support/list_harness.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'project_screen_inputs.dart';

const SectionRoute projectsSectionRoute = SectionRoute(AppSection.projects);
const int _largestProjectCount = 9;

typedef ProjectsPage = ({
  AppDependencies dependencies,
  AppNavigation navigation,
  Size window,
});

List<Project> randomWorkspaceProjects(Random random) {
  final int count = random.nextInt(_largestProjectCount);
  return <Project>[
    for (int index = 0; index < count; index += 1)
      Project(
        id: ProjectId('p-${random.nextInt(1 << 20)}-$index'),
        workspaceId: pickOne(random, galleryWorkspaces).id,
        name: 'p${randomHostileText(random)}',
        repositories: randomScreenRepositories(random),
        approvalPolicy: null,
      ),
  ];
}

Future<ProjectsPage> openProjectsPage(
  WidgetTester tester,
  Random random,
) async {
  final AppDependencies dependencies = buildDependenciesWithProjects(
    randomWorkspaceProjects(random),
  );
  final Size window = randomPageWindowSize(random);
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: window,
    route: projectsSectionRoute,
    dependencies: dependencies,
  );
  return (dependencies: dependencies, navigation: navigation, window: window);
}

List<Project> listCurrentProjects(ProjectsPage page) {
  final Workspace workspace = page.dependencies.workspaceRepository
      .currentWorkspace();
  return page.dependencies.projectRepository.listProjects(workspace.id);
}

Finder findProjectRowMains() {
  return find.descendant(
    of: find.byType(ProjectsScreen),
    matching: find.byType(ListRowMain),
  );
}

List<String> readProjectRowTitles(WidgetTester tester) {
  return <String>[
    for (final ListRowMain row in tester.widgetList<ListRowMain>(
      findProjectRowMains(),
    ))
      row.title,
  ];
}

List<String> listProjectNames(List<Project> projects) {
  return <String>[for (final Project project in projects) project.name];
}
