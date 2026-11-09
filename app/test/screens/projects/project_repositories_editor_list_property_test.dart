import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/projects.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/random_inputs.dart';
import 'project_repositories_editor_inputs.dart';

void main() {
  test('test_remove_repository_property_removes_only_that_address', () {
    final Random random = seededRandom(1050501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryDraft> drafts = <RepositoryDraft>[
        ...randomInitialDrafts(random),
        RepositoryDraft(
          address: randomCanonicalHostedAddress(random),
          defaultBranch: 'main',
        ),
      ];
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: drafts,
        folderPicker: null,
      );
      final String removed = pickOne(random, drafts).address;

      subject.editor.removeRepository(removed);

      expect(subject.listAddresses(), <String>[
        for (final RepositoryDraft draft in drafts)
          if (draft.address != removed) draft.address,
      ]);
      expect(subject.notificationCount, 1);
    }
  });

  test('test_remove_repository_property_unknown_address_changes_nothing', () {
    final Random random = seededRandom(1050502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: null,
      );
      final List<String> before = subject.listAddresses();

      subject.editor.removeRepository('unknown ${randomHostileText(random)}');

      expect(subject.listAddresses(), before);
    }
  });

  test('test_remove_repository_property_removed_address_can_return', () async {
    final Random random = seededRandom(1050503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = randomCanonicalHostedAddress(random);
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: null,
      );
      await subject.typeAndAdd(address);

      subject.editor.removeRepository(address);
      await subject.typeAndAdd(randomSpellingOf(random, address));

      final List<String> listed = subject.listAddresses();
      expect(listed.where((String shown) => shown == address), <String>[
        address,
      ]);
      expect(subject.editor.addressProblem, isNull);
    }
  });

  test('test_list_added_addresses_property_initial_drafts_count', () async {
    final Random random = seededRandom(1050504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryDraft> drafts = <RepositoryDraft>[
        ...randomInitialDrafts(random),
        RepositoryDraft(
          address: randomCanonicalHostedAddress(random),
          defaultBranch: 'main',
        ),
      ];
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: drafts,
        folderPicker: null,
      );

      await subject.typeAndAdd(pickOne(random, drafts).address);

      expect(subject.editor.addressProblem, repositoryAlreadyAddedProblem);
      expect(subject.editor.repositories, hasLength(drafts.length));
    }
  });

  test(
    'test_list_added_addresses_property_folders_and_hosted_differ',
    () async {
      final Random random = seededRandom(1050505);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String path = randomFolderPath(random, i);
        final EditorUnderTest subject = buildEditorUnderTest(
          initialRepositories: const <RepositoryDraft>[],
          folderPicker: FixedFolderPicker(null),
        );

        await subject.typeAndAdd(path);
        await subject.typeAndAdd(randomCanonicalHostedAddress(random));

        expect(subject.editor.repositories, hasLength(2));
        expect(subject.editor.addressProblem, isNull);
      }
    },
  );

  test('test_list_added_addresses_property_follow_every_removal', () async {
    final Random random = seededRandom(1050506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryDraft> drafts = randomInitialDrafts(random);
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: drafts,
        folderPicker: null,
      );
      for (final RepositoryDraft draft in drafts) {
        subject.editor.removeRepository(draft.address);
      }

      for (final RepositoryDraft draft in drafts) {
        await subject.typeAndAdd(draft.address);
        expect(subject.editor.addressProblem, isNull);
      }
      expect(subject.editor.repositories, hasLength(drafts.length));
    }
  });

  test('test_keep_repository_property_first_kept_is_reported_once', () async {
    final Random random = seededRandom(1050507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: const <RepositoryDraft>[],
        folderPicker: null,
      );
      final List<String> addresses = <String>[
        for (int index = 0; index < 1 + random.nextInt(4); index += 1)
          '${randomCanonicalHostedAddress(random)}-$index',
      ];

      for (final String address in addresses) {
        await subject.typeAndAdd(address);
      }

      expect(subject.firstKeptRepositories, hasLength(1));
      expect(subject.firstKeptRepositories.single.address, addresses.first);
    }
  });

  test(
    'test_keep_repository_property_reported_again_after_emptying',
    () async {
      final Random random = seededRandom(1050508);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<RepositoryDraft> drafts = randomInitialDrafts(random);
        final EditorUnderTest subject = buildEditorUnderTest(
          initialRepositories: drafts,
          folderPicker: null,
        );
        for (final RepositoryDraft draft in drafts) {
          subject.editor.removeRepository(draft.address);
        }
        final String address = randomCanonicalHostedAddress(random);

        await subject.typeAndAdd(address);

        expect(subject.firstKeptRepositories, hasLength(1));
        expect(subject.firstKeptRepositories.single.address, address);
      }
    },
  );

  test('test_keep_repository_property_clears_text_and_problem', () async {
    final Random random = seededRandom(1050509);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: null,
      );
      subject.editor.showAddressProblem(randomHostileText(random));
      final int notificationsBefore = subject.notificationCount;

      await subject.typeAndAdd(randomCanonicalHostedAddress(random));

      expect(subject.editor.addressController.text, isEmpty);
      expect(subject.editor.addressProblem, isNull);
      expect(subject.notificationCount, notificationsBefore + 1);
    }
  });
}
