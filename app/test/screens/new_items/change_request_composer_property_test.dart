import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/new_items/change_request_composer.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'change_request_composer_steps.dart';

void main() {
  test('test_change_request_composer_constructor_property_keeps_example_'
      'and_callback', () {
    final Random random = seededRandom(1020801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String example = randomHostileText(random);
      final List<String> sent = <String>[];

      final ChangeRequestComposer composer = ChangeRequestComposer(
        example: example,
        onSend: sent.add,
      );
      composer.onSend(example);

      expect(composer.example, example);
      expect(sent, <String>[example]);
    }
  });

  test('test_change_request_composer_constructor_property_no_key_unless_'
      'given', () {
    final Random random = seededRandom(1020802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(99));
      final List<String> sent = <String>[];

      expect(ChangeRequestComposer(example: '', onSend: sent.add).key, isNull);
      expect(
        ChangeRequestComposer(example: '', onSend: sent.add, key: key).key,
        key,
      );
    }
  });

  test('test_change_request_composer_create_state_property_every_call_is_'
      'fresh', () {
    final ChangeRequestComposer composer = ChangeRequestComposer(
      example: 'For example',
      onSend: <String>[].add,
    );

    final State<ChangeRequestComposer> first = composer.createState();
    final State<ChangeRequestComposer> second = composer.createState();

    expect(identical(first, second), isFalse);
    expect(first.mounted, isFalse);
  });

  testWidgets('test_change_request_composer_create_state_property_new_'
      'composers_start_empty', (WidgetTester tester) async {
    final Random random = seededRandom(1020803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> sent = <String>[];
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildComposerPage(
          ChangeRequestComposer(
            key: ValueKey<int>(i),
            example: 'Example $i',
            onSend: sent.add,
          ),
        ),
      );

      expect(readShownChangeNote(tester), isEmpty);
      await typeChangeNote(tester, randomChangeNote(random));
      expect(sent, isEmpty);
    }
  });

  testWidgets('test_change_request_composer_state_dispose_property_leaving_'
      'with_a_note_is_clean', (WidgetTester tester) async {
    final Random random = seededRandom(1020804);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildComposerPage(
          ChangeRequestComposer(example: 'Example', onSend: <String>[].add),
        ),
      );
      await typeChangeNote(tester, randomChangeNote(random));

      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isNull);
      expect(find.byType(ChangeRequestComposer), findsNothing);
    }
  });

  testWidgets('test_change_request_composer_state_build_property_shows_'
      'example_label_and_send', (WidgetTester tester) async {
    final Random random = seededRandom(1020805);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String example = 'For example: ${randomHostileText(random)}';
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildComposerPage(
          ChangeRequestComposer(example: example, onSend: <String>[].add),
        ),
      );

      final TextField field = tester.widget(find.byType(TextField));
      expect(tester.takeException(), isNull);
      expect(field.decoration!.hintText, example);
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(changeFieldLabel))),
        findsOneWidget,
      );
      expect(find.text(sendChangeLabel), findsOneWidget);
      expect(
        tester.getRect(find.text(sendChangeLabel)).left,
        greaterThan(tester.getRect(find.byType(TextField)).left),
      );
    }
  });

  testWidgets('test_change_request_composer_state_build_property_rebuild_'
      'keeps_the_note', (WidgetTester tester) async {
    final Random random = seededRandom(1020806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String note = randomChangeNote(random);
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildComposerPage(
          ChangeRequestComposer(example: 'First', onSend: <String>[].add),
        ),
      );
      await typeChangeNote(tester, note);

      await tester.pumpWidget(
        tester.widget<MaterialApp>(find.byType(MaterialApp)),
      );
      await tester.pump();

      expect(readShownChangeNote(tester), note);
    }
  });

  testWidgets('test_change_request_composer_send_property_sends_trimmed_'
      'once_and_clears', (WidgetTester tester) async {
    final Random random = seededRandom(1020807);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> sent = <String>[];
      final String note = randomChangeNote(random);
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildComposerPage(
          ChangeRequestComposer(example: 'Example', onSend: sent.add),
        ),
      );
      await typeChangeNote(tester, note);

      await tapShownText(tester, sendChangeLabel);
      await tapShownText(tester, sendChangeLabel);

      expect(sent, <String>[note.trim()]);
      expect(readShownChangeNote(tester), isEmpty);
    }
  });

  testWidgets('test_change_request_composer_send_property_blank_notes_stay_'
      'unsent', (WidgetTester tester) async {
    final Random random = seededRandom(1020808);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> sent = <String>[];
      final String blank = randomBlankNote(random);
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildComposerPage(
          ChangeRequestComposer(example: 'Example', onSend: sent.add),
        ),
      );
      await typeChangeNote(tester, blank);

      await tapShownText(tester, sendChangeLabel);

      expect(sent, isEmpty);
      expect(readShownChangeNote(tester), blank);
    }
  });

  testWidgets('test_change_request_composer_send_property_notes_arrive_in_'
      'order', (WidgetTester tester) async {
    final Random random = seededRandom(1020809);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> sent = <String>[];
      final List<String> expected = <String>[];
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildComposerPage(
          ChangeRequestComposer(example: 'Example', onSend: sent.add),
        ),
      );

      for (int round = 0; round < random.nextInt(5); round += 1) {
        final String note = random.nextBool()
            ? randomChangeNote(random)
            : randomBlankNote(random);
        await typeChangeNote(tester, note);
        await tapShownText(tester, sendChangeLabel);
        if (note.trim().isNotEmpty) {
          expected.add(note.trim());
        }
      }

      expect(sent, expected);
    }
  });
}
