import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'repository_dialog_steps.dart';

void main() {
  testWidgets('test_add_repository_dialog_dispose_property_cancel_is_clean', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1061113);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRandomAddRepositoryDialog(tester, random);
      await typeAddressAndAdd(tester, randomHostileText(random));

      await tapDialogButton(tester, cancelLabel);

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNothing);
    }
  });

  testWidgets('test_add_repository_dialog_dispose_property_reopening_'
      'forgets_the_text', (WidgetTester tester) async {
    final Random random = seededRandom(1061114);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StoredProject stored = buildStoredProject(random, <Repository>[]);
      await tester.pumpWidget(const SizedBox.shrink());
      await openAddRepositoryDialog(
        tester,
        random: random,
        stored: stored,
        folderPicker: null,
      );
      await typeAddressAndAdd(tester, 'not an address ${random.nextInt(9)}');
      await tapDialogButton(tester, cancelLabel);

      await openAddRepositoryDialog(
        tester,
        random: random,
        stored: stored,
        folderPicker: null,
      );
      final TextField field = tester.widget(findFieldInput(addressFieldLabel));

      expect(field.controller!.text, isEmpty);
      expect(field.decoration!.errorText, isNull);
    }
  });

  testWidgets('test_add_repository_dialog_dispose_property_tapping_outside_'
      'closes', (WidgetTester tester) async {
    final Random random = seededRandom(1061115);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AddRepositoryDialogPage page = await openRandomAddRepositoryDialog(
        tester,
        random,
      );
      final List<String> before = page.listStoredAddresses();

      await tester.tapAt(const Offset(2, 2));
      await pumpFrames(tester);

      expect(page.closing.isClosed, isTrue);
      expect(page.listStoredAddresses(), before);
      expect(tester.takeException(), isNull);
    }
  });
}
