import 'dart:math';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/random_repository_addresses.dart';
import 'file_property_inputs.dart';
import 'files_screen_repositories.dart';

const ProjectId scenarioProjectId = ProjectId('files-project');
const WorkspaceId _scenarioWorkspaceId = WorkspaceId('workspace');
const String missingBranch = 'gone/branch';
const List<String> plainBranches = <String>['main', 'release', 'task/a1'];
const List<String?> _readmePaths = <String?>[
  null,
  'README.md',
  'readme.md',
  'ReadMe.MD',
  'README.md/inside.txt',
  'docs/README.md',
  'README',
];
const String _hugeReadmeLine = '- step with `code`, **bold** and a link';
const int _hugeReadmeLineCount = 300;
const int _largestFileCount = 6;
const int _largestRepositoryCount = 3;
const int _largestHolderCount = 4;
const int _largestMinutesAgo = 100000;
final DateTime scenarioNow = DateTime.utc(2026, 11, 8, 12);

enum FilesSourceKind { runner, offlineHolders, unknown }

final class FilesScreenScenario {
  const FilesScreenScenario({
    required this.project,
    required this.route,
    required this.source,
    required this.files,
  });

  final Project project;
  final ProjectFilesRoute route;
  final RepositoryFileSource? source;
  final List<FakeRepositoryFile> files;

  Repository get chosenRepository {
    return project.repositories.firstWhere(
      (Repository repository) => repository.address == route.repositoryAddress,
    );
  }

  ScreenFileRepository buildFileRepository() {
    return ScreenFileRepository(
      FakeFileRepository(
        sources: <String, RepositoryFileSource>{
          route.repositoryAddress: ?source,
        },
        files: files,
      ),
    );
  }
}

FilesScreenScenario randomFilesScreenScenario(Random random) {
  return randomScenarioWithSource(
    random,
    pickOne(random, FilesSourceKind.values),
  );
}

FilesScreenScenario randomScenarioWithSource(
  Random random,
  FilesSourceKind kind,
) {
  final List<Repository> repositories = _randomRepositories(random);
  final Repository chosen = pickOne(random, repositories);
  final RepositoryFileSource? source = switch (kind) {
    FilesSourceKind.runner => _randomRunnerSource(random, chosen),
    FilesSourceKind.offlineHolders => FilesWithoutRunner(
      holders: _randomHolders(random),
    ),
    FilesSourceKind.unknown => null,
  };
  return FilesScreenScenario(
    project: Project(
      id: scenarioProjectId,
      workspaceId: _scenarioWorkspaceId,
      name: 'p${randomHostileText(random)}',
      repositories: repositories,
      approvalPolicy: null,
    ),
    route: ProjectFilesRoute(
      projectId: scenarioProjectId,
      repositoryAddress: chosen.address,
      branch: _randomRequestedBranch(random, source),
      preferredRunnerId: random.nextBool() ? null : const DeviceId('wanted'),
    ),
    source: source,
    files: randomRepositoryFiles(random, chosen.address),
  );
}

List<Repository> _randomRepositories(Random random) {
  final int count = 1 + random.nextInt(_largestRepositoryCount);
  return <Repository>[
    for (int index = 0; index < count; index += 1)
      Repository(
        address: _buildRealisticAddress(random, index),
        defaultBranch: random.nextBool() ? 'main' : 'trunk$index',
        agentAccess: pickOne(random, AgentAccess.values),
      ),
  ];
}

String _buildRealisticAddress(Random random, int index) {
  final String name = randomPathPartWithoutGitSuffix(random);
  return 'github.com/acme/$name-$index';
}

FilesFromRunner _randomRunnerSource(Random random, Repository chosen) {
  final List<String> branches = randomDistinctBranches(random, '');
  final bool listsDefault = random.nextBool();
  if (listsDefault && !branches.contains(chosen.defaultBranch)) {
    branches.insert(random.nextInt(branches.length + 1), chosen.defaultBranch);
  }
  return FilesFromRunner(
    runnerId: DeviceId('runner-${random.nextInt(1000)}'),
    runnerName: 'r${randomHostileText(random)}',
    branches: branches,
    taskBranches: randomDistinctBranches(random, 'task/'),
  );
}

String? _randomRequestedBranch(Random random, RepositoryFileSource? source) {
  if (source is! FilesFromRunner || random.nextBool()) {
    return random.nextBool() ? null : missingBranch;
  }
  final List<String> listed = <String>[
    ...source.branches,
    ...source.taskBranches,
  ];
  return listed.isEmpty ? missingBranch : pickOne(random, listed);
}

List<RepositoryHolder> _randomHolders(Random random) {
  final int count = random.nextInt(_largestHolderCount);
  return <RepositoryHolder>[
    for (int index = 0; index < count; index += 1)
      RepositoryHolder(
        deviceId: DeviceId('holder-$index'),
        name: 'h${randomHostileText(random)}',
        lastSeen: scenarioNow.subtract(
          Duration(minutes: random.nextInt(_largestMinutesAgo)),
        ),
      ),
  ];
}

List<FakeRepositoryFile> randomRepositoryFiles(Random random, String address) {
  final List<String> paths = <String>[
    for (int index = 0; index < random.nextInt(_largestFileCount); index += 1)
      randomFilePath(random),
  ];
  final String? readmePath = pickOne(random, _readmePaths);
  if (readmePath != null) {
    paths.add(readmePath);
  }
  final List<FakeRepositoryFile> files = <FakeRepositoryFile>[];
  for (final String path in _keepTreeShapedPaths(paths)) {
    files.add(
      FakeRepositoryFile(
        repositoryAddress: address,
        path: path,
        size: randomFileSize(random),
        preview: path == readmePath && random.nextBool()
            ? _hugeReadmePreview()
            : randomFilePreview(random),
      ),
    );
  }
  return files;
}

TextFilePreview _hugeReadmePreview() {
  final List<String> lines = List<String>.filled(
    _hugeReadmeLineCount,
    _hugeReadmeLine,
  );
  return TextFilePreview(lines.join('\n'));
}

List<String> _keepTreeShapedPaths(List<String> paths) {
  final List<String> kept = <String>[];
  for (final String path in paths) {
    final bool clashes = kept.any(
      (String other) =>
          other == path ||
          other.startsWith('$path/') ||
          path.startsWith('$other/'),
    );
    if (!clashes) {
      kept.add(path);
    }
  }
  return kept;
}

FilesScreenScenario randomFilePageScenario(Random random) {
  while (true) {
    final FilesScreenScenario scenario = randomScenarioWithSource(
      random,
      FilesSourceKind.runner,
    );
    if (listBranchesOf(scenario).isNotEmpty) {
      return scenario;
    }
  }
}

List<String> listBranchesOf(FilesScreenScenario scenario) {
  final FilesFromRunner source = scenario.source as FilesFromRunner;
  return <String>[...source.branches, ...source.taskBranches];
}

RepositoryFileRoute randomFileRoute(
  Random random,
  FilesScreenScenario scenario,
) {
  final List<String> paths = <String>[
    for (final FakeRepositoryFile file in scenario.files) file.path,
    randomFilePath(random),
  ];
  return RepositoryFileRoute(
    filesRoute: scenario.route,
    source: scenario.source as FilesFromRunner,
    branch: pickOne(random, listBranchesOf(scenario)),
    path: pickOne(random, paths),
  );
}

FilesScreenScenario replaceScenarioRoute(
  FilesScreenScenario scenario,
  ProjectFilesRoute route,
) {
  return FilesScreenScenario(
    project: scenario.project,
    route: route,
    source: scenario.source,
    files: scenario.files,
  );
}

FilesScreenScenario replaceScenarioSource(
  FilesScreenScenario scenario,
  RepositoryFileSource? source,
) {
  return FilesScreenScenario(
    project: scenario.project,
    route: scenario.route,
    source: source,
    files: scenario.files,
  );
}

FilesScreenScenario randomOfflineScenario(Random random) {
  return randomScenarioWithSource(
    random,
    pickOne(random, <FilesSourceKind>[
      FilesSourceKind.offlineHolders,
      FilesSourceKind.unknown,
    ]),
  );
}

FilesScreenScenario replaceWithPlainBranches(FilesScreenScenario scenario) {
  final FilesFromRunner source = scenario.source as FilesFromRunner;
  return replaceScenarioSource(
    scenario,
    FilesFromRunner(
      runnerId: source.runnerId,
      runnerName: source.runnerName,
      branches: plainBranches.sublist(0, 2),
      taskBranches: plainBranches.sublist(2),
    ),
  );
}
