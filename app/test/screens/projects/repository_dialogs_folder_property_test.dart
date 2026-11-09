import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';

import '../../support/app_harness.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/random_inputs.dart';
import 'project_repositories_editor_inputs.dart';
import 'project_screen_inputs.dart';
import 'repository_dialog_steps.dart';

const String _chooseFolderLabel = 'Choose folder…';

Future<AddRepositoryDialogPage> _openWithPicker(
  WidgetTester tester,
  Random random,
  FolderPicker picker,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  return openAddRepositoryDialog(
    tester,
    random: random,
    stored: buildStoredProject(random, randomScreenRepositories(random)),
    folderPicker: picker,
  );
}

String _randomPath(Random random) {
  return randomFolderPath(random, 100 + random.nextInt(900));
}

void main() {
  testWidgets('test_choose_folder_property_dialog_picked_folder_joins_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1061401);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String path = _randomPath(random);
      final FixedFolderPicker picker = FixedFolderPicker(path);
      final AddRepositoryDialogPage page = await _openWithPicker(
        tester,
        random,
        picker,
      );
      final List<String> before = page.listStoredAddresses();

      await tapDialogButton(tester, _chooseFolderLabel);

      final String address = renderEditorFolderAddress(path);
      expect(page.listStoredAddresses(), <String>[...before, address]);
      expect(picker.chooseCount, 1);
      expect(page.closing.isClosed, isTrue);
    }
  });

  testWidgets('test_choose_folder_property_dialog_cancelled_pick_changes_'
      'nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1061402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AddRepositoryDialogPage page = await _openWithPicker(
        tester,
        random,
        FixedFolderPicker(null),
      );
      final List<String> before = page.listStoredAddresses();

      await tapDialogButton(tester, _chooseFolderLabel);

      expect(page.listStoredAddresses(), before);
      expect(page.devices.checkedPaths, isEmpty);
      expect(page.closing.isClosed, isFalse);
    }
  });

  testWidgets('test_choose_folder_property_dialog_closed_before_the_pick_'
      'adds_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1061403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldFolderPicker picker = HeldFolderPicker();
      final AddRepositoryDialogPage page = await _openWithPicker(
        tester,
        random,
        picker,
      );
      final List<String> before = page.listStoredAddresses();
      await tapDialogButton(tester, _chooseFolderLabel);
      await tapDialogButton(tester, cancelLabel);

      picker.chosenPath.complete(_randomPath(random));
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(page.devices.checkedPaths, isEmpty);
      expect(page.listStoredAddresses(), before);
    }
  });

  testWidgets('test_add_folder_property_dialog_refusals_show_under_the_'
      'field', (WidgetTester tester) async {
    final Random random = seededRandom(1061404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AddRepositoryDialogPage page = await _openWithPicker(
        tester,
        random,
        FixedFolderPicker(_randomPath(random)),
      );
      final List<String> before = page.listStoredAddresses();
      final String reason = 'no git here ${random.nextInt(999)}';
      page.devices.refusal = PeopleFacingRefusal(reason);

      await tapDialogButton(tester, _chooseFolderLabel);

      expect(find.text(reason), findsOneWidget);
      expect(page.listStoredAddresses(), before);
      expect(page.closing.isClosed, isFalse);
    }
  });

  testWidgets('test_add_folder_property_dialog_same_folder_twice_is_'
      'refused', (WidgetTester tester) async {
    final Random random = seededRandom(1061405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String path = _randomPath(random);
      final List<Repository> repositories = <Repository>[
        ...randomScreenRepositories(random),
        Repository(
          address: renderEditorFolderAddress(path),
          defaultBranch: 'main',
          agentAccess: pickOne(random, AgentAccess.values),
        ),
      ];
      await tester.pumpWidget(const SizedBox.shrink());
      final AddRepositoryDialogPage page = await openAddRepositoryDialog(
        tester,
        random: random,
        stored: buildStoredProject(random, repositories),
        folderPicker: FixedFolderPicker(path),
      );

      final bool typesThePath = random.nextBool();
      if (typesThePath) {
        await typeAddressAndAdd(tester, path);
      } else {
        await tapDialogButton(tester, _chooseFolderLabel);
      }

      expect(find.text(alreadyAddedProblem), findsOneWidget);
      expect(page.listStoredAddresses(), hasLength(repositories.length));
    }
  });

  testWidgets('test_add_folder_property_dialog_closed_before_the_check_'
      'adds_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1061406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AddRepositoryDialogPage page = await _openWithPicker(
        tester,
        random,
        FixedFolderPicker(null),
      );
      final List<String> before = page.listStoredAddresses();
      final Completer<void> heldCheck = Completer<void>();
      page.devices.heldAnswer = heldCheck;
      await typeAddressAndAdd(tester, _randomPath(random));
      await tapDialogButton(tester, cancelLabel);

      heldCheck.complete();
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(page.devices.checkedPaths, hasLength(1));
      expect(page.listStoredAddresses(), before);
    }
  });
}
