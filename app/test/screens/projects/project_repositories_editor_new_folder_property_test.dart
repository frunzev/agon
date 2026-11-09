import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/projects.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'project_repositories_editor_inputs.dart';

const List<String> _folderNames = <String>['billing', 'site-2', 'a b', 'é'];

EditorUnderTest _buildPlannedEditor(Random random, String parent) {
  final EditorUnderTest subject = buildEditorUnderTest(
    initialRepositories: randomInitialDrafts(random),
    folderPicker: null,
  );
  subject.editor.planNewFolder(parent);
  return subject;
}

void main() {
  test('test_create_new_folder_property_nothing_planned_is_ready', () async {
    final Random random = seededRandom(1050401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: null,
      );
      final List<String> before = subject.listAddresses();

      final bool isReady = await subject.editor.createNewFolder(
        pickOne(random, _folderNames),
      );

      expect(isReady, isTrue);
      expect(subject.devices.createdPaths, isEmpty);
      expect(subject.listAddresses(), before);
    }
  });

  test(
    'test_create_new_folder_property_created_folder_joins_the_list',
    () async {
      final Random random = seededRandom(1050402);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String parent = randomFolderPath(random, i);
        final String name = pickOne(random, _folderNames);
        final EditorUnderTest subject = _buildPlannedEditor(random, parent);
        final List<String> before = subject.listAddresses();

        final bool isReady = await subject.editor.createNewFolder(name);

        final String address = renderEditorFolderAddress('$parent/$name');
        expect(isReady, isTrue);
        expect(subject.devices.createdPaths, <String>['$parent/$name']);
        expect(subject.listAddresses(), <String>[...before, address]);
        expect(subject.editor.newFolderParent, isNull);
        expect(subject.editor.gitStartedAddresses, contains(address));
      }
    },
  );

  test('test_create_new_folder_property_refusal_keeps_the_plan', () async {
    final Random random = seededRandom(1050403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String parent = randomFolderPath(random, i);
      final String message = 'taken ${randomHostileText(random)}';
      final EditorUnderTest subject = _buildPlannedEditor(random, parent);
      final List<String> before = subject.listAddresses();
      subject.devices.refusal = PeopleFacingRefusal(message);

      final bool isReady = await subject.editor.createNewFolder(
        pickOne(random, _folderNames),
      );

      expect(isReady, isFalse);
      expect(subject.editor.newFolderParent, parent);
      expect(subject.editor.addressProblem, message);
      expect(subject.listAddresses(), before);
    }
  });

  test('test_create_new_folder_property_listed_folder_is_not_ready', () async {
    final Random random = seededRandom(1050404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String parent = randomFolderPath(random, i);
      final String name = pickOne(random, _folderNames);
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: <RepositoryDraft>[
          RepositoryDraft(
            address: renderEditorFolderAddress('$parent/$name'),
            defaultBranch: 'main',
          ),
        ],
        folderPicker: null,
      );
      subject.editor.planNewFolder(parent);

      final bool isReady = await subject.editor.createNewFolder(name);

      expect(isReady, isFalse);
      expect(subject.editor.addressProblem, repositoryAlreadyAddedProblem);
      expect(subject.editor.repositories, hasLength(1));
    }
  });

  test('test_new_folder_parent_property_reads_the_last_plan', () {
    final Random random = seededRandom(1050405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: null,
      );
      String? expected;
      for (int step = 0; step < random.nextInt(6); step += 1) {
        if (random.nextBool()) {
          expected = randomFolderPath(random, step);
          subject.editor.planNewFolder(expected);
        } else {
          expected = null;
          subject.editor.dropNewFolder();
        }
      }

      expect(subject.editor.newFolderParent, expected);
    }
  });

  test('test_new_folder_parent_property_typing_never_changes_it', () async {
    final Random random = seededRandom(1050406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String parent = randomFolderPath(random, i);
      final EditorUnderTest subject = _buildPlannedEditor(random, parent);

      await subject.typeAndAdd(randomCanonicalHostedAddress(random));
      await subject.typeAndAdd(randomHostileText(random));

      expect(subject.editor.newFolderParent, parent);
    }
  });

  test('test_new_folder_parent_property_kept_verbatim', () {
    final Random random = seededRandom(1050407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String parent = randomHostileText(random);
      final EditorUnderTest subject = _buildPlannedEditor(random, parent);

      expect(subject.editor.newFolderParent, parent);
    }
  });

  test('test_plan_new_folder_property_notifies_once_per_call', () {
    final Random random = seededRandom(1050408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: null,
      );
      final int calls = 1 + random.nextInt(4);

      for (int call = 0; call < calls; call += 1) {
        subject.editor.planNewFolder(randomFolderPath(random, call));
      }

      expect(subject.notificationCount, calls);
    }
  });

  test('test_plan_new_folder_property_twice_is_once', () {
    final Random random = seededRandom(1050409);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String parent = randomFolderPath(random, i);
      final EditorUnderTest subject = _buildPlannedEditor(random, parent);
      final List<String> before = subject.listAddresses();

      subject.editor.planNewFolder(parent);

      expect(subject.editor.newFolderParent, parent);
      expect(subject.listAddresses(), before);
    }
  });

  test('test_plan_new_folder_property_creates_nothing_yet', () {
    final Random random = seededRandom(1050410);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = _buildPlannedEditor(
        random,
        randomFolderPath(random, i),
      );

      expect(subject.devices.createdPaths, isEmpty);
      expect(subject.devices.checkedPaths, isEmpty);
      expect(subject.firstKeptRepositories, isEmpty);
    }
  });

  test('test_drop_new_folder_property_forgets_the_plan', () {
    final Random random = seededRandom(1050411);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = _buildPlannedEditor(
        random,
        randomFolderPath(random, i),
      );

      subject.editor.dropNewFolder();

      expect(subject.editor.newFolderParent, isNull);
      expect(subject.notificationCount, 2);
    }
  });

  test('test_drop_new_folder_property_twice_is_once', () {
    final Random random = seededRandom(1050412);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = _buildPlannedEditor(
        random,
        randomFolderPath(random, i),
      );
      final List<String> before = subject.listAddresses();

      subject.editor.dropNewFolder();
      subject.editor.dropNewFolder();

      expect(subject.editor.newFolderParent, isNull);
      expect(subject.listAddresses(), before);
    }
  });

  test('test_drop_new_folder_property_dropped_plan_creates_nothing', () async {
    final Random random = seededRandom(1050413);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = _buildPlannedEditor(
        random,
        randomFolderPath(random, i),
      );

      subject.editor.dropNewFolder();
      final bool isReady = await subject.editor.createNewFolder('billing');

      expect(isReady, isTrue);
      expect(subject.devices.createdPaths, isEmpty);
    }
  });
}
