import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';

import '../../support/fixed_folder_picker.dart';
import '../../support/random_inputs.dart';
import 'project_repositories_editor_inputs.dart';

const int _stepsPerRound = 12;
const int _rounds = 40;

final class _EditorModel {
  final List<String> addresses = <String>[];
  final Set<String> gitStarted = <String>{};
  String? newFolderParent;
}

Future<void> _takeRandomStep(
  Random random,
  EditorUnderTest subject,
  _EditorModel model,
  int step,
) async {
  final int choice = random.nextInt(6);
  if (choice == 0) {
    final String address = randomCanonicalHostedAddress(random);
    await subject.typeAndAdd(randomSpellingOf(random, address));
    if (!model.addresses.contains(address)) {
      model.addresses.add(address);
    }
  } else if (choice == 1 && model.addresses.isNotEmpty) {
    final String known = pickOne(random, model.addresses);
    await subject.typeAndAdd(known);
  } else if (choice == 2) {
    final String path = randomFolderPath(random, step % 3);
    final String address = renderEditorFolderAddress(path);
    final bool isGitless = random.nextBool();
    if (isGitless) {
      subject.devices.gitlessPaths.add(path);
    }
    await subject.typeAndAdd(path);
    if (!model.addresses.contains(address)) {
      model.addresses.add(address);
      if (isGitless) {
        model.gitStarted.add(address);
      }
    }
    subject.devices.gitlessPaths.remove(path);
  } else if (choice == 3 && model.addresses.isNotEmpty) {
    final String removed = pickOne(random, model.addresses);
    subject.editor.removeRepository(removed);
    model.addresses.remove(removed);
  } else if (choice == 4) {
    final String parent = randomFolderPath(random, step);
    subject.editor.planNewFolder(parent);
    model.newFolderParent = parent;
  } else {
    subject.editor.dropNewFolder();
    model.newFolderParent = null;
  }
}

Future<void> _walkRandomSteps(
  Random random,
  void Function(EditorUnderTest subject, _EditorModel model) check,
) async {
  for (int round = 0; round < _rounds; round += 1) {
    final EditorUnderTest subject = buildEditorUnderTest(
      initialRepositories: const <RepositoryDraft>[],
      folderPicker: FixedFolderPicker(null),
    );
    final _EditorModel model = _EditorModel();
    for (int step = 0; step < _stepsPerRound; step += 1) {
      await _takeRandomStep(random, subject, model, step);
      check(subject, model);
    }
  }
}

void main() {
  test('test_project_repositories_editor_new_property_keeps_the_initial_'
      'drafts', () {
    final Random random = seededRandom(1050201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryDraft> drafts = randomInitialDrafts(random);
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: drafts,
        folderPicker: null,
      );

      expect(subject.editor.repositories, orderedEquals(drafts));
      expect(subject.editor.hasNoRepository, drafts.isEmpty);
      expect(subject.firstKeptRepositories, isEmpty);
    }
  });

  test('test_project_repositories_editor_new_property_starts_clean', () {
    final Random random = seededRandom(1050202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: random.nextBool() ? FixedFolderPicker(null) : null,
      );

      expect(subject.editor.addressProblem, isNull);
      expect(subject.editor.newFolderParent, isNull);
      expect(subject.editor.gitStartedAddresses, isEmpty);
      expect(subject.editor.addressController.text, isEmpty);
    }
  });

  test('test_project_repositories_editor_new_property_owns_its_copy', () {
    final Random random = seededRandom(1050203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryDraft> drafts = randomInitialDrafts(random);
      final List<RepositoryDraft> expected = List<RepositoryDraft>.of(drafts);
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: drafts,
        folderPicker: null,
      );

      drafts.clear();

      expect(subject.editor.repositories, orderedEquals(expected));
    }
  });

  test('test_repositories_property_match_a_model_of_every_step', () async {
    await _walkRandomSteps(seededRandom(1050204), (
      EditorUnderTest subject,
      _EditorModel model,
    ) {
      expect(subject.listAddresses(), model.addresses);
    });
  });

  test('test_repositories_property_never_lists_an_address_twice', () async {
    await _walkRandomSteps(seededRandom(1050205), (
      EditorUnderTest subject,
      _EditorModel model,
    ) {
      final List<String> addresses = subject.listAddresses();
      expect(addresses.toSet(), hasLength(addresses.length));
    });
  });

  test('test_repositories_property_callers_cannot_change_the_list', () {
    final Random random = seededRandom(1050206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: null,
      );
      final RepositoryDraft extra = RepositoryDraft(
        address: randomCanonicalHostedAddress(random),
        defaultBranch: 'main',
      );

      expect(() => subject.editor.repositories.add(extra), throwsA(anything));
      expect(subject.editor.repositories, isNot(contains(extra)));
    }
  });

  test('test_git_started_addresses_property_match_the_model', () async {
    await _walkRandomSteps(seededRandom(1050207), (
      EditorUnderTest subject,
      _EditorModel model,
    ) {
      for (final String address in model.gitStarted) {
        expect(subject.editor.gitStartedAddresses, contains(address));
      }
      for (final String address in subject.editor.gitStartedAddresses) {
        expect(model.gitStarted, contains(address));
      }
    });
  });

  test('test_git_started_addresses_property_only_folder_addresses', () async {
    await _walkRandomSteps(seededRandom(1050208), (
      EditorUnderTest subject,
      _EditorModel model,
    ) {
      for (final String address in subject.editor.gitStartedAddresses) {
        expect(address, startsWith('local:'));
      }
    });
  });

  test('test_git_started_addresses_property_callers_cannot_add', () async {
    final Random random = seededRandom(1050209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: FixedFolderPicker(null),
      );
      final String path = randomFolderPath(random, i);
      subject.devices.gitlessPaths.add(path);
      await subject.typeAndAdd(path);
      final String address = randomCanonicalHostedAddress(random);

      expect(
        () => subject.editor.gitStartedAddresses.add(address),
        throwsA(anything),
      );
      expect(subject.editor.gitStartedAddresses, <String>{
        renderEditorFolderAddress(path),
      });
    }
  });

  test('test_has_no_repository_property_matches_the_model', () async {
    await _walkRandomSteps(seededRandom(1050210), (
      EditorUnderTest subject,
      _EditorModel model,
    ) {
      expect(
        subject.editor.hasNoRepository,
        model.addresses.isEmpty && model.newFolderParent == null,
      );
    });
  });

  test('test_has_no_repository_property_a_planned_folder_counts', () {
    final Random random = seededRandom(1050211);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: const <RepositoryDraft>[],
        folderPicker: null,
      );

      subject.editor.planNewFolder(randomFolderPath(random, i));
      expect(subject.editor.hasNoRepository, isFalse);
      subject.editor.dropNewFolder();
      expect(subject.editor.hasNoRepository, isTrue);
    }
  });

  test('test_has_no_repository_property_removing_all_empties_it', () {
    final Random random = seededRandom(1050212);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryDraft> drafts = randomInitialDrafts(random);
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: drafts,
        folderPicker: null,
      );

      for (final RepositoryDraft draft in drafts.reversed) {
        expect(subject.editor.hasNoRepository, isFalse);
        subject.editor.removeRepository(draft.address);
      }

      expect(subject.editor.hasNoRepository, isTrue);
    }
  });
}
