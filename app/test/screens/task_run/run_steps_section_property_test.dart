import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/screens/shared/status_labels.dart';
import 'package:agent_orchestration/screens/task_run/run_notes_section.dart';
import 'package:agent_orchestration/screens/task_run/run_steps_section.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/random_inputs.dart';
import 'support/run_steps_section_scenes.dart';

const String _stepsTitle = 'Steps';
const Set<StepStatus> _currentStatuses = <StepStatus>{
  StepStatus.running,
  StepStatus.waitingForApproval,
  StepStatus.waitingForPerson,
  StepStatus.failed,
};

int? _findExpectedEmphasizedIndex(Run run) {
  for (int index = 0; index < run.steps.length; index += 1) {
    if (_currentStatuses.contains(run.steps[index].status)) {
      return index;
    }
  }
  return null;
}

void main() {
  test('test_run_steps_section_property_keeps_every_field', () {
    final Random random = seededRandom(115101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SectionInputs inputs = randomSectionInputs(random);
      final RunStepsSection section = buildSection(inputs, key: UniqueKey());

      expect(identical(section.run, inputs.run), isTrue);
      expect(identical(section.task, inputs.task), isTrue);
      expect(identical(section.workflow, inputs.workflow), isTrue);
      expect(identical(section.deviceNames, galleryDeviceNames), isTrue);
      expect(section.now, galleryNow);
    }
  });

  test('test_run_steps_section_property_keeps_the_given_key', () {
    final Random random = seededRandom(115102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SectionInputs inputs = randomSectionInputs(random);
      final Key key = ValueKey<String>(randomText(random));
      final RunStepsSection section = RunStepsSection(
        run: inputs.run,
        task: inputs.task,
        workflow: inputs.workflow,
        deviceNames: galleryDeviceNames,
        now: galleryNow,
        key: key,
      );

      expect(section.key, key);
    }
  });

  test('test_run_steps_section_property_constructing_reads_no_steps', () {
    final Random random = seededRandom(115103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SectionInputs inputs = randomSectionInputs(random);
      final Run stepless = inputs.run.withProgress(
        nextStatus: inputs.run.status,
        nextSteps: const <RunStep>[],
        nextFinishedAt: inputs.run.finishedAt,
      );

      expect(
        () => buildSection((
          run: stepless,
          task: inputs.task,
          workflow: inputs.workflow,
        ), key: UniqueKey()),
        returnsNormally,
      );
    }
  });

  testWidgets('test_run_steps_section_build_property_rows_follow_run_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(115104);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SectionInputs inputs = randomSectionInputs(random);
      await pumpSection(
        tester,
        random: random,
        section: buildSection(inputs, key: UniqueKey()),
      );

      final List<String> shownTitles = <String>[
        for (final ListRowData row in readStepRows(tester))
          readRowMain(row).title,
      ];
      final List<String> stepNames = <String>[
        for (final RunStep step in inputs.run.steps) step.name,
      ];
      expect(shownTitles, stepNames);
      expect(find.text(_stepsTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_run_steps_section_build_property_labels_match_status', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(115105);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SectionInputs inputs = randomSectionInputs(random);
      await pumpSection(
        tester,
        random: random,
        section: buildSection(inputs, key: UniqueKey()),
      );

      final List<ListRowData> rows = readStepRows(tester);
      expect(rows, hasLength(inputs.run.steps.length));
      for (int index = 0; index < rows.length; index += 1) {
        final StatusLabel label = rows[index].end! as StatusLabel;
        final StepStatus status = inputs.run.steps[index].status;
        expect(label.text, buildStepStatusLabel(status).text);
        expect(label.tone, buildStepStatusLabel(status).tone);
      }
    }
  });

  testWidgets(
    'test_run_steps_section_build_property_highlights_current_only',
    (WidgetTester tester) async {
      final Random random = seededRandom(115106);

      for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
        final SectionInputs inputs = randomSectionInputs(random);
        await pumpSection(
          tester,
          random: random,
          section: buildSection(inputs, key: UniqueKey()),
        );

        final List<ListRowData> rows = readStepRows(tester);
        final int? expected = _findExpectedEmphasizedIndex(inputs.run);
        for (int index = 0; index < rows.length; index += 1) {
          final RowEmphasis emphasis = index == expected
              ? RowEmphasis.current
              : RowEmphasis.normal;
          expect(rows[index].emphasis, emphasis, reason: 'row $index');
        }
      }
    },
  );

  testWidgets('test_run_steps_section_build_property_notes_only_when_kept', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(115107);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SectionInputs inputs = randomSectionInputs(random);
      await pumpSection(
        tester,
        random: random,
        section: buildSection(inputs, key: UniqueKey()),
      );

      final List<RunNote> notes = inputs.run.notes;
      expect(
        find.byType(RunNotesSection),
        findsNWidgets(notes.isEmpty ? 0 : 1),
      );
      for (final RunNote note in notes) {
        expect(find.text(note.text), findsOneWidget);
      }
    }
  });

  testWidgets('test_run_steps_section_build_property_fits_at_random_widths', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(115108);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SectionInputs inputs = randomSectionInputs(random);
      await pumpSection(
        tester,
        random: random,
        section: buildSection(inputs, key: UniqueKey()),
      );

      expect(tester.takeException(), isNull);
      for (final RunStep step in inputs.run.steps) {
        expect(find.text(step.name), findsOneWidget);
      }
    }
  });
}
