import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';
import 'package:agent_orchestration/data/rules/schedule_time_zone.dart';

import '../../bridge/support/random_moments.dart';
import '../../support/random_inputs.dart';
import '../../support/random_schedules.dart';
import 'support/local_clock_changes.dart';

const int _widestDayShift = 14;
final DateTime _firstMondayOf2024 = DateTime.utc(2024);

Duration _randomUtcOffset(Random random, List<DateTime> clockChanges) {
  if (clockChanges.isNotEmpty && random.nextBool()) {
    final DateTime clockChange = pickOne(random, clockChanges);
    final DateTime justBefore = clockChange.subtract(const Duration(hours: 2));
    return pickOne(random, <Duration>[
      clockChange.timeZoneOffset,
      justBefore.timeZoneOffset,
    ]);
  }
  return Duration(minutes: randomOffsetMinutes(random));
}

DateTime _wallClockOf(Weekday on, ScheduleTime at) {
  return _firstMondayOf2024.add(
    Duration(days: on.isoNumber - 1, hours: at.hour, minutes: at.minute),
  );
}

Schedule _modelShift(Schedule schedule, Duration shift) {
  switch (schedule) {
    case HourlySchedule(:final int minute):
      final DateTime shifted = _firstMondayOf2024
          .add(Duration(minutes: minute))
          .add(shift);
      return HourlySchedule(minute: shifted.minute);
    case DailySchedule(:final ScheduleTime at):
      final DateTime shifted = _wallClockOf(Weekday.monday, at).add(shift);
      return DailySchedule(
        at: ScheduleTime(hour: shifted.hour, minute: shifted.minute),
      );
    case WeeklySchedule(:final Weekday on, :final ScheduleTime at):
      final DateTime shifted = _wallClockOf(on, at).add(shift);
      return WeeklySchedule(
        on: Weekday.fromIsoNumber(shifted.weekday),
        at: ScheduleTime(hour: shifted.hour, minute: shifted.minute),
      );
  }
}

void main() {
  final List<DateTime> clockChanges = findLocalClockChanges();

  test('test_convert_schedule_to_utc_property_matches_the_wall_clock_'
      'model', () {
    final Random random = seededRandom(88401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule localSchedule = randomSchedule(random);
      final Duration utcOffset = _randomUtcOffset(random, clockChanges);

      final Schedule utcSchedule = convertScheduleToUtc(
        localSchedule,
        utcOffset: utcOffset,
      );

      final Schedule expected = _modelShift(localSchedule, -utcOffset);
      expect(describeSchedule(utcSchedule), describeSchedule(expected));
    }
  });

  test('test_convert_schedule_to_utc_property_half_hour_zones_move_hourly_'
      'minutes', () {
    final Random random = seededRandom(88402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int minute = random.nextInt(Duration.minutesPerHour);
      final int offsetMinutes = randomOffsetMinutes(random);

      final Schedule utcSchedule = convertScheduleToUtc(
        HourlySchedule(minute: minute),
        utcOffset: Duration(minutes: offsetMinutes),
      );

      final int expectedMinute =
          (minute - offsetMinutes) % Duration.minutesPerHour;
      expect((utcSchedule as HourlySchedule).minute, expectedMinute);
    }
  });

  test('test_convert_schedule_from_utc_property_matches_the_wall_clock_'
      'model', () {
    final Random random = seededRandom(88403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule utcSchedule = randomSchedule(random);
      final Duration utcOffset = _randomUtcOffset(random, clockChanges);

      final Schedule localSchedule = convertScheduleFromUtc(
        utcSchedule,
        utcOffset: utcOffset,
      );

      final Schedule expected = _modelShift(utcSchedule, utcOffset);
      expect(describeSchedule(localSchedule), describeSchedule(expected));
    }
  });

  test('test_convert_schedule_from_utc_property_round_trips_through_to_'
      'utc', () {
    final Random random = seededRandom(88404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule utcSchedule = randomSchedule(random);
      final Duration utcOffset = _randomUtcOffset(random, clockChanges);

      final Schedule localSchedule = convertScheduleFromUtc(
        utcSchedule,
        utcOffset: utcOffset,
      );
      final Schedule backToUtc = convertScheduleToUtc(
        localSchedule,
        utcOffset: utcOffset,
      );

      expect(describeSchedule(backToUtc), describeSchedule(utcSchedule));
    }
  });

  test('test_convert_schedule_from_utc_property_runs_at_the_same_'
      'instants', () {
    final Random random = seededRandom(88405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule utcSchedule = randomSchedule(random);
      final Duration utcOffset = _randomUtcOffset(random, clockChanges);
      final DateTime utcMoment = randomPreciseUtcMoment(random);
      final Schedule localSchedule = convertScheduleFromUtc(
        utcSchedule,
        utcOffset: utcOffset,
      );

      final DateTime nextUtcRun = findNextRunAfter(utcSchedule, utcMoment);
      final DateTime nextWallClockRun = findNextRunAfter(
        localSchedule,
        utcMoment.add(utcOffset),
      );

      expect(nextWallClockRun.subtract(utcOffset), nextUtcRun);
    }
  });

  test('test_shift_schedule_property_keeps_the_kind_of_schedule', () {
    final Random random = seededRandom(88406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomSchedule(random);
      final Duration utcOffset = _randomUtcOffset(random, clockChanges);

      final Schedule toUtc = convertScheduleToUtc(
        schedule,
        utcOffset: utcOffset,
      );
      final Schedule fromUtc = convertScheduleFromUtc(
        schedule,
        utcOffset: utcOffset,
      );

      expect(toUtc.runtimeType, schedule.runtimeType);
      expect(fromUtc.runtimeType, schedule.runtimeType);
    }
  });

  test('test_shift_schedule_property_shifts_add_up', () {
    final Random random = seededRandom(88407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomSchedule(random);
      final Duration first = _randomUtcOffset(random, clockChanges);
      final Duration second = _randomUtcOffset(random, clockChanges);

      final Schedule twice = convertScheduleFromUtc(
        convertScheduleFromUtc(schedule, utcOffset: first),
        utcOffset: second,
      );
      final Schedule once = convertScheduleFromUtc(
        schedule,
        utcOffset: first + second,
      );
      final Schedule inverse = convertScheduleToUtc(
        schedule,
        utcOffset: -first,
      );

      expect(describeSchedule(twice), describeSchedule(once));
      expect(
        describeSchedule(inverse),
        describeSchedule(convertScheduleFromUtc(schedule, utcOffset: first)),
      );
    }
  });

  test('test_shift_schedule_property_whole_day_shifts_keep_the_clock', () {
    final Random random = seededRandom(88408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Weekday on = pickOne(random, Weekday.values);
      final ScheduleTime at = ScheduleTime(
        hour: random.nextInt(Duration.hoursPerDay),
        minute: random.nextInt(Duration.minutesPerHour),
      );
      final int days =
          random.nextInt(2 * _widestDayShift + 1) - _widestDayShift;

      final Schedule weekly = convertScheduleFromUtc(
        WeeklySchedule(on: on, at: at),
        utcOffset: Duration(days: days),
      );
      final Schedule daily = convertScheduleFromUtc(
        DailySchedule(at: at),
        utcOffset: Duration(days: days),
      );

      final int expectedIsoNumber =
          (on.isoNumber - 1 + days) % DateTime.daysPerWeek + 1;
      expect((weekly as WeeklySchedule).on.isoNumber, expectedIsoNumber);
      expect(formatScheduleTime(weekly.at), formatScheduleTime(at));
      final ScheduleTime dailyTime = (daily as DailySchedule).at;
      expect(formatScheduleTime(dailyTime), formatScheduleTime(at));
    }
  });
}
