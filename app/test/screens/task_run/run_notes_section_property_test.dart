import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/task_run/run_notes_section.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'support/random_run_records.dart';

final RegExp _clockWording = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$');

Future<void> _pumpNotes(
  WidgetTester tester, {
  required Random random,
  required List<RunNote> notes,
}) async {
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SingleChildScrollView(child: RunNotesSection(notes: notes)),
  );
}

void main() {
  testWidgets('test_run_notes_section_build_property_one_row_per_note_in_'
      'order', (WidgetTester tester) async {
    final Random random = seededRandom(1141201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<RunNote> notes = randomRunNotes(random);

      await _pumpNotes(tester, random: random, notes: notes);

      expect(tester.takeException(), isNull);
      final List<ListRowMain> rows = tester
          .widgetList<ListRowMain>(find.byType(ListRowMain))
          .toList();
      expect(rows.length, notes.length);
      for (int index = 0; index < notes.length; index += 1) {
        expect(rows[index].title, notes[index].text);
      }
    }
  });

  testWidgets('test_run_notes_section_build_property_each_note_shows_its_'
      'clock_time', (WidgetTester tester) async {
    final Random random = seededRandom(1141202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<RunNote> notes = randomRunNotes(random);

      await _pumpNotes(tester, random: random, notes: notes);

      for (final RunNote note in notes) {
        final String clock = formatClockTime(note.at);
        expect(clock, matches(_clockWording));
        expect(find.text(clock), findsWidgets);
      }
    }
  });

  testWidgets('test_run_notes_section_build_property_titled_notes_like_'
      'the_design', (WidgetTester tester) async {
    final Random random = seededRandom(1141203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpNotes(tester, random: random, notes: randomRunNotes(random));

      final PageSection section = tester.widget(find.byType(PageSection));
      expect(section.title, 'Notes');
      expect(runNotesTitle, 'Notes');
    }
  });
}
