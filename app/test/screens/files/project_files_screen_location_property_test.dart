import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/file_pickers.dart';
import 'package:agent_orchestration/screens/files/file_tree_view.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'files_screen_scenarios.dart';
import 'project_files_screen_steps.dart';

FilesScreenScenario _withBranches(
  FilesScreenScenario base, {
  required List<String> branches,
  required String? requestedBranch,
}) {
  final FilesFromRunner source = base.source! as FilesFromRunner;
  return FilesScreenScenario(
    project: base.project,
    route: ProjectFilesRoute(
      projectId: base.route.projectId,
      repositoryAddress: base.route.repositoryAddress,
      branch: requestedBranch,
    ),
    source: FilesFromRunner(
      runnerId: source.runnerId,
      runnerName: source.runnerName,
      branches: branches,
      taskBranches: source.taskBranches,
    ),
    files: base.files,
  );
}

FilesScreenScenario _withDistinctDefaults(FilesScreenScenario base) {
  final List<Repository> repositories = <Repository>[
    for (int index = 0; index < base.project.repositories.length; index += 1)
      Repository(
        address: base.project.repositories[index].address,
        defaultBranch: 'default-$index',
        agentAccess: base.project.repositories[index].agentAccess,
      ),
  ];
  final FilesScreenScenario scenario = FilesScreenScenario(
    project: base.project.withRepositories(repositories),
    route: base.route,
    source: base.source,
    files: base.files,
  );
  final FilesFromRunner source = base.source! as FilesFromRunner;
  return _withBranches(
    scenario,
    branches: <String>[
      ...source.branches,
      for (final Repository repository in repositories)
        repository.defaultBranch,
    ],
    requestedBranch: null,
  );
}

LocationFields _expectedLocation(FilesScreenScenario scenario) {
  final FilesFromRunner source = scenario.source! as FilesFromRunner;
  return (
    scenario.project.id.value,
    scenario.route.repositoryAddress,
    source.runnerId.value,
    predictInitialBranch(scenario)!,
  );
}

String _chosenBranch(WidgetTester tester) {
  final BranchPicker picker = tester.widget(find.byType(BranchPicker));
  return picker.chosenBranch;
}

void main() {
  testWidgets('test_project_files_screen_find_repository_property_default', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(737001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario base = randomFilePageScenario(random);
      final String defaultBranch = base.chosenRepository.defaultBranch;
      final FilesFromRunner source = base.source! as FilesFromRunner;
      final FilesScreenScenario scenario = _withBranches(
        base,
        branches: <String>{...source.branches, defaultBranch}.toList(),
        requestedBranch: random.nextBool() ? null : missingBranch,
      );
      await pumpProjectFilesAt(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );

      expect(_chosenBranch(tester), defaultBranch);
    }
  });

  testWidgets('test_project_files_screen_find_repository_property_first', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(737002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario base = randomFilePageScenario(random);
      final String defaultBranch = base.chosenRepository.defaultBranch;
      final FilesFromRunner source = base.source! as FilesFromRunner;
      final List<String> branches = <String>[
        for (final String branch in source.branches)
          if (branch != defaultBranch) branch,
      ];
      final List<String> listed = <String>[
        ...branches,
        ...source.taskBranches,
      ];
      if (listed.isEmpty) {
        continue;
      }
      await pumpProjectFilesAt(
        tester,
        scenario: _withBranches(
          base,
          branches: branches,
          requestedBranch: missingBranch,
        ),
        size: randomScreenSize(random),
      );

      expect(_chosenBranch(tester), listed.first);
    }
  });

  testWidgets('test_project_files_screen_find_repository_property_own_one', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(737003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = _withDistinctDefaults(
        randomFilePageScenario(random),
      );
      await pumpProjectFilesAt(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );

      expect(_chosenBranch(tester), scenario.chosenRepository.defaultBranch);
    }
  });

  testWidgets('test_project_files_screen_locate_property_tree_location', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(737004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilePageScenario(random);
      await pumpProjectFilesAt(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );

      final FileTreeView tree = tester.widget(find.byType(FileTreeView));
      expect(
        describeLocation(tree.controller.location),
        _expectedLocation(scenario),
      );
    }
  });

  testWidgets('test_project_files_screen_locate_property_every_request', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(737005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilePageScenario(random);
      final ScreenFileRepository files = await pumpProjectFilesAt(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
      );

      expect(files.askedLocations, isNotEmpty);
      for (final RepositoryBranchLocation location in files.askedLocations) {
        expect(describeLocation(location), _expectedLocation(scenario));
      }
    }
  });

  testWidgets('test_project_files_screen_locate_property_opened_file', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(737006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesScreenScenario scenario = randomFilePageScenario(random);
      final AppNavigation navigation = navigationToProjectFiles(scenario);
      await pumpProjectFilesScenario(
        tester,
        scenario: scenario,
        size: randomScreenSize(random),
        navigation: navigation,
        refusals: const <FileOperation, Object>{},
      );
      final FileTreeView tree = tester.widget(find.byType(FileTreeView));
      tree.onOpenFile(randomHostileText(random));

      final RepositoryFileRoute opened =
          navigation.currentRoute as RepositoryFileRoute;
      expect(describeLocation(opened.location), _expectedLocation(scenario));
    }
  });
}
