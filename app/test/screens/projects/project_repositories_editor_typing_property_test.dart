import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/projects.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/random_inputs.dart';
import 'project_repositories_editor_inputs.dart';

const String _pasteProblem = 'Paste an address like github.com/acme/repo';
const List<String> _notAddresses = <String>[
  '',
  '  ',
  'nonsense',
  'github.com/acme',
  'ftp://github.com/acme/app',
  'github.com/acme/app/extra',
  'github.com/../app',
  'localhost/acme/app',
];

void main() {
  test(
    'test_add_typed_repository_property_keeps_the_canonical_address',
    () async {
      final Random random = seededRandom(1050301);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String address = randomCanonicalHostedAddress(random);
        final EditorUnderTest subject = buildEditorUnderTest(
          initialRepositories: const <RepositoryDraft>[],
          folderPicker: random.nextBool() ? FixedFolderPicker(null) : null,
        );

        await subject.typeAndAdd(randomSpellingOf(random, address));

        expect(subject.listAddresses(), <String>[address]);
        expect(subject.editor.repositories.single.defaultBranch, 'main');
        expect(subject.editor.addressController.text, isEmpty);
        expect(subject.devices.checkedPaths, isEmpty);
      }
    },
  );

  test('test_add_typed_repository_property_any_spelling_of_an_added_'
      'address_is_refused', () async {
    final Random random = seededRandom(1050302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = randomCanonicalHostedAddress(random);
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: <RepositoryDraft>[
          ...randomInitialDrafts(random),
          RepositoryDraft(address: address, defaultBranch: 'trunk'),
        ],
        folderPicker: null,
      );
      final List<String> before = subject.listAddresses();
      final String spelling = randomSpellingOf(random, address);

      await subject.typeAndAdd(spelling);

      expect(subject.listAddresses(), before);
      expect(subject.editor.addressProblem, repositoryAlreadyAddedProblem);
      expect(subject.editor.addressController.text, spelling);
    }
  });

  test(
    'test_add_typed_repository_property_non_addresses_are_refused',
    () async {
      final Random random = seededRandom(1050303);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String text = random.nextBool()
            ? pickOne(random, _notAddresses)
            : 'x${randomHostileText(random)}';
        final EditorUnderTest subject = buildEditorUnderTest(
          initialRepositories: randomInitialDrafts(random),
          folderPicker: null,
        );
        final List<String> before = subject.listAddresses();

        await subject.typeAndAdd(text);

        expect(subject.listAddresses(), before);
        expect(subject.editor.addressProblem, _pasteProblem);
        expect(subject.notificationCount, 1);
      }
    },
  );

  test('test_add_typed_repository_property_folders_need_a_picker', () async {
    final Random random = seededRandom(1050304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = randomFolderPath(random, i);
      final bool hasPicker = random.nextBool();
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: const <RepositoryDraft>[],
        folderPicker: hasPicker ? FixedFolderPicker(null) : null,
      );

      await subject.typeAndAdd(path);

      expect(
        subject.devices.checkedPaths,
        hasPicker ? <String>[path] : isEmpty,
      );
      expect(
        subject.listAddresses(),
        hasPicker ? <String>[renderEditorFolderAddress(path)] : isEmpty,
      );
      expect(
        subject.editor.addressProblem,
        hasPicker ? isNull : _pasteProblem,
      );
    }
  });

  test('test_show_address_problem_property_shows_the_words_verbatim', () {
    final Random random = seededRandom(1050305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: null,
      );
      final String? problem = randomOptionalHostileText(random);

      subject.editor.showAddressProblem(problem);

      expect(subject.editor.addressProblem, problem);
      expect(subject.notificationCount, 1);
    }
  });

  test('test_show_address_problem_property_last_call_wins', () {
    final Random random = seededRandom(1050306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: null,
      );
      final List<String?> problems = <String?>[
        for (int call = 0; call < 1 + random.nextInt(5); call += 1)
          randomOptionalHostileText(random),
      ];

      for (final String? problem in problems) {
        subject.editor.showAddressProblem(problem);
      }

      expect(subject.editor.addressProblem, problems.last);
      expect(subject.notificationCount, problems.length);
    }
  });

  test('test_show_address_problem_property_leaves_the_list_alone', () {
    final Random random = seededRandom(1050307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: null,
      );
      final List<String> before = subject.listAddresses();
      final String typed = randomHostileText(random);
      subject.editor.addressController.text = typed;

      subject.editor.showAddressProblem(randomHostileText(random));

      expect(subject.listAddresses(), before);
      expect(subject.editor.addressController.text, typed);
      expect(subject.editor.newFolderParent, isNull);
    }
  });

  test('test_address_problem_property_a_kept_repository_clears_it', () async {
    final Random random = seededRandom(1050308);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: null,
      );
      await subject.typeAndAdd(pickOne(random, _notAddresses));
      expect(subject.editor.addressProblem, _pasteProblem);

      await subject.typeAndAdd(randomCanonicalHostedAddress(random));

      expect(subject.editor.addressProblem, isNull);
    }
  });

  test('test_address_problem_property_refusals_never_clear_it', () async {
    final Random random = seededRandom(1050309);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: null,
      );
      final String address = randomCanonicalHostedAddress(random);
      await subject.typeAndAdd(address);
      await subject.typeAndAdd(pickOne(random, <String>[address, 'nope']));

      expect(subject.editor.addressProblem, isNotNull);
    }
  });

  test('test_address_problem_property_one_problem_at_a_time', () async {
    final Random random = seededRandom(1050310);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: const <RepositoryDraft>[],
        folderPicker: null,
      );
      final String address = randomCanonicalHostedAddress(random);
      await subject.typeAndAdd(address);
      await subject.typeAndAdd('nope');
      await subject.typeAndAdd(address);

      expect(subject.editor.addressProblem, repositoryAlreadyAddedProblem);
    }
  });
}
