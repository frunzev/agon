import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/screens/task_form/schedule_fields.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../presentation/support/plain_shown_text.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'task_form_scene.dart';

const String _designPage = 'job-new';
const String _repeatLabel = 'Repeat';
const String _weekdayLabel = 'On';
const String _timeLabel = 'At';
const String _timeHint = 'HH:MM';

final class _ScheduleRecorder {
  final List<String> times = <String>[];
  final List<RepeatChoice> repeats = <RepeatChoice>[];
  final List<Weekday> weekdays = <Weekday>[];

  void recordTime(String time) {
    times.add(time);
  }

  void recordRepeat(RepeatChoice repeat) {
    repeats.add(repeat);
  }

  void recordWeekday(Weekday weekday) {
    weekdays.add(weekday);
  }
}

typedef _ScheduleScene = ({ScheduleFields fields, _ScheduleRecorder recorder});

_ScheduleScene _randomScene(Random random) {
  final List<RepeatChoice> repeatChoices = <RepeatChoice>[
    for (final RepeatChoice choice in RepeatChoice.values)
      if (random.nextBool()) choice,
  ];
  final RepeatChoice repeat = pickOne(random, RepeatChoice.values);
  if (!repeatChoices.contains(repeat)) {
    repeatChoices.add(repeat);
  }
  final _ScheduleRecorder recorder = _ScheduleRecorder();
  final ScheduleFields fields = ScheduleFields(
    repeat: repeat,
    repeatChoices: repeatChoices,
    repeatHint: random.nextBool() ? 'Hint ${randomText(random)}' : null,
    weekday: pickOne(random, Weekday.values),
    timeController: TextEditingController(text: randomText(random)),
    timeProblem: random.nextBool() ? 'Problem ${randomText(random)}' : null,
    onTimeChanged: recorder.recordTime,
    onRepeatChanged: recorder.recordRepeat,
    onWeekdayChanged: recorder.recordWeekday,
  );
  return (fields: fields, recorder: recorder);
}

Finder _findBlock(String label) {
  return find.byWidgetPredicate(
    (Widget widget) => widget is FormFieldBlock && widget.label == label,
  );
}

Future<_ScheduleScene> _pumpRandomScene(
  WidgetTester tester,
  Random random,
) async {
  final _ScheduleScene scene = _randomScene(random);
  addTearDown(scene.fields.timeController.dispose);
  await pumpScrollingPage(tester, random: random, page: scene.fields);
  return scene;
}

void main() {
  test('test_schedule_fields_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(1132601);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _ScheduleScene scene = _randomScene(random);
      final ScheduleFields fields = scene.fields;

      final ScheduleFields copy = ScheduleFields(
        repeat: fields.repeat,
        repeatChoices: fields.repeatChoices,
        repeatHint: fields.repeatHint,
        weekday: fields.weekday,
        timeController: fields.timeController,
        timeProblem: fields.timeProblem,
        onTimeChanged: fields.onTimeChanged,
        onRepeatChanged: fields.onRepeatChanged,
        onWeekdayChanged: fields.onWeekdayChanged,
      );

      expect(copy.repeat, fields.repeat);
      expect(copy.repeatChoices, same(fields.repeatChoices));
      expect(copy.repeatHint, fields.repeatHint);
      expect(copy.weekday, fields.weekday);
      expect(copy.timeController, same(fields.timeController));
      expect(copy.timeProblem, fields.timeProblem);
      fields.timeController.dispose();
    }
  });

  test('test_schedule_fields_constructor_property_keeps_the_callbacks', () {
    final Random random = seededRandom(1132602);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _ScheduleScene scene = _randomScene(random);
      final String time = randomHostileText(random);
      final RepeatChoice repeat = pickOne(random, RepeatChoice.values);
      final Weekday weekday = pickOne(random, Weekday.values);

      scene.fields.onTimeChanged(time);
      scene.fields.onRepeatChanged(repeat);
      scene.fields.onWeekdayChanged(weekday);

      expect(scene.recorder.times, <String>[time]);
      expect(scene.recorder.repeats, <RepeatChoice>[repeat]);
      expect(scene.recorder.weekdays, <Weekday>[weekday]);
      scene.fields.timeController.dispose();
    }
  });

  test('test_schedule_fields_constructor_property_no_key_unless_given', () {
    final Random random = seededRandom(1132603);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _ScheduleScene scene = _randomScene(random);

      expect(scene.fields.key, isNull);
      scene.fields.timeController.dispose();
    }
  });

  testWidgets('test_schedule_fields_build_property_fields_follow_repeat', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1132604);
    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final _ScheduleScene scene = await _pumpRandomScene(tester, random);
      final RepeatChoice repeat = scene.fields.repeat;

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(_findBlock(_repeatLabel), findsOneWidget);
      final bool isWeekly = repeat == RepeatChoice.weekly;
      final bool needsTime =
          repeat == RepeatChoice.daily || repeat == RepeatChoice.weekly;
      expect(
        _findBlock(_weekdayLabel),
        isWeekly ? findsOneWidget : findsNothing,
      );
      expect(
        _findBlock(_timeLabel),
        needsTime ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_schedule_fields_build_property_lists_follow_the_choices', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1132605);
    final String designText = readDesignPageText(_designPage);
    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final _ScheduleScene scene = await _pumpRandomScene(tester, random);

      final SelectField<RepeatChoice> repeat = tester.widget(
        find.byType(SelectField<RepeatChoice>),
      );
      expect(repeat.value, scene.fields.repeat);
      expect(listOptionValues(repeat.entries), scene.fields.repeatChoices);
      if (scene.fields.repeat != RepeatChoice.weekly) {
        continue;
      }
      final SelectField<Weekday> weekday = tester.widget(
        find.byType(SelectField<Weekday>),
      );
      expect(weekday.value, scene.fields.weekday);
      expect(listOptionValues(weekday.entries), Weekday.values);
      for (final Weekday day in Weekday.values) {
        expect(designText, contains(' ${day.label} '));
      }
    }
  });

  testWidgets('test_schedule_fields_build_property_hints_problems_typing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1132606);
    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final _ScheduleScene scene = await _pumpRandomScene(tester, random);
      final FormFieldBlock repeat = tester.widget(_findBlock(_repeatLabel));
      expect(repeat.hint, scene.fields.repeatHint);
      if (!scene.fields.repeat.needsTime) {
        continue;
      }
      final TextField time = tester.widget(findFieldInput(_timeLabel));
      expect(time.decoration?.hintText, _timeHint);
      expect(time.decoration?.errorText, scene.fields.timeProblem);
      final String typed = 'typed ${randomText(random)}';

      await enterFieldText(tester, label: _timeLabel, text: typed);

      expect(scene.recorder.times.last, typed);
      expect(scene.fields.timeController.text, typed);
    }
  });
}
