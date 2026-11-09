import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/projects/folder_choice.dart';
import 'package:agent_orchestration/screens/projects/new_project_repos_field.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'repos_field_inputs.dart';

void main() {
  test('test_local_folder_actions_new_property_keeps_each_callback', () {
    final Random random = seededRandom(105101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ReposFieldInputs inputs = ReposFieldInputs(random);
      final LocalFolderActions actions = inputs.folderActions;

      actions.onFolderChosen();
      actions.onNewFolderStarted();
      actions.onNewFolderRemoved();

      expect(inputs.calls, <String>['choose', 'start', 'drop']);
      inputs.controller.dispose();
    }
  });

  test('test_local_folder_actions_new_property_calling_one_calls_no_'
      'other', () {
    final Random random = seededRandom(105102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ReposFieldInputs inputs = ReposFieldInputs(random);
      final LocalFolderActions actions = inputs.folderActions;
      final int choice = random.nextInt(3);

      switch (choice) {
        case 0:
          actions.onFolderChosen();
        case 1:
          actions.onNewFolderStarted();
        default:
          actions.onNewFolderRemoved();
      }

      expect(inputs.calls, <String>[
        <String>['choose', 'start', 'drop'][choice],
      ]);
      inputs.controller.dispose();
    }
  });

  testWidgets('test_local_folder_actions_new_property_each_button_reaches_'
      'its_own_action', (WidgetTester tester) async {
    final Random random = seededRandom(105103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReposFieldInputs inputs = await pumpReposField(tester, random);
      if (!inputs.hasFolderActions) {
        expect(find.text(chooseFolderLabel), findsNothing);
        continue;
      }

      await tapVisible(tester, find.text(chooseFolderLabel));
      await tapVisible(tester, find.text(createNewFolderLabel));

      expect(inputs.calls, <String>['choose', 'start']);
    }
  });

  test('test_new_project_repos_field_new_property_keeps_every_input', () {
    final Random random = seededRandom(105104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ReposFieldInputs inputs = ReposFieldInputs(random);

      final NewProjectReposField field = inputs.buildField();

      expect(field.drafts, same(inputs.drafts));
      expect(field.newFolderPath, inputs.newFolderPath);
      expect(field.addressController, same(inputs.controller));
      expect(field.addressProblem, inputs.addressProblem);
      expect(field.localFolderActions == null, !inputs.hasFolderActions);
      inputs.controller.dispose();
    }
  });

  test('test_new_project_repos_field_new_property_keeps_the_callbacks', () {
    final Random random = seededRandom(105105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ReposFieldInputs inputs = ReposFieldInputs(random);
      final String text = randomText(random);

      final NewProjectReposField field = inputs.buildField();
      field.onAddressChanged(text);
      field.onAddressAdded();
      field.onRemoved(text);

      expect(inputs.calls, <String>[
        'changed $text',
        'added',
        'removed $text',
      ]);
      inputs.controller.dispose();
    }
  });

  testWidgets('test_new_project_repos_field_new_property_leaves_the_drafts_'
      'unchanged', (WidgetTester tester) async {
    final Random random = seededRandom(105106);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReposFieldInputs inputs = ReposFieldInputs(random);
      final List<String> before = listInputAddresses(inputs.drafts);

      await pumpReposFieldInputs(tester, random, inputs);

      expect(listInputAddresses(inputs.drafts), before);
      expect(inputs.calls, isEmpty);
    }
  });
}
