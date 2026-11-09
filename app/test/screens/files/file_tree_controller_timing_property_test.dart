import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_tree_controller.dart';
import 'package:agent_orchestration/screens/files/repository_file_paths.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'file_property_inputs.dart';

const int _concurrentRounds = 60;
const int _actionsPerRound = 25;

final class _NotificationCounter {
  int count = 0;

  void countOne() {
    count += 1;
  }
}

FileTreeController _openController(ScriptedFolderRepository repository) {
  return FileTreeController(
    fileRepository: repository,
    location: sampleBranchLocation,
  );
}

String _pickDeepestFolder(Random random, FolderTree tree) {
  final List<String> folders = tree.keys.toList()
    ..sort((String first, String second) => second.length - first.length);
  return pickOne(random, folders.take(3).toList());
}

List<String> _listChainTo(String folder) {
  return listAncestorFolders(joinRepositoryPath(folder, 'child'));
}

Future<void> _releaseEveryAnswer(
  Random random,
  ScriptedFolderRepository repository,
) async {
  while (repository.heldAnswers.isNotEmpty) {
    repository.releaseOneAnswer(random);
    await pumpEventQueue();
  }
}

Future<ScriptedFolderRepository> _runConcurrentRound(Random random) async {
  final FolderTree tree = randomFolderTree(random);
  final ScriptedFolderRepository repository = ScriptedFolderRepository(
    folders: tree,
  )..isHoldingAnswers = true;
  final FileTreeController controller = _openController(repository);
  final List<String> folders = tree.keys.toList();
  final List<Future<void>> actions = <Future<void>>[];

  for (int i = 0; i < _actionsPerRound; i += 1) {
    final String folder = pickOne(random, folders);
    if (random.nextInt(4) == 0) {
      actions.add(controller.revealFolders(_listChainTo(folder)));
    } else {
      actions.add(controller.toggleFolder(folder));
    }
    if (random.nextBool()) {
      repository.refusedFolders.add(pickOne(random, folders));
    }
    if (random.nextBool() && repository.heldAnswers.isNotEmpty) {
      repository.releaseOneAnswer(random);
    }
    await pumpEventQueue();
  }
  await _releaseEveryAnswer(random, repository);
  await Future.wait(actions);

  for (final String folder in folders) {
    if (controller.isExpanded(folder)) {
      expect(controller.entriesOf(folder), isNotNull, reason: folder);
    }
  }
  controller.dispose();
  return repository;
}

void main() {
  test('test_reveal_folders_property_asks_in_the_given_order', () async {
    final Random random = seededRandom(99601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: tree,
      );
      final FileTreeController controller = _openController(repository);
      final List<String> chain = _listChainTo(
        _pickDeepestFolder(random, tree),
      );
      await controller.revealFolders(chain);

      expect(repository.askedFolders, chain);
      for (final String folder in chain) {
        expect(controller.isExpanded(folder), isTrue);
        expect(controller.entriesOf(folder), tree[folder]);
      }
      controller.dispose();
    }
  });

  test('test_reveal_folders_property_notifies_for_loaded_folders', () async {
    final Random random = seededRandom(99602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final FileTreeController controller = _openController(
        ScriptedFolderRepository(folders: tree),
      );
      final String folder = pickOne(random, tree.keys.toList());
      await controller.toggleFolder(folder);
      await controller.toggleFolder(folder);
      final _NotificationCounter counter = _NotificationCounter();
      controller.addListener(counter.countOne);
      await controller.revealFolders(<String>[folder]);

      expect(controller.isExpanded(folder), isTrue);
      expect(counter.count, greaterThan(0));
      controller.dispose();
    }
  });

  test('test_reveal_folders_property_stops_after_dispose', () async {
    final Random random = seededRandom(99603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: tree,
      )..isHoldingAnswers = true;
      final FileTreeController controller = _openController(repository);
      final List<String> chain = _listChainTo(
        _pickDeepestFolder(random, tree),
      );
      final Future<void> reveal = controller.revealFolders(chain);
      await pumpEventQueue();
      controller.dispose();
      await _releaseEveryAnswer(random, repository);
      await reveal;

      expect(repository.askedFolders, <String>[chain.first]);
    }
  });

  test('test_load_folder_property_unexplained_problems_propagate', () async {
    final Random random = seededRandom(99604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: randomFolderTree(random),
      );
      final ArgumentError problem = ArgumentError(randomHostileText(random));
      repository.problemToThrow = problem;
      final FileTreeController controller = _openController(repository);

      await expectLater(controller.toggleFolder(''), throwsA(same(problem)));
      expect(controller.problem, isNull);
      controller.dispose();
    }
  });

  test('test_load_folder_property_one_request_per_folder_at_a_time', () async {
    final Random random = seededRandom(99605);

    for (int round = 0; round < _concurrentRounds; round += 1) {
      final ScriptedFolderRepository repository = await _runConcurrentRound(
        random,
      );

      expect(repository.repeatedPendingFolders, isEmpty);
    }
  });

  test('test_load_folder_property_settles_with_open_folders_filled', () async {
    final Random random = seededRandom(99606);

    for (int round = 0; round < _concurrentRounds; round += 1) {
      final ScriptedFolderRepository repository = await _runConcurrentRound(
        random,
      );

      expect(repository.heldAnswers, isEmpty);
    }
  });

  test('test_dispose_property_late_answers_never_notify', () async {
    final Random random = seededRandom(99607);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: tree,
      )..isHoldingAnswers = true;
      final FileTreeController controller = _openController(repository);
      final _NotificationCounter counter = _NotificationCounter();
      final Future<void> toggle = controller.toggleFolder(
        pickOne(random, tree.keys.toList()),
      );
      controller.addListener(counter.countOne);
      controller.dispose();
      await _releaseEveryAnswer(random, repository);
      await toggle;

      expect(counter.count, 0);
    }
  });

  test('test_dispose_property_late_refusals_never_throw', () async {
    final Random random = seededRandom(99608);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: tree,
      )..isHoldingAnswers = true;
      final FileTreeController controller = _openController(repository);
      final String folder = pickOne(random, tree.keys.toList());
      final Future<void> toggle = controller.toggleFolder(folder);
      repository.refusedFolders.add(folder);
      controller.dispose();
      await _releaseEveryAnswer(random, repository);

      await expectLater(toggle, completes);
    }
  });

  test('test_dispose_property_reveal_still_finishes', () async {
    final Random random = seededRandom(99609);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: tree,
      )..isHoldingAnswers = true;
      final FileTreeController controller = _openController(repository);
      final Future<void> reveal = controller.revealFolders(
        _listChainTo(_pickDeepestFolder(random, tree)),
      );
      await pumpEventQueue();
      controller.dispose();
      await _releaseEveryAnswer(random, repository);

      await expectLater(reveal, completes);
    }
  });
}
