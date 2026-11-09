import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/random_inputs.dart';
import 'project_repositories_editor_inputs.dart';

void main() {
  test('test_choose_folder_property_picked_folder_joins_once', () async {
    final Random random = seededRandom(1050101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = randomFolderPath(random, i);
      final FixedFolderPicker picker = FixedFolderPicker(path);
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: picker,
      );
      final List<String> before = subject.listAddresses();

      await subject.editor.chooseFolder(picker);
      await subject.editor.chooseFolder(picker);

      expect(subject.listAddresses(), <String>[
        ...before,
        renderEditorFolderAddress(path),
      ]);
      expect(subject.devices.checkedPaths, <String>[path, path]);
      expect(subject.editor.addressProblem, isNotNull);
    }
  });

  test('test_choose_folder_property_cancelled_pick_changes_nothing', () async {
    final Random random = seededRandom(1050102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FixedFolderPicker picker = FixedFolderPicker(null);
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: picker,
      );
      final List<String> before = subject.listAddresses();

      await subject.editor.chooseFolder(picker);

      expect(subject.listAddresses(), before);
      expect(subject.devices.checkedPaths, isEmpty);
      expect(subject.notificationCount, 0);
    }
  });

  test('test_choose_folder_property_refusals_show_and_keep_list', () async {
    final Random random = seededRandom(1050103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = 'no ${randomHostileText(random)}';
      final FixedFolderPicker picker = FixedFolderPicker(
        randomFolderPath(random, i),
      );
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: picker,
      );
      final List<String> before = subject.listAddresses();
      subject.devices.refusal = PeopleFacingRefusal(message);

      await subject.editor.chooseFolder(picker);

      expect(subject.listAddresses(), before);
      expect(subject.editor.addressProblem, message);
      expect(subject.editor.gitStartedAddresses, isEmpty);
    }
  });

  test('test_choose_folder_property_closed_editor_never_checks', () async {
    final Random random = seededRandom(1050104);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final HeldFolderPicker picker = HeldFolderPicker();
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: picker,
      );

      final Future<void> choosing = subject.editor.chooseFolder(picker);
      subject.editor.dispose();
      picker.chosenPath.complete(randomFolderPath(random, i));
      await choosing;

      expect(subject.devices.checkedPaths, isEmpty);
    }
  });

  test(
    'test_choose_new_folder_place_property_picked_parent_is_planned',
    () async {
      final Random random = seededRandom(1050105);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String parent = randomFolderPath(random, i);
        final FixedFolderPicker picker = FixedFolderPicker(parent);
        final EditorUnderTest subject = buildEditorUnderTest(
          initialRepositories: randomInitialDrafts(random),
          folderPicker: picker,
        );
        final List<String> before = subject.listAddresses();

        await subject.editor.chooseNewFolderPlace(picker);

        expect(subject.editor.newFolderParent, parent);
        expect(subject.editor.hasNoRepository, isFalse);
        expect(subject.listAddresses(), before);
        expect(subject.devices.createdPaths, isEmpty);
      }
    },
  );

  test(
    'test_choose_new_folder_place_property_cancel_keeps_the_plan',
    () async {
      final Random random = seededRandom(1050106);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FixedFolderPicker picker = FixedFolderPicker(null);
        final EditorUnderTest subject = buildEditorUnderTest(
          initialRepositories: randomInitialDrafts(random),
          folderPicker: picker,
        );
        final String? planned = random.nextBool()
            ? randomFolderPath(random, i)
            : null;
        if (planned != null) {
          subject.editor.planNewFolder(planned);
        }

        await subject.editor.chooseNewFolderPlace(picker);

        expect(subject.editor.newFolderParent, planned);
      }
    },
  );

  test(
    'test_choose_new_folder_place_property_closed_editor_is_quiet',
    () async {
      final Random random = seededRandom(1050107);

      for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
        final HeldFolderPicker picker = HeldFolderPicker();
        final EditorUnderTest subject = buildEditorUnderTest(
          initialRepositories: randomInitialDrafts(random),
          folderPicker: picker,
        );

        final Future<void> choosing = subject.editor.chooseNewFolderPlace(
          picker,
        );
        subject.editor.dispose();
        picker.chosenPath.complete(randomFolderPath(random, i));
        await choosing;

        expect(subject.editor.newFolderParent, isNull);
        expect(subject.notificationCount, 0);
      }
    },
  );

  test('test_project_repositories_editor_dispose_property_late_answers_'
      'are_ignored', () async {
    final Random random = seededRandom(1050108);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: FixedFolderPicker(null),
      );
      final List<String> before = subject.listAddresses();
      subject.devices.heldAnswer = Completer<void>();
      if (random.nextBool()) {
        subject.devices.refusal = PeopleFacingRefusal('late $i');
      }

      final Future<void> adding = subject.typeAndAdd(
        randomFolderPath(random, i),
      );
      subject.editor.dispose();
      subject.devices.heldAnswer!.complete();
      await adding;

      expect(subject.listAddresses(), before);
      expect(subject.notificationCount, 0);
    }
  });

  test('test_project_repositories_editor_dispose_property_releases_the_'
      'address_field', () {
    final Random random = seededRandom(1050109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: null,
      );
      subject.editor.addressController.text = randomHostileText(random);

      subject.editor.dispose();

      expect(
        () => subject.editor.addressController.addListener(() {}),
        throwsFlutterError,
      );
      expect(() => subject.editor.addListener(() {}), throwsFlutterError);
    }
  });

  test('test_project_repositories_editor_dispose_property_keeps_last_'
      'state_readable', () async {
    final Random random = seededRandom(1050110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: null,
      );
      await subject.typeAndAdd(randomCanonicalHostedAddress(random));
      final List<String> before = subject.listAddresses();

      subject.editor.dispose();

      expect(subject.listAddresses(), before);
      expect(subject.editor.hasNoRepository, before.isEmpty);
    }
  });
}
