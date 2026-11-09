import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/projects.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'project_repositories_editor_inputs.dart';
import 'project_screen_inputs.dart';
import 'repository_dialog_steps.dart';

const String _computerHint =
    'Paste a GitHub address or choose a folder on this computer.';
const String _phoneHint = 'Paste a GitHub address.';
const String _chooseFolderLabel = 'Choose folder…';
const List<String> _accessTitles = <String>['Read only', 'Read and push'];

AddRepositoryDialog _buildDialog(Random random, {Key? key}) {
  final StoredProject stored = buildStoredProject(
    random,
    randomScreenRepositories(random),
  );
  return AddRepositoryDialog(
    project: stored.project,
    projectRepository: stored.repository,
    deviceRepository: ScriptedFolderDevices(gitlessPaths: <String>{}),
    folderPicker: randomFolderPicker(random),
    key: key,
  );
}

String _titleOf(AddRepositoryDialogPage page) {
  return 'Add repo to ${page.stored.project.name}';
}

void main() {
  testWidgets('test_show_add_repository_dialog_property_titles_the_project', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1061101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AddRepositoryDialogPage page = await openRandomAddRepositoryDialog(
        tester,
        random,
      );

      expect(find.text(_titleOf(page)), findsOneWidget);
      expect(find.byType(AddRepositoryDialog), findsOneWidget);
      expect(page.closing.isClosed, isFalse);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_show_add_repository_dialog_property_cancel_changes_'
      'nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1061102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AddRepositoryDialogPage page = await openRandomAddRepositoryDialog(
        tester,
        random,
      );
      final List<String> before = page.listStoredAddresses();
      await enterFieldText(
        tester,
        label: addressFieldLabel,
        text: randomCanonicalHostedAddress(random),
      );

      await tapDialogButton(tester, cancelLabel);

      expect(page.closing.isClosed, isTrue);
      expect(find.byType(AddRepositoryDialog), findsNothing);
      expect(page.listStoredAddresses(), before);
    }
  });

  testWidgets('test_show_add_repository_dialog_property_completes_after_'
      'adding', (WidgetTester tester) async {
    final Random random = seededRandom(1061103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AddRepositoryDialogPage page = await openRandomAddRepositoryDialog(
        tester,
        random,
      );
      final String canonical = '${randomCanonicalHostedAddress(random)}-new';

      await typeAddressAndAdd(tester, randomSpellingOf(random, canonical));

      expect(page.closing.isClosed, isTrue);
      expect(page.listStoredAddresses().last, canonical);
    }
  });

  test('test_add_repository_dialog_new_property_keeps_every_dependency', () {
    final Random random = seededRandom(1061104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final StoredProject stored = buildStoredProject(random, <Repository>[]);
      final ScriptedFolderDevices devices = ScriptedFolderDevices(
        gitlessPaths: <String>{},
      );
      final FolderPicker? picker = randomFolderPicker(random);

      final AddRepositoryDialog dialog = AddRepositoryDialog(
        project: stored.project,
        projectRepository: stored.repository,
        deviceRepository: devices,
        folderPicker: picker,
      );

      expect(dialog.project, same(stored.project));
      expect(dialog.projectRepository, same(stored.repository));
      expect(dialog.deviceRepository, same(devices));
      expect(dialog.folderPicker, same(picker));
    }
  });

  test('test_add_repository_dialog_new_property_keeps_the_key', () {
    final Random random = seededRandom(1061105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomHostileText(random));

      expect(_buildDialog(random, key: key).key, key);
    }
  });

  test('test_add_repository_dialog_new_property_no_key_by_default', () {
    final Random random = seededRandom(1061106);

    for (int i = 0; i < propertyIterations; i += 1) {
      expect(_buildDialog(random).key, isNull);
    }
  });

  test('test_add_repository_dialog_create_state_property_fresh_states', () {
    final Random random = seededRandom(1061107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AddRepositoryDialog dialog = _buildDialog(random);

      final State<AddRepositoryDialog> first = dialog.createState();
      final State<AddRepositoryDialog> second = dialog.createState();

      expect(identical(first, second), isFalse);
      expect(first.mounted, isFalse);
    }
  });

  testWidgets('test_add_repository_dialog_create_state_property_serves_'
      'its_widget', (WidgetTester tester) async {
    final Random random = seededRandom(1061108);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRandomAddRepositoryDialog(tester, random);
      final Finder dialog = find.byType(AddRepositoryDialog);

      final State<AddRepositoryDialog> state = tester.state(dialog);

      expect(state.mounted, isTrue);
      expect(state.widget, same(tester.widget(dialog)));
    }
  });

  testWidgets('test_add_repository_dialog_create_state_property_each_'
      'dialog_starts_empty', (WidgetTester tester) async {
    final Random random = seededRandom(1061109);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRandomAddRepositoryDialog(tester, random);

      final TextField field = tester.widget(findFieldInput(addressFieldLabel));

      expect(field.controller!.text, isEmpty);
      expect(field.decoration!.errorText, isNull);
    }
  });

  testWidgets('test_add_repository_dialog_build_property_hint_follows_'
      'the_picker', (WidgetTester tester) async {
    final Random random = seededRandom(1061110);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderPicker? picker = randomFolderPicker(random);
      await tester.pumpWidget(const SizedBox.shrink());
      await openAddRepositoryDialog(
        tester,
        random: random,
        stored: buildStoredProject(random, randomScreenRepositories(random)),
        folderPicker: picker,
      );
      final bool canPick = picker != null;

      expect(
        find.text(_computerHint),
        canPick ? findsOneWidget : findsNothing,
      );
      expect(find.text(_phoneHint), canPick ? findsNothing : findsOneWidget);
      expect(
        find.text(_chooseFolderLabel),
        canPick ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_add_repository_dialog_build_property_renders_at_any_'
      'size', (WidgetTester tester) async {
    final Random random = seededRandom(1061111);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRandomAddRepositoryDialog(tester, random);
      await typeAddressAndAdd(tester, randomHostileText(random));

      expect(tester.takeException(), isNull);
      expect(find.text(addRepositoryLabel), findsOneWidget);
      expect(find.text(cancelLabel), findsOneWidget);
    }
  });

  testWidgets('test_add_repository_dialog_build_property_offers_every_'
      'agent_access', (WidgetTester tester) async {
    final Random random = seededRandom(1061112);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRandomAddRepositoryDialog(tester, random);

      for (final String title in _accessTitles) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('What agents can do'), findsOneWidget);
    }
  });
}
