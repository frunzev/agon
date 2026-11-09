import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/schedule_rules.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../../support/sample_records.dart';
import 'task_form_scene.dart';

const List<String> _brokenTimes = <String>['', '24:00', '9:00', '12:60', 'ab'];
const String _lineBreak = '\n';
const List<RepeatChoice> _timedRepeats = <RepeatChoice>[
  RepeatChoice.daily,
  RepeatChoice.weekly,
];

Future<TaskFormScene> _pumpBrokenForm(
  WidgetTester tester, {
  required Random random,
  required RuleTitleWhiteSpaceTable table,
}) async {
  final TaskFormOptions options = buildRandomTaskFormOptions(random);
  final TaskFormValues broken = randomSavableValues(random, options).copyWith(
    title: table.randomWhiteSpaceRun(random),
    timeText: pickOne(random, _brokenTimes),
    repeat: pickOne(random, _timedRepeats),
  );
  final TaskFormScene scene = await pumpTaskFormScene(
    tester,
    random: random,
    initialValues: broken,
    options: options,
    answerSubmit: answerAtOnce,
  );
  await tapTaskFormSubmit(tester);
  expect(find.text(taskFormTitleProblem), findsOneWidget);
  expect(find.text(taskFormTimeProblem), findsOneWidget);
  return scene;
}

String _pickTitle(Random random, RuleTitleWhiteSpaceTable table) {
  if (random.nextBool()) {
    return table.randomWhiteSpaceRun(random);
  }
  return table.randomExoticTitle(random);
}

String _randomTypedTitle(
  WidgetTester tester, {
  required Random random,
  required RuleTitleWhiteSpaceTable table,
}) {
  final String shown = readFieldText(tester, taskFormTitleLabel);
  String typed = _pickTitle(random, table);
  while (typed.replaceAll(_lineBreak, '') == shown) {
    typed = _pickTitle(random, table);
  }
  return typed;
}

String _pickTime(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _brokenTimes);
  }
  return formatScheduleTime(randomScheduleTime(random));
}

String _randomTypedTime(WidgetTester tester, Random random) {
  final String shown = readFieldText(tester, taskFormTimeLabel);
  String typed = _pickTime(random);
  while (typed == shown) {
    typed = _pickTime(random);
  }
  return typed;
}

void main() {
  late RuleTitleWhiteSpaceTable table;

  setUpAll(() {
    table = readRuleTitleWhiteSpaceTable();
  });

  testWidgets('test_change_title_property_typing_clears_the_title_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131501);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpBrokenForm(tester, random: random, table: table);

      await enterFieldText(
        tester,
        label: taskFormTitleLabel,
        text: _randomTypedTitle(tester, random: random, table: table),
      );

      expect(find.text(taskFormTitleProblem), findsNothing);
    }
  });

  testWidgets('test_change_title_property_reports_the_typed_title', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131502);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormScene scene = await _pumpBrokenForm(
        tester,
        random: random,
        table: table,
      );

      await enterFieldText(
        tester,
        label: taskFormTitleLabel,
        text: _randomTypedTitle(tester, random: random, table: table),
      );

      final String shown = readFieldText(tester, taskFormTitleLabel);
      expect(scene.reportedChanges.single.title, shown);
      expect(scene.submitted, isEmpty);
    }
  });

  testWidgets('test_change_title_property_leaves_the_time_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131503);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpBrokenForm(tester, random: random, table: table);

      await enterFieldText(
        tester,
        label: taskFormTitleLabel,
        text: _randomTypedTitle(tester, random: random, table: table),
      );

      expect(find.text(taskFormTimeProblem), findsOneWidget);
    }
  });

  testWidgets('test_change_time_property_typing_clears_the_time_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131504);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpBrokenForm(tester, random: random, table: table);

      await enterFieldText(
        tester,
        label: taskFormTimeLabel,
        text: _randomTypedTime(tester, random),
      );

      expect(find.text(taskFormTimeProblem), findsNothing);
    }
  });

  testWidgets('test_change_time_property_reports_the_typed_time', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131505);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormScene scene = await _pumpBrokenForm(
        tester,
        random: random,
        table: table,
      );
      final String typed = _randomTypedTime(tester, random);

      await enterFieldText(tester, label: taskFormTimeLabel, text: typed);

      expect(scene.reportedChanges.single.timeText, typed);
      expect(readFieldText(tester, taskFormTimeLabel), typed);
      await tapTaskFormSubmit(tester);
      expect(scene.submitted, isEmpty);
    }
  });

  testWidgets('test_change_time_property_leaves_the_title_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131506);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpBrokenForm(tester, random: random, table: table);

      await enterFieldText(
        tester,
        label: taskFormTimeLabel,
        text: _randomTypedTime(tester, random),
      );

      expect(find.text(taskFormTitleProblem), findsOneWidget);
    }
  });
}
