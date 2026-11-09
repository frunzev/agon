import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/task_form/sign_workflow_notice.dart';
import 'package:agent_orchestration/screens/task_form/submit_refusal.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../support/planned_refusal.dart';
import 'task_form_scene.dart';

const List<String> _boundaryTimes = <String>[
  '00:00',
  '23:59',
  '24:00',
  '12:60',
  '01:59',
  '02:00',
  '02:30',
  '03:00',
  ' 09:00 ',
  '9:00',
  '09:5',
];
const int _largestTriedHour = 30;
const int _largestTriedMinute = 70;
const int _clockFieldWidth = 2;

String _randomClockField(Random random, int largest) {
  final String digits = random.nextInt(largest).toString();
  if (random.nextBool()) {
    return digits.padLeft(_clockFieldWidth, '0');
  }
  return digits;
}

String _randomTimeText(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _boundaryTimes);
  }
  final String hour = _randomClockField(random, _largestTriedHour);
  final String minute = _randomClockField(random, _largestTriedMinute);
  return '$hour:$minute';
}

({int hour, int minute})? _parseTimeByModel(String timeText) {
  final List<String> fields = timeText.trim().split(':');
  if (fields.length != 2) {
    return null;
  }
  final bool isPadded = fields.every(
    (String field) => field.length == _clockFieldWidth,
  );
  final int? hour = int.tryParse(fields.first);
  final int? minute = int.tryParse(fields.last);
  if (!isPadded || hour == null || minute == null) {
    return null;
  }
  if (hour >= Duration.hoursPerDay || minute >= Duration.minutesPerHour) {
    return null;
  }
  return (hour: hour, minute: minute);
}

ScheduleTime? _readScheduleTime(TaskFormValues values) {
  final Schedule? schedule = values.toSchedule();
  if (schedule is DailySchedule) {
    return schedule.at;
  }
  if (schedule is WeeklySchedule) {
    return schedule.at;
  }
  return null;
}

void main() {
  testWidgets('test_submit_property_saves_exactly_titles_with_a_non_white_'
      'space_character', (WidgetTester tester) async {
    final Random random = seededRandom(1131301);
    final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();
    final List<String> titles = <String>[
      for (final RuleTitleWhiteSpaceCase shared in table.cases) shared.title,
      for (int i = 0; i < widgetPropertyIterations; i += 1)
        table.randomExoticTitle(random),
    ];
    for (final String title in titles) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final String trimmed = table.trimByModel(title);
      final String reason = title.runes.toString();

      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: randomSavableValues(
          random,
          options,
        ).copyWith(title: title),
        options: options,
        answerSubmit: answerAtOnce,
      );
      await tapTaskFormSubmit(tester);

      final Matcher problemShown = trimmed.isEmpty
          ? findsOneWidget
          : findsNothing;
      expect(find.text(taskFormTitleProblem), problemShown, reason: reason);
      expect(scene.submitted, hasLength(trimmed.isEmpty ? 0 : 1));
      for (final TaskFormValues values in scene.submitted) {
        expect(values.toDraftedWork().title, trimmed, reason: reason);
      }
    }
  });

  testWidgets('test_submit_property_saves_exactly_valid_times', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131302);
    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final String timeText = _randomTimeText(random);
      final RepeatChoice repeat = pickOne(random, RepeatChoice.values);
      final ({int hour, int minute})? modelTime = _parseTimeByModel(timeText);
      final bool isSavable = !repeat.needsTime || modelTime != null;

      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: randomSavableValues(
          random,
          options,
        ).copyWith(timeText: timeText, repeat: repeat),
        options: options,
        answerSubmit: answerAtOnce,
      );
      await tapTaskFormSubmit(tester);

      final String reason = '"$timeText" ${repeat.name}';
      expect(scene.submitted, hasLength(isSavable ? 1 : 0), reason: reason);
      final Matcher problemShown = isSavable ? findsNothing : findsOneWidget;
      expect(find.text(taskFormTimeProblem), problemShown, reason: reason);
      if (isSavable && repeat.needsTime) {
        final ScheduleTime? saved = _readScheduleTime(scene.submitted.single);
        expect(saved?.hour, modelTime?.hour, reason: reason);
        expect(saved?.minute, modelTime?.minute, reason: reason);
      }
    }
  });

  testWidgets('test_submit_property_taps_while_saving_save_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131303);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final Completer<void> answer = Completer<void>();
      final int pressCount = 2 + random.nextInt(4);
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: randomSavableValues(random, options),
        options: options,
        answerSubmit: (TaskFormValues _) => answer.future,
      );
      final AppButton button = tester.widget(
        find.widgetWithText(AppButton, taskFormSubmitLabel),
      );

      for (int press = 0; press < pressCount; press += 1) {
        button.onPressed!();
      }
      await tester.pump();
      expect(scene.submitted, hasLength(1), reason: '$pressCount presses');
      expect(isTaskFormSubmitEnabled(tester), isFalse);

      answer.complete();
      await tester.pump();
      expect(isTaskFormSubmitEnabled(tester), isTrue);
      expect(scene.submitted, hasLength(1));
    }
  });

  testWidgets('test_submit_property_unsigned_workflow_scrolls_to_the_notice', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131304);
    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final List<TaskDoer> unsignedDoers = <TaskDoer>[
        for (final TaskDoer doer in listOptionValues(options.doers))
          if (options.findWorkflowToSign(doer) != null) doer,
      ];
      if (unsignedDoers.isEmpty) {
        continue;
      }
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: randomSavableValues(
          random,
          options,
        ).copyWith(doer: pickOne(random, unsignedDoers)),
        options: options,
        answerSubmit: answerAtOnce,
      );
      final ScrollableState page = tester.state(find.byType(Scrollable).first);
      page.position.jumpTo(page.position.maxScrollExtent);
      await tester.pump();

      final AppButton button = tester.widget(
        find.widgetWithText(AppButton, taskFormSubmitLabel),
      );
      button.onPressed!();
      await tester.pump();

      expect(scene.submitted, isEmpty);
      final Rect notice = tester.getRect(find.byType(SignWorkflowNotice));
      final Size window = tester.view.physicalSize;
      expect(notice.top, greaterThanOrEqualTo(0));
      expect(notice.top, lessThan(window.height));
    }
  });

  testWidgets('test_submit_property_refusal_shows_until_the_next_try', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131305);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final ExplainedRefusal refusal = randomExplainedRefusal(random);
      final PlannedRefusal planned = PlannedRefusal()
        ..problem = refusal.problem;
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: randomSavableValues(random, options),
        options: options,
        answerSubmit: (TaskFormValues _) =>
            planned.refuseOr<void>(() async {}),
      );

      await tapTaskFormSubmit(tester);
      final SubmitRefusalBanner banner = tester.widget(
        find.byType(SubmitRefusalBanner),
      );
      expect(banner.refusal.actionLabel, taskFormSubmitLabel);
      expect(banner.refusal.explanation, refusal.explanation);
      expect(find.text('$taskFormSubmitLabel did not work'), findsOneWidget);
      expect(isTaskFormSubmitEnabled(tester), isTrue);

      planned.problem = null;
      await tapTaskFormSubmit(tester);
      expect(find.byType(SubmitRefusalBanner), findsNothing);
      expect(scene.submitted, hasLength(2));
      expect(tester.takeException(), isNull);
    }
  });
}
