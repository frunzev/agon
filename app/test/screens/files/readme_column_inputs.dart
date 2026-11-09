import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/file_tree_controller.dart';
import 'package:agent_orchestration/screens/files/readme_column.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'files_screen_pumps.dart';
import 'files_screen_repositories.dart';
import 'files_screen_scenarios.dart';
import 'project_files_screen_steps.dart';

const String readmeRootFolder = '';
const String _shownRepositoryPath = 'acme/app';

typedef ReadmeSetup = ({
  FilesScreenScenario scenario,
  ScreenFileRepository files,
  FileTreeController tree,
});

ReadmeSetup randomReadmeSetup(Random random) {
  final FilesScreenScenario scenario = randomFilePageScenario(random);
  final ScreenFileRepository files = scenario.buildFileRepository();
  final FilesFromRunner source = scenario.source! as FilesFromRunner;
  final FileTreeController tree = FileTreeController(
    fileRepository: files,
    location: RepositoryBranchLocation(
      projectId: scenario.project.id,
      repositoryAddress: scenario.route.repositoryAddress,
      runnerId: source.runnerId,
      branch: pickOne(random, listBranchesOf(scenario)),
    ),
  );
  addTearDown(tree.dispose);
  return (scenario: scenario, files: files, tree: tree);
}

ReadmeSetup randomReadmeSetupWithReadme(Random random) {
  while (true) {
    final ReadmeSetup setup = randomReadmeSetup(random);
    if (findRootReadmePath(setup.scenario) != null) {
      return setup;
    }
  }
}

Future<void> pumpReadmeColumn(WidgetTester tester, FileTreeController tree) {
  return pumpScrollableAtWidth(
    tester,
    width: desktopWidth,
    child: ReadmeColumn(tree: tree, repositoryPath: _shownRepositoryPath),
  );
}

Future<void> revealRootFolder(
  WidgetTester tester,
  FileTreeController tree,
) async {
  unawaited(tree.revealFolders(const <String>[readmeRootFolder]));
  await settleFilesScreen(tester);
}

List<String> listExpectedReadmeReads(FilesScreenScenario scenario) {
  final String? readmePath = findRootReadmePath(scenario);
  return <String>[?readmePath];
}
