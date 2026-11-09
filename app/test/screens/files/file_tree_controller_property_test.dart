import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/rules/code_point_order.dart';
import 'package:agent_orchestration/screens/files/file_tree_controller.dart';
import 'package:agent_orchestration/screens/files/repository_file_paths.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'file_property_inputs.dart';

const int _treeCount = 25;
const int _stepsPerTree = 30;

typedef _StepCheck = void Function(
  FileTreeController controller,
  _TreeModel model,
  List<String> folders,
);

final class _TreeModel {
  _TreeModel(this.repository);

  final ScriptedFolderRepository repository;
  final Set<String> expanded = <String>{};
  final FolderTree loaded = <String, List<RepositoryEntry>>{};
  String? problem;
  int askCount = 0;
  int notificationCount = 0;

  String describeVisibleState() {
    final List<String> openFolders = expanded.toList()..sort();
    final List<String> loadedFolders = loaded.keys.toList()..sort();
    return '$openFolders $loadedFolders $problem';
  }

  void expand(String folder) {
    expanded.add(folder);
    if (loaded.containsKey(folder)) {
      return;
    }
    askCount += 1;
    final List<RepositoryEntry>? entries = repository.folders[folder];
    if (entries == null || repository.refusedFolders.contains(folder)) {
      expanded.remove(folder);
      problem = describeListingRefusal(folder);
      return;
    }
    loaded[folder] = entries;
    problem = null;
  }

  void toggle(String folder) {
    if (!expanded.remove(folder)) {
      expand(folder);
    }
  }
}

List<String> _listOpenableFolders(Random random, FolderTree tree) {
  return <String>[...tree.keys, 'missing/${randomHostileText(random)}'];
}

Future<void> _takeRandomStep(
  Random random,
  FileTreeController controller,
  _TreeModel model,
  List<String> folders,
) async {
  final String folder = pickOne(random, folders);
  switch (random.nextInt(4)) {
    case 0:
    case 1:
      model.toggle(folder);
      await controller.toggleFolder(folder);
    case 2:
      final List<String> chain = listAncestorFolders(
        joinRepositoryPath(folder, 'child'),
      );
      for (final String link in chain) {
        model.expand(link);
      }
      await controller.revealFolders(chain);
    default:
      final Set<String> refused = model.repository.refusedFolders;
      if (!refused.remove(folder)) {
        refused.add(folder);
      }
  }
}

Future<void> _runModelSteps(int seed, _StepCheck check) async {
  final Random random = seededRandom(seed);

  for (int tree = 0; tree < _treeCount; tree += 1) {
    final FolderTree folderTree = randomFolderTree(random);
    final ScriptedFolderRepository repository = ScriptedFolderRepository(
      folders: folderTree,
    );
    final FileTreeController controller = FileTreeController(
      fileRepository: repository,
      location: sampleBranchLocation,
    );
    final _TreeModel model = _TreeModel(repository);
    final List<String> folders = _listOpenableFolders(random, folderTree);
    controller.addListener(() => model.notificationCount += 1);

    for (int step = 0; step < _stepsPerTree; step += 1) {
      final String before = model.describeVisibleState();
      final int notificationsBefore = model.notificationCount;
      await _takeRandomStep(random, controller, model, folders);
      check(controller, model, folders);
      if (model.describeVisibleState() != before) {
        expect(model.notificationCount, greaterThan(notificationsBefore));
      }
    }
    controller.dispose();
  }
}

void _checkProblem(
  FileTreeController controller,
  _TreeModel model,
  List<String> _,
) {
  expect(controller.problem, model.problem);
}

void _checkEntries(
  FileTreeController controller,
  _TreeModel model,
  List<String> _,
) {
  for (final String folder in model.repository.folders.keys) {
    final List<RepositoryEntry>? entries = controller.entriesOf(folder);
    expect(entries, model.loaded[folder], reason: folder);
    final List<String> names = <String>[
      for (final RepositoryEntry entry in entries ?? <RepositoryEntry>[])
        entry.name,
    ];
    expect(names, List<String>.of(names)..sort(compareCodePoints));
  }
}

void _checkAsks(
  FileTreeController controller,
  _TreeModel model,
  List<String> _,
) {
  expect(model.repository.askedFolders, hasLength(model.askCount));
}

void _checkExpanded(
  FileTreeController controller,
  _TreeModel model,
  List<String> folders,
) {
  for (final String folder in folders) {
    expect(
      controller.isExpanded(folder),
      model.expanded.contains(folder),
      reason: folder,
    );
  }
}

void _checkOpenFoldersHaveEntries(
  FileTreeController controller,
  _TreeModel model,
  List<String> folders,
) {
  for (final String folder in folders) {
    if (controller.isExpanded(folder)) {
      expect(controller.entriesOf(folder), isNotNull, reason: folder);
    }
  }
}

void main() {
  test('test_problem_property_matches_the_last_finished_load', () async {
    await _runModelSteps(99504, _checkProblem);
  });

  test('test_entries_of_property_matches_the_node_listing_in_order', () async {
    await _runModelSteps(99507, _checkEntries);
  });

  test('test_entries_of_property_never_asks_again_once_loaded', () async {
    await _runModelSteps(99508, _checkAsks);
  });

  test('test_is_expanded_property_follows_every_open_and_close', () async {
    await _runModelSteps(99509, _checkExpanded);
  });

  test('test_is_expanded_property_open_folders_always_have_entries', () async {
    await _runModelSteps(99510, _checkOpenFoldersHaveEntries);
  });

  test('test_toggle_folder_property_notifies_on_every_change', () async {
    await _runModelSteps(99513, _checkExpanded);
  });
}
