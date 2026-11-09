import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/files/file_tree_controller.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'file_property_inputs.dart';

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

void main() {
  test('test_file_tree_controller_new_property_keeps_its_collaborators', () {
    final Random random = seededRandom(99501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: randomFolderTree(random),
      );
      final FileTreeController controller = _openController(repository);

      expect(controller.fileRepository, same(repository));
      expect(controller.location, same(sampleBranchLocation));
      controller.dispose();
    }
  });

  test('test_file_tree_controller_new_property_starts_with_nothing', () {
    final Random random = seededRandom(99502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final FileTreeController controller = _openController(
        ScriptedFolderRepository(folders: tree),
      );

      expect(controller.problem, isNull);
      for (final String folder in <String>[
        ...tree.keys,
        randomHostileText(random),
      ]) {
        expect(controller.isExpanded(folder), isFalse);
        expect(controller.entriesOf(folder), isNull);
      }
      controller.dispose();
    }
  });

  test('test_file_tree_controller_new_property_asks_nothing_yet', () {
    final Random random = seededRandom(99503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: randomFolderTree(random),
      );
      _openController(repository).dispose();

      expect(repository.askedFolders, isEmpty);
    }
  });

  test('test_problem_property_is_the_people_facing_message', () async {
    final Random random = seededRandom(99505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: randomFolderTree(random),
      );
      final AppServerRefusal refusal = AppServerRefusal(
        status: 400 + random.nextInt(200),
        reason: 'refused ${randomHostileText(random)}',
      );
      repository.problemToThrow = refusal;
      final FileTreeController controller = _openController(repository);
      await controller.toggleFolder('');

      expect(controller.problem, describeProblemForPeople(refusal));
      expect(controller.problem, refusal.message);
      controller.dispose();
    }
  });

  test('test_problem_property_clears_after_a_successful_retry', () async {
    final Random random = seededRandom(99506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: randomFolderTree(random),
      );
      final FileTreeController controller = _openController(repository);
      repository.refusedFolders.add('');
      await controller.revealFolders(const <String>['']);
      expect(controller.problem, describeListingRefusal(''));
      repository.refusedFolders.clear();
      await controller.revealFolders(const <String>['']);

      expect(controller.problem, isNull);
      expect(controller.entriesOf(''), repository.folders['']);
      controller.dispose();
    }
  });

  test('test_toggle_folder_property_twice_restores_a_loaded_folder', () async {
    final Random random = seededRandom(99511);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: tree,
      );
      final FileTreeController controller = _openController(repository);
      final String folder = pickOne(random, tree.keys.toList());
      await controller.toggleFolder(folder);
      await controller.toggleFolder(folder);
      await controller.toggleFolder(folder);
      await controller.toggleFolder(folder);

      expect(controller.isExpanded(folder), isFalse);
      expect(controller.entriesOf(folder), tree[folder]);
      expect(repository.askedFolders, <String>[folder]);
      controller.dispose();
    }
  });

  test(
    'test_toggle_folder_property_failed_folder_reopens_on_one_tap',
    () async {
      final Random random = seededRandom(99512);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FolderTree tree = randomFolderTree(random);
        final ScriptedFolderRepository repository = ScriptedFolderRepository(
          folders: tree,
        );
        final FileTreeController controller = _openController(repository);
        final String folder = pickOne(random, tree.keys.toList());
        repository.refusedFolders.add(folder);
        await controller.toggleFolder(folder);
        expect(controller.isExpanded(folder), isFalse);
        repository.refusedFolders.clear();
        await controller.toggleFolder(folder);

        expect(controller.isExpanded(folder), isTrue);
        expect(controller.entriesOf(folder), tree[folder]);
        controller.dispose();
      }
    },
  );

  test('test_expand_folder_property_marks_open_before_the_answer', () async {
    final Random random = seededRandom(99514);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: tree,
      )..isHoldingAnswers = true;
      final FileTreeController controller = _openController(repository);
      final _NotificationCounter counter = _NotificationCounter();
      controller.addListener(counter.countOne);
      final String folder = pickOne(random, tree.keys.toList());
      final Future<void> toggle = controller.toggleFolder(folder);

      expect(controller.isExpanded(folder), isTrue);
      expect(controller.entriesOf(folder), isNull);
      expect(counter.count, 1);
      repository.releaseOneAnswer(random);
      await toggle;
      expect(controller.entriesOf(folder), tree[folder]);
      controller.dispose();
    }
  });

  test('test_expand_folder_property_loaded_folder_opens_unasked', () async {
    final Random random = seededRandom(99515);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: tree,
      );
      final FileTreeController controller = _openController(repository);
      final String folder = pickOne(random, tree.keys.toList());
      await controller.revealFolders(<String>[folder]);
      await controller.toggleFolder(folder);
      final _NotificationCounter counter = _NotificationCounter();
      controller.addListener(counter.countOne);
      await controller.toggleFolder(folder);

      expect(controller.isExpanded(folder), isTrue);
      expect(counter.count, 1);
      expect(repository.askedFolders, <String>[folder]);
      controller.dispose();
    }
  });

  test('test_expand_folder_property_parallel_opens_share_a_request', () async {
    final Random random = seededRandom(99516);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final ScriptedFolderRepository repository = ScriptedFolderRepository(
        folders: tree,
      )..isHoldingAnswers = true;
      final FileTreeController controller = _openController(repository);
      final String folder = pickOne(random, tree.keys.toList());
      final Future<void> first = controller.toggleFolder(folder);
      final Future<void> second = controller.revealFolders(<String>[folder]);
      await pumpEventQueue();
      repository.releaseOneAnswer(random);
      await Future.wait(<Future<void>>[first, second]);

      expect(repository.askedFolders, <String>[folder]);
      expect(repository.heldAnswers, isEmpty);
      expect(controller.entriesOf(folder), tree[folder]);
      controller.dispose();
    }
  });

  test('test_entries_of_property_unknown_folders_have_none', () async {
    final Random random = seededRandom(99517);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final FileTreeController controller = _openController(
        ScriptedFolderRepository(folders: tree),
      );
      await controller.revealFolders(tree.keys.toList());
      final String unknown = 'gone/${randomHostileText(random)}';

      expect(controller.entriesOf(unknown), isNull);
      expect(controller.isExpanded(unknown), isFalse);
      controller.dispose();
    }
  });

  test('test_is_expanded_property_closing_keeps_loaded_entries', () async {
    final Random random = seededRandom(99518);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderTree tree = randomFolderTree(random);
      final FileTreeController controller = _openController(
        ScriptedFolderRepository(folders: tree),
      );
      final String folder = pickOne(random, tree.keys.toList());
      await controller.toggleFolder(folder);
      await controller.toggleFolder(folder);

      expect(controller.isExpanded(folder), isFalse);
      expect(controller.entriesOf(folder), tree[folder]);
      controller.dispose();
    }
  });
}
