import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/projects/repository_entry_field.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';

final class _EntryEvents {
  final List<String> changedTexts = <String>[];
  int addCount = 0;

  void recordChange(String text) {
    changedTexts.add(text);
  }

  void recordAdd() {
    addCount += 1;
  }
}

RepositoryEntryField _buildField({
  required TextEditingController controller,
  required String? problem,
  required String placeholder,
  required _EntryEvents events,
  Key? key,
}) {
  return RepositoryEntryField(
    controller: controller,
    problem: problem,
    placeholder: placeholder,
    onChanged: events.recordChange,
    onAdded: events.recordAdd,
    key: key,
  );
}

Future<_EntryEvents> _pumpField(
  WidgetTester tester,
  Random random, {
  required String? problem,
  required String placeholder,
}) async {
  final _EntryEvents events = _EntryEvents();
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: _buildField(
      controller: TextEditingController(),
      problem: problem,
      placeholder: placeholder,
      events: events,
    ),
  );
  return events;
}

String _typedText(Random random) {
  return 'g${randomHostileText(random)}'.replaceAll('\n', ' ');
}

void main() {
  test('test_repository_entry_field_new_property_keeps_every_field', () {
    final Random random = seededRandom(1061701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TextEditingController controller = TextEditingController();
      final String? problem = random.nextBool() ? randomText(random) : null;
      final String placeholder = randomHostileText(random);
      final _EntryEvents events = _EntryEvents();

      final RepositoryEntryField field = _buildField(
        controller: controller,
        problem: problem,
        placeholder: placeholder,
        events: events,
      );

      expect(field.controller, same(controller));
      expect(field.problem, problem);
      expect(field.placeholder, placeholder);
    }
  });

  test('test_repository_entry_field_new_property_keeps_the_callbacks', () {
    final Random random = seededRandom(1061702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _EntryEvents events = _EntryEvents();
      final String text = randomHostileText(random);
      final RepositoryEntryField field = _buildField(
        controller: TextEditingController(),
        problem: null,
        placeholder: '',
        events: events,
      );

      field.onChanged(text);
      field.onAdded();

      expect(events.changedTexts, <String>[text]);
      expect(events.addCount, 1);
    }
  });

  test('test_repository_entry_field_new_property_keeps_the_key', () {
    final Random random = seededRandom(1061703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(1 << 30));
      final RepositoryEntryField field = _buildField(
        controller: TextEditingController(),
        problem: null,
        placeholder: '',
        events: _EntryEvents(),
        key: key,
      );

      expect(field.key, key);
    }
  });

  testWidgets('test_repository_entry_field_build_property_typing_reports_'
      'each_text', (WidgetTester tester) async {
    final Random random = seededRandom(1061704);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _EntryEvents events = await _pumpField(
        tester,
        random,
        problem: null,
        placeholder: 'github.com/acme/repo',
      );
      final List<String> typed = <String>[
        for (int index = 0; index < 1 + random.nextInt(3); index += 1)
          '${_typedText(random)}$index',
      ];

      for (final String text in typed) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump();
      }

      expect(events.changedTexts, typed);
      expect(events.addCount, 0);
    }
  });

  testWidgets('test_repository_entry_field_build_property_submit_and_'
      'button_each_add_once', (WidgetTester tester) async {
    final Random random = seededRandom(1061705);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _EntryEvents events = await _pumpField(
        tester,
        random,
        problem: null,
        placeholder: '',
      );
      await tester.enterText(find.byType(TextField), _typedText(random));

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.tap(find.text('Add repo'));
      await tester.pump();

      expect(events.addCount, 2);
    }
  });

  testWidgets('test_repository_entry_field_build_property_shows_problem_'
      'and_placeholder', (WidgetTester tester) async {
    final Random random = seededRandom(1061706);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = 'p${randomHostileText(random)}' * 6;
      final String placeholder = 'h${randomHostileText(random)}';
      await _pumpField(
        tester,
        random,
        problem: problem,
        placeholder: placeholder,
      );

      expect(find.text(problem), findsOneWidget);
      expect(find.text(placeholder), findsOneWidget);
      expect(find.text('Add repo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
