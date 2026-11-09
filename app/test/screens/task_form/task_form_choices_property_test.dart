import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import '../../support/random_inputs.dart';
import 'task_form_scene.dart';

enum _ChoiceKind { project, doer, runner, place, repeat }

Future<T> _chooseEntry<T>(
  WidgetTester tester, {
  required Random random,
  required bool Function(T value) isAllowed,
}) async {
  final SelectField<T> field = tester.widget(find.byType(SelectField<T>));
  final List<T> allowed = <T>[
    for (final T value in listOptionValues(field.entries))
      if (isAllowed(value)) value,
  ];
  final T chosen = pickOne(random, allowed);
  field.onChanged(chosen);
  await tester.pump();
  return chosen;
}

bool _allowEvery(Object? _) => true;

Future<TaskFormValues> _makeRandomChoice(
  WidgetTester tester, {
  required Random random,
  required TaskFormOptions options,
  required TaskFormValues expected,
}) async {
  switch (pickOne(random, _ChoiceKind.values)) {
    case _ChoiceKind.project:
      final ProjectId projectId = await _chooseEntry<ProjectId>(
        tester,
        random: random,
        isAllowed: _allowEvery,
      );
      return expected.copyWith(projectId: projectId);
    case _ChoiceKind.doer:
      final TaskDoer doer = await _chooseEntry<TaskDoer>(
        tester,
        random: random,
        isAllowed: (TaskDoer doer) => options.findWorkflowToSign(doer) == null,
      );
      return expected.copyWith(doer: doer);
    case _ChoiceKind.runner:
      final RunnerTarget target = await _chooseEntry<RunnerTarget>(
        tester,
        random: random,
        isAllowed: _allowEvery,
      );
      return expected.copyWith(runsOn: target);
    case _ChoiceKind.place:
      final AgentPlace place = await _chooseEntry<AgentPlace>(
        tester,
        random: random,
        isAllowed: _allowEvery,
      );
      return expected.copyWith(agentPlace: place);
    case _ChoiceKind.repeat:
      final RepeatChoice repeat = await _chooseEntry<RepeatChoice>(
        tester,
        random: random,
        isAllowed: _allowEvery,
      );
      return expected.copyWith(repeat: repeat);
  }
}

void _expectShownChoices(WidgetTester tester, TaskFormValues expected) {
  final SelectField<ProjectId> project = tester.widget(
    find.byType(SelectField<ProjectId>),
  );
  final SelectField<TaskDoer> doer = tester.widget(
    find.byType(SelectField<TaskDoer>),
  );
  final SelectField<RunnerTarget> runner = tester.widget(
    find.byType(SelectField<RunnerTarget>),
  );
  final SelectField<AgentPlace> place = tester.widget(
    find.byType(SelectField<AgentPlace>),
  );
  final SelectField<RepeatChoice> repeat = tester.widget(
    find.byType(SelectField<RepeatChoice>),
  );
  expect(project.value, expected.projectId);
  expect(doer.value, expected.doer);
  expect(runner.value, expected.runsOn);
  expect(place.value, expected.agentPlace);
  expect(repeat.value, expected.repeat);
}

void main() {
  testWidgets('test_update_values_property_reports_each_choice_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131601);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      TaskFormValues expected = randomSavableValues(random, options);
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: expected,
        options: options,
        answerSubmit: answerAtOnce,
      );
      final int choiceCount = 1 + random.nextInt(6);

      for (int choice = 0; choice < choiceCount; choice += 1) {
        expected = await _makeRandomChoice(
          tester,
          random: random,
          options: options,
          expected: expected,
        );
        expect(scene.reportedChanges, hasLength(choice + 1));
        expectSameChoices(scene.reportedChanges.last, expected);
      }
    }
  });

  testWidgets('test_update_values_property_shown_choices_follow', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131602);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      TaskFormValues expected = randomSavableValues(random, options);
      await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: expected,
        options: options,
        answerSubmit: answerAtOnce,
      );
      _expectShownChoices(tester, expected);
      final int choiceCount = 1 + random.nextInt(6);

      for (int choice = 0; choice < choiceCount; choice += 1) {
        expected = await _makeRandomChoice(
          tester,
          random: random,
          options: options,
          expected: expected,
        );
        _expectShownChoices(tester, expected);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('test_update_values_property_last_choices_are_submitted', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131603);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      TaskFormValues expected = randomSavableValues(random, options);
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: expected,
        options: options,
        answerSubmit: answerAtOnce,
      );
      final int choiceCount = random.nextInt(8);

      for (int choice = 0; choice < choiceCount; choice += 1) {
        expected = await _makeRandomChoice(
          tester,
          random: random,
          options: options,
          expected: expected,
        );
      }
      await tapTaskFormSubmit(tester);

      expectSameChoices(scene.submitted.single, expected);
      expect(scene.submitted.single.title, expected.title);
    }
  });
}
