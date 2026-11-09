import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/projects/repository_entry.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/random_inputs.dart';
import 'project_repositories_editor_inputs.dart';
import 'project_screen_inputs.dart';
import 'repository_dialog_steps.dart';

String _randomTypedText(Random random, int round) {
  final List<String> choices = <String>[
    randomSpellingOf(random, randomCanonicalHostedAddress(random)),
    randomHostileText(random),
    randomFolderPath(random, round),
    '',
  ];
  return pickOne(random, choices);
}

FolderPicker? _randomPicker(Random random) {
  return random.nextBool() ? FixedFolderPicker(null) : null;
}

Future<RepositoryEntry> _readExpected({
  required String text,
  required FolderPicker? folderPicker,
  required ScriptedFolderDevices devices,
  required List<String> addedAddresses,
}) {
  return readTypedRepository(
    text: text,
    checkFolder: folderPicker == null ? null : devices.checkLocalFolder,
    listAddedAddresses: () => addedAddresses,
  );
}

void main() {
  test('test_keep_entry_property_editor_follows_the_shared_reading', () async {
    final Random random = seededRandom(54101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderPicker? folderPicker = _randomPicker(random);
      final EditorUnderTest editor = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: folderPicker,
      );
      final List<String> addressesBefore = editor.listAddresses();
      final String text = _randomTypedText(random, i);

      await editor.typeAndAdd(text);

      final RepositoryEntry expected = await _readExpected(
        text: text,
        folderPicker: folderPicker,
        devices: editor.devices,
        addedAddresses: addressesBefore,
      );
      switch (expected) {
        case RefusedRepository(:final String problem):
          expect(editor.editor.addressProblem, problem);
          expect(editor.listAddresses(), addressesBefore);
        case AcceptedRepository(:final RepositoryDraft repository):
          expect(editor.editor.addressProblem, isNull);
          expect(editor.listAddresses(), <String>[
            ...addressesBefore,
            repository.address,
          ]);
      }
    }
  });

  test('test_keep_entry_property_git_started_folders_are_listed', () async {
    final Random random = seededRandom(54102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = randomFolderPath(random, i);
      final bool isGitless = random.nextBool();
      final EditorUnderTest editor = EditorUnderTest(
        initialRepositories: const <RepositoryDraft>[],
        devices: ScriptedFolderDevices(
          gitlessPaths: isGitless ? <String>{path} : <String>{},
        ),
        folderPicker: FixedFolderPicker(null),
      );

      await editor.typeAndAdd(path);

      final String address = renderEditorFolderAddress(path);
      expect(editor.listAddresses(), <String>[address]);
      expect(editor.editor.gitStartedAddresses.contains(address), isGitless);
    }
  });

  test('test_keep_entry_property_disposed_editor_changes_nothing', () async {
    final Random random = seededRandom(54103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EditorUnderTest editor = buildEditorUnderTest(
        initialRepositories: randomInitialDrafts(random),
        folderPicker: FixedFolderPicker(null),
      );
      final Completer<void> held = Completer<void>();
      editor.devices.heldAnswer = held;
      final Future<void> adding = editor.typeAndAdd(
        randomFolderPath(random, i),
      );
      editor.editor.dispose();
      final int notificationsAtDispose = editor.notificationCount;

      held.complete();
      await adding;

      expect(editor.notificationCount, notificationsAtDispose);
    }
  });

  testWidgets('test_save_entry_property_dialog_follows_the_shared_reading', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54104);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderPicker? folderPicker = _randomPicker(random);
      final AddRepositoryDialogPage page = await _openDialog(
        tester,
        random: random,
        folderPicker: folderPicker,
        stored: _randomStoredProject(random),
      );
      final List<String> addressesBefore = page.listStoredAddresses();
      final String text = _randomTypedText(random, i);

      await typeAddressAndAdd(tester, text);

      final RepositoryEntry expected = await _readExpected(
        text: text,
        folderPicker: folderPicker,
        devices: ScriptedFolderDevices(gitlessPaths: <String>{}),
        addedAddresses: addressesBefore,
      );
      switch (expected) {
        case RefusedRepository(:final String problem):
          expect(find.text(problem), findsOneWidget, reason: text);
          expect(page.listStoredAddresses(), addressesBefore);
          expect(page.closing.isClosed, isFalse);
        case AcceptedRepository(:final RepositoryDraft repository):
          expect(page.listStoredAddresses(), <String>[
            ...addressesBefore,
            repository.address,
          ]);
          expect(page.closing.isClosed, isTrue);
      }
    }
  });

  testWidgets('test_save_entry_property_added_repo_is_refused_in_place', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54105);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AddRepositoryDialogPage page = await _openDialog(
        tester,
        random: random,
        folderPicker: _randomPicker(random),
        stored: _randomStoredProject(random),
      );
      final String added = randomCanonicalHostedAddress(random);
      await typeAddressAndAdd(tester, added);
      final AddRepositoryDialogPage again = await _openDialog(
        tester,
        random: random,
        folderPicker: _randomPicker(random),
        stored: _reloadStoredProject(page.stored),
      );
      final List<String> addressesBefore = again.listStoredAddresses();

      await typeAddressAndAdd(tester, randomSpellingOf(random, added));

      expect(find.text(alreadyAddedProblem), findsOneWidget);
      expect(again.listStoredAddresses(), addressesBefore);
      expect(again.closing.isClosed, isFalse);
    }
  });

  testWidgets('test_save_entry_property_closed_dialog_saves_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54106);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AddRepositoryDialogPage page = await _openDialog(
        tester,
        random: random,
        folderPicker: FixedFolderPicker(null),
        stored: _randomStoredProject(random),
      );
      final List<String> addressesBefore = page.listStoredAddresses();
      final Completer<void> held = Completer<void>();
      page.devices.heldAnswer = held;
      await typeAddressAndAdd(tester, randomFolderPath(random, i));

      await tapDialogButton(tester, cancelLabel);
      held.complete();
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(page.listStoredAddresses(), addressesBefore);
      expect(page.closing.isClosed, isTrue);
    }
  });
}

Future<AddRepositoryDialogPage> _openDialog(
  WidgetTester tester, {
  required Random random,
  required FolderPicker? folderPicker,
  required StoredProject stored,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  return openAddRepositoryDialog(
    tester,
    random: random,
    stored: stored,
    folderPicker: folderPicker,
  );
}

StoredProject _randomStoredProject(Random random) {
  return buildStoredProject(random, randomScreenRepositories(random));
}

StoredProject _reloadStoredProject(StoredProject stored) {
  return (
    project: stored.repository.findProject(stored.project.id),
    repository: stored.repository,
  );
}
