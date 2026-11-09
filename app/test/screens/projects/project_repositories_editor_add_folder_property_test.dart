import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/random_inputs.dart';
import 'project_repositories_editor_inputs.dart';

const String _blankMessage = ' ';

void main() {
  test('test_add_folder_property_people_facing_refusals_become_the_'
      'problem', () async {
    final Random random = seededRandom(1050111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = 'x${randomHostileText(random)}';
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: FixedFolderPicker(null),
      );
      subject.devices.refusal = PeopleFacingRefusal(message);
      final String path = randomFolderPath(random, i);

      await subject.typeAndAdd(path);

      expect(subject.editor.addressProblem, message);
      expect(subject.editor.addressController.text, path);
    }
  });

  test('test_add_folder_property_other_failures_reach_the_caller', () async {
    final Random random = seededRandom(1050112);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: FixedFolderPicker(null),
      );
      subject.devices.refusal = pickOne(random, <Object>[
        StateError('broken $i'),
        PeopleFacingRefusal(_blankMessage),
        const FormatException('bad'),
      ]);

      await expectLater(
        subject.typeAndAdd(randomFolderPath(random, i)),
        throwsA(anything),
      );
      expect(subject.editor.addressProblem, isNull);
    }
  });

  test('test_add_folder_property_same_folder_twice_is_refused', () async {
    final Random random = seededRandom(1050113);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = randomFolderPath(random, i);
      final EditorUnderTest subject = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: FixedFolderPicker(null),
      );

      await subject.typeAndAdd(path);
      final List<String> afterFirst = subject.listAddresses();
      await subject.typeAndAdd('$path${pickOne(random, <String>['', '/'])}');

      expect(subject.listAddresses(), afterFirst);
      expect(subject.editor.addressProblem, 'This repo is already added');
    }
  });
}
