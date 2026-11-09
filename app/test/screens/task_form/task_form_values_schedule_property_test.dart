import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';

import '../../support/random_inputs.dart';
import '../../support/random_schedules.dart';
import '../../support/sample_records.dart';
import 'task_form_values_inputs.dart';

final RegExp _clockText = RegExp(r'^\d{2}:\d{2}$');

RepeatChoice _expectedRepeat(Schedule? schedule) {
  switch (schedule) {
    case null:
      return RepeatChoice.none;
    case HourlySchedule():
      return RepeatChoice.hourly;
    case DailySchedule():
      return RepeatChoice.daily;
    case WeeklySchedule():
      return RepeatChoice.weekly;
  }
}

ScheduleTime? _clockTimeOf(Schedule schedule) {
  if (schedule is DailySchedule) {
    return schedule.at;
  }
  if (schedule is WeeklySchedule) {
    return schedule.at;
  }
  return null;
}

void main() {
  test('test_find_repeat_choice_property_follows_the_schedule_kind', () {
    final Random random = seededRandom(1140401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomSchedule(random);

      expect(
        randomValuesFromDraft(random, schedule).repeat,
        _expectedRepeat(schedule),
      );
      expect(
        TaskFormValues.fromTask(buildScheduledTask(random, schedule)).repeat,
        _expectedRepeat(schedule),
      );
    }
  });

  test('test_find_repeat_choice_property_unscheduled_tasks_do_not_'
      'repeat', () {
    final Random random = seededRandom(1140402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = TaskFormValues.fromTask(
        buildScheduledTask(random, null),
      );

      expect(values.repeat, RepeatChoice.none);
      expect(values.toSchedule(), isNull);
    }
  });

  test('test_find_repeat_choice_property_schedules_round_trip', () {
    final Random random = seededRandom(1140403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomSchedule(random);
      final TaskFormValues values = TaskFormValues.fromTask(
        buildScheduledTask(random, schedule),
      );

      expect(
        describeScheduleShape(values.toSchedule()),
        describeScheduleShape(schedule),
      );
    }
  });

  test('test_find_weekday_property_weekly_schedules_keep_their_day', () {
    final Random random = seededRandom(1140404);

    for (final Weekday day in Weekday.values) {
      final Schedule schedule = WeeklySchedule(
        on: day,
        at: randomScheduleTime(random),
      );

      expect(
        TaskFormValues.fromTask(buildScheduledTask(random, schedule)).weekday,
        day,
      );
      expect(randomValuesFromDraft(random, schedule).weekday, day);
    }
  });

  test('test_find_weekday_property_other_schedules_start_on_monday', () {
    final Random random = seededRandom(1140405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomSchedule(random);
      if (schedule is WeeklySchedule) {
        continue;
      }

      expect(randomValuesFromDraft(random, schedule).weekday, Weekday.monday);
      expect(randomValuesFromDraft(random, null).weekday, Weekday.monday);
    }
  });

  test('test_find_weekday_property_switching_to_weekly_keeps_the_day', () {
    final Random random = seededRandom(1140406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomSchedule(random);
      final TaskFormValues values = randomValuesFromDraft(
        random,
        schedule,
      ).copyWith(repeat: RepeatChoice.weekly);

      final Schedule? weekly = values.toSchedule();

      expect(weekly, isA<WeeklySchedule>());
      expect((weekly! as WeeklySchedule).on, values.weekday);
    }
  });

  test('test_find_time_text_property_clock_schedules_round_trip', () {
    final Random random = seededRandom(1140407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomSchedule(random);
      final ScheduleTime? at = _clockTimeOf(schedule);
      final TaskFormValues values = randomValuesFromDraft(random, schedule);

      final String expectedText = at == null
          ? defaultScheduleTimeText
          : formatScheduleTime(at);
      expect(values.timeText, expectedText);
    }
  });

  test('test_find_time_text_property_always_shows_a_valid_clock', () {
    final Random random = seededRandom(1140408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule? schedule = random.nextBool()
          ? null
          : randomSchedule(random);
      final TaskFormValues values = TaskFormValues.fromTask(
        buildScheduledTask(random, schedule),
      ).copyWith(repeat: pickOne(random, RepeatChoice.values));

      expect(values.timeText, matches(_clockText));
      expect(values.describeTimeProblem(), isNull);
    }
  });

  test('test_find_time_text_property_unscheduled_work_starts_at_nine', () {
    final Random random = seededRandom(1140409);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = TaskFormValues.fromTask(
        buildScheduledTask(random, HourlySchedule(minute: random.nextInt(60))),
      );

      expect(values.timeText, defaultScheduleTimeText);
      expect(
        randomValuesFromDraft(random, null).timeText,
        defaultScheduleTimeText,
      );
    }
  });

  test('test_find_hourly_minute_property_hourly_schedules_round_trip', () {
    for (int minute = 0; minute < Duration.minutesPerHour; minute += 1) {
      final Random random = seededRandom(1140410 + minute);
      final TaskFormValues values = TaskFormValues.fromTask(
        buildScheduledTask(random, HourlySchedule(minute: minute)),
      );

      final Schedule? back = values.toSchedule();

      expect(values.hourlyMinute, minute);
      expect((back! as HourlySchedule).minute, minute);
    }
  });

  test('test_find_hourly_minute_property_other_schedules_use_zero', () {
    final Random random = seededRandom(1140411);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomSchedule(random);
      if (schedule is HourlySchedule) {
        continue;
      }

      expect(randomValuesFromDraft(random, schedule).hourlyMinute, 0);
      expect(randomValuesFromDraft(random, null).hourlyMinute, 0);
    }
  });

  test('test_find_hourly_minute_property_stays_within_the_hour', () {
    final Random random = seededRandom(1140412);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule? schedule = random.nextBool()
          ? null
          : randomSchedule(random);
      final int minute = randomValuesFromDraft(random, schedule).hourlyMinute;

      expect(minute, inInclusiveRange(0, Duration.minutesPerHour - 1));
    }
  });
}
