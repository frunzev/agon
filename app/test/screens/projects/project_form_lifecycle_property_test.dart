import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/projects/folder_choice.dart';
import 'package:agent_orchestration/screens/projects/new_project_repos_field.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'project_form_pumps.dart';
import 'project_form_steps.dart';

const String _badAddressProblem = 'Paste an address like github.com/acme/repo';

void main() {
  testWidgets('test_project_form_init_state_property_added_repos_show_at_'
      'once', (WidgetTester tester) async {
    final Random random = seededRandom(105307);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftedProject initial = randomInitialProject(random);
      await pumpProjectForm(
        tester,
        random,
        buildProjectForm(
          initialProject: initial,
          folderPicker: null,
          recorder: FormRecorder(),
          key: null,
        ),
      );
      final TypedRepository added = randomTypedGitHubRepository(random);

      await addTypedRepository(tester, added.typed);

      expect(readRepositoryRowTitles(tester), <String>[
        ...describeExpectedRowTitles(initial),
        describeRepositoryPath(added.canonical),
      ]);
    }
  });

  testWidgets('test_project_form_init_state_property_removed_repos_leave_'
      'at_once', (WidgetTester tester) async {
    final Random random = seededRandom(105308);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftedProject initial = randomInitialProject(random);
      await pumpProjectForm(
        tester,
        random,
        buildProjectForm(
          initialProject: initial,
          folderPicker: null,
          recorder: FormRecorder(),
          key: null,
        ),
      );
      final int removed = random.nextInt(initial.repositories.length);

      await tapVisible(tester, find.text('Remove').at(removed));
      await tester.pump();

      final List<String> expected = describeExpectedRowTitles(initial)
        ..removeAt(removed);
      expect(readRepositoryRowTitles(tester), expected);
    }
  });

  testWidgets('test_project_form_init_state_property_address_problems_show_'
      'at_once', (WidgetTester tester) async {
    final Random random = seededRandom(105309);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpProjectForm(
        tester,
        random,
        buildRandomProjectForm(random, FormRecorder()),
      );

      await addTypedRepository(tester, 'not an address ${randomText(random)}');

      expect(find.text(_badAddressProblem), findsOneWidget);
    }
  });

  testWidgets('test_project_form_dispose_property_a_pending_folder_pick_'
      'raises_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(105310);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldFolderPicker picker = HeldFolderPicker();
      await pumpProjectForm(
        tester,
        random,
        buildProjectForm(
          initialProject: randomInitialProject(random),
          folderPicker: picker,
          recorder: FormRecorder(),
          key: null,
        ),
      );
      await tapVisible(
        tester,
        find.text(
          pickOne(random, <String>[chooseFolderLabel, createNewFolderLabel]),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      picker.chosenFolder.complete('$folderRoot/${randomFolderName(random)}');
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_project_form_dispose_property_a_new_form_starts_'
      'fresh', (WidgetTester tester) async {
    final Random random = seededRandom(105311);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftedProject first = randomInitialProject(random);
      final DraftedProject second = randomInitialProject(random);
      final FormRecorder recorder = FormRecorder();
      await pumpProjectForm(
        tester,
        random,
        buildProjectForm(
          initialProject: first,
          folderPicker: null,
          recorder: recorder,
          key: const ValueKey<String>('first'),
        ),
      );
      await enterSettledText(tester, label: nameLabel, text: 'typed');

      await pumpProjectForm(
        tester,
        random,
        buildProjectForm(
          initialProject: second,
          folderPicker: null,
          recorder: recorder,
          key: const ValueKey<String>('second'),
        ),
      );

      expect(findFieldText(nameLabel, second.name), findsOneWidget);
      expect(
        readRepositoryRowTitles(tester),
        describeExpectedRowTitles(second),
      );
    }
  });

  testWidgets('test_project_form_dispose_property_a_slow_save_finishing_'
      'later_raises_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(105312);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormRecorder recorder = FormRecorder();
      final Completer<void> slowSave = Completer<void>();
      recorder.heldSubmission = slowSave;
      if (random.nextBool()) {
        recorder.plannedProblem = PeopleFacingRefusal('refused');
      }
      await pumpProjectForm(
        tester,
        random,
        buildRandomProjectForm(random, recorder),
      );
      await tapVisible(tester, find.text(saveLabel));
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      slowSave.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(recorder.submitted, hasLength(1));
    }
  });
}
