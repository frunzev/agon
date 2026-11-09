import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/task_form/task_form.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'task_form_scene.dart';

Future<void> _typeTexts(
  WidgetTester tester, {
  required Random random,
  required TaskFormValues values,
}) async {
  await enterFieldText(
    tester,
    label: taskFormTitleLabel,
    text: 'Typed ${randomText(random)}',
  );
  await enterFieldText(
    tester,
    label: taskFormDetailsLabel,
    text: randomText(random),
  );
  if (values.repeat.needsTime) {
    await enterFieldText(
      tester,
      label: taskFormTimeLabel,
      text: formatScheduleTime(randomScheduleTime(random)),
    );
  }
}

void main() {
  testWidgets('test_read_values_property_submits_the_typed_texts', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131401);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskFormValues initial = randomSavableValues(random, options);
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: initial,
        options: options,
        answerSubmit: answerAtOnce,
      );

      await _typeTexts(tester, random: random, values: initial);
      await tapTaskFormSubmit(tester);

      final TaskFormValues saved = scene.submitted.single;
      expect(saved.title, readFieldText(tester, taskFormTitleLabel));
      expect(saved.details, readFieldText(tester, taskFormDetailsLabel));
      if (initial.repeat.needsTime) {
        expect(saved.timeText, readFieldText(tester, taskFormTimeLabel));
      } else {
        expect(saved.timeText, initial.timeText);
      }
      expectSameChoices(saved, initial);
    }
  });

  testWidgets('test_read_values_property_untouched_form_keeps_every_field', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131402);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskFormValues initial = randomSavableValues(random, options);
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: initial,
        options: options,
        answerSubmit: answerAtOnce,
      );

      await tapTaskFormSubmit(tester);

      final TaskFormValues saved = scene.submitted.single;
      expectSameChoices(saved, initial);
      expect(saved.title, initial.title);
      expect(saved.details, initial.details);
      expect(saved.timeText, initial.timeText);
      expect(scene.reportedChanges, isEmpty);
    }
  });

  testWidgets('test_read_values_property_choices_keep_the_typed_texts', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131403);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskFormValues initial = randomSavableValues(random, options);
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: initial,
        options: options,
        answerSubmit: answerAtOnce,
      );
      await _typeTexts(tester, random: random, values: initial);
      final ProjectId chosenProject = pickOne(random, options.projects).value;

      final SelectField<ProjectId> projectField = tester.widget(
        find.byType(SelectField<ProjectId>),
      );
      projectField.onChanged(chosenProject);
      await tester.pump();

      final TaskFormValues reported = scene.reportedChanges.last;
      expect(reported.projectId, chosenProject);
      expect(reported.title, readFieldText(tester, taskFormTitleLabel));
      expect(reported.details, readFieldText(tester, taskFormDetailsLabel));
      await tapTaskFormSubmit(tester);
      expect(scene.submitted.single.title, reported.title);
      expect(scene.submitted.single.projectId, chosenProject);
    }
  });

  testWidgets('test_report_typed_values_property_each_edit_reports_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131404);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: randomSavableValues(random, options),
        options: options,
        answerSubmit: answerAtOnce,
      );
      final int editCount = 1 + random.nextInt(4);

      for (int edit = 0; edit < editCount; edit += 1) {
        await enterFieldText(
          tester,
          label: taskFormDetailsLabel,
          text: '$edit ${randomText(random)}',
        );
        final String shown = readFieldText(tester, taskFormDetailsLabel);
        expect(scene.reportedChanges, hasLength(edit + 1));
        expect(scene.reportedChanges.last.details, shown);
      }
    }
  });

  testWidgets('test_report_typed_values_property_keeps_every_other_field', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131405);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskFormValues initial = randomTaskFormValues(random, options);
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: initial,
        options: options,
        answerSubmit: answerAtOnce,
      );

      await enterFieldText(
        tester,
        label: taskFormDetailsLabel,
        text: randomText(random),
      );

      final TaskFormValues reported = scene.reportedChanges.single;
      expectSameChoices(reported, initial);
      expect(reported.title, initial.title);
      expect(reported.timeText, initial.timeText);
    }
  });

  testWidgets('test_report_typed_values_property_no_listener_is_fine', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131406);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskFormValues initial = randomSavableValues(random, options);
      final List<TaskFormValues> submitted = <TaskFormValues>[];
      await pumpScrollingPage(
        tester,
        random: random,
        page: TaskForm(
          initialValues: initial,
          options: options,
          repeatChoices: RepeatChoice.values,
          onRouteOpened: (_) {},
          actions: <FormAction<TaskFormValues>>[
            SubmitFormAction<TaskFormValues>(
              label: taskFormSubmitLabel,
              tone: ButtonTone.primary,
              icon: AppIconKind.check,
              onSubmitted: (TaskFormValues values) async =>
                  submitted.add(values),
            ),
          ],
        ),
      );

      await _typeTexts(tester, random: random, values: initial);
      final SelectField<TaskDoer> doerField = tester.widget(
        find.byType(SelectField<TaskDoer>),
      );
      doerField.onChanged(initial.doer);
      await tester.pump();
      await tapTaskFormSubmit(tester);

      expect(tester.takeException(), isNull);
      expect(
        submitted.single.title,
        readFieldText(tester, taskFormTitleLabel),
      );
    }
  });
}
