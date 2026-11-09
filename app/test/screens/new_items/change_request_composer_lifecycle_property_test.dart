import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/new_items/change_request_composer.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';

import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'change_request_composer_steps.dart';

Widget _twoComposers({
  required List<String> firstSent,
  required List<String> secondSent,
}) {
  return SingleChildScrollView(
    child: Column(
      children: <Widget>[
        ChangeRequestComposer(example: 'First', onSend: firstSent.add),
        ChangeRequestComposer(example: 'Second', onSend: secondSent.add),
      ],
    ),
  );
}

void main() {
  test('test_change_request_composer_constructor_property_never_trims_'
      'the_example', () {
    final Random random = seededRandom(1020904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String example =
          '${randomBlankNote(random)}${randomText(random)}'
          '${randomBlankNote(random)}';

      final ChangeRequestComposer composer = ChangeRequestComposer(
        example: example,
        onSend: <String>[].add,
      );

      expect(composer.example, example);
      expect(composer.example.length, example.length);
    }
  });

  testWidgets('test_change_request_composer_create_state_property_two_'
      'composers_keep_their_own_notes', (WidgetTester tester) async {
    final Random random = seededRandom(1020901);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> firstSent = <String>[];
      final List<String> secondSent = <String>[];
      final String firstNote = randomChangeNote(random);
      final String secondNote = randomChangeNote(random);
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _twoComposers(firstSent: firstSent, secondSent: secondSent),
      );

      await tester.enterText(find.byType(TextField).first, firstNote);
      await tester.enterText(find.byType(TextField).last, secondNote);
      await tester.tap(find.text(sendChangeLabel).last);
      await tester.pump();

      expect(firstSent, isEmpty);
      expect(secondSent, <String>[secondNote.trim()]);
      final TextField firstField = tester.widget(find.byType(TextField).first);
      expect(firstField.controller!.text, firstNote);
    }
  });

  testWidgets('test_change_request_composer_state_dispose_property_comes_'
      'back_empty', (WidgetTester tester) async {
    final Random random = seededRandom(1020902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> sent = <String>[];
      final Widget page = buildComposerPage(
        ChangeRequestComposer(example: 'Example', onSend: sent.add),
      );
      await pumpPageInRandomWindow(tester, random: random, page: page);
      await typeChangeNote(tester, randomChangeNote(random));

      await pumpPageInRandomWindow(tester, random: random, page: page);

      expect(tester.takeException(), isNull);
      expect(readShownChangeNote(tester), isEmpty);
      expect(sent, isEmpty);
    }
  });

  testWidgets('test_change_request_composer_state_dispose_property_focused_'
      'field_leaves_cleanly', (WidgetTester tester) async {
    final Random random = seededRandom(1020903);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildComposerPage(
          ChangeRequestComposer(example: 'Example', onSend: <String>[].add),
        ),
      );
      await tester.showKeyboard(find.byType(TextField));
      await typeChangeNote(tester, randomChangeNote(random));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.testTextInput.isVisible, isFalse);
    }
  });
}
