import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';
import 'package:agent_orchestration/data/rules/schedule_time_zone.dart';

import '../../support/random_inputs.dart';

const int _widestShiftInMinutes = 30 * Duration.minutesPerDay;
const Duration _oneMinute = Duration(minutes: 1);
final ScheduleTime _midnight = ScheduleTime(hour: 0, minute: 0);
final ScheduleTime _lastMinute = ScheduleTime(
  hour: Duration.hoursPerDay - 1,
  minute: Duration.minutesPerHour - 1,
);

ScheduleTime _randomScheduleTime(Random random) {
  return ScheduleTime(
    hour: random.nextInt(Duration.hoursPerDay),
    minute: random.nextInt(Duration.minutesPerHour),
  );
}

int _minuteOfDay(ScheduleTime time) {
  return time.hour * Duration.minutesPerHour + time.minute;
}

ScheduleTime _shiftDailyTime(ScheduleTime at, int shiftInMinutes) {
  final Schedule shifted = convertScheduleFromUtc(
    DailySchedule(at: at),
    utcOffset: Duration(minutes: shiftInMinutes),
  );
  return (shifted as DailySchedule).at;
}

WeeklySchedule _shiftWeekly(WeeklySchedule schedule, Duration shift) {
  return convertScheduleFromUtc(schedule, utcOffset: shift) as WeeklySchedule;
}

void main() {
  test('test_minute_of_day_property_daily_shift_moves_the_minute_of_day', () {
    final Random random = seededRandom(88501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScheduleTime at = _randomScheduleTime(random);
      final int shift =
          random.nextInt(2 * _widestShiftInMinutes + 1) -
          _widestShiftInMinutes;

      final ScheduleTime shifted = _shiftDailyTime(at, shift);

      final int expected = (_minuteOfDay(at) + shift) % Duration.minutesPerDay;
      expect(_minuteOfDay(shifted), expected);
    }
  });

  test('test_minute_of_day_property_zero_shift_keeps_every_time', () {
    for (int minute = 0; minute < Duration.minutesPerDay; minute += 1) {
      final ScheduleTime at = ScheduleTime(
        hour: minute ~/ Duration.minutesPerHour,
        minute: minute % Duration.minutesPerHour,
      );

      final ScheduleTime shifted = _shiftDailyTime(at, 0);
      final WeeklySchedule weekly = _shiftWeekly(
        WeeklySchedule(on: Weekday.wednesday, at: at),
        Duration.zero,
      );

      expect(formatScheduleTime(shifted), formatScheduleTime(at));
      expect(formatScheduleTime(weekly.at), formatScheduleTime(at));
      expect(weekly.on, Weekday.wednesday);
    }
  });

  test('test_minute_of_day_property_one_minute_across_midnight_changes_the_'
      'day', () {
    final Random random = seededRandom(88503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Weekday on = pickOne(random, Weekday.values);
      final int nextIsoNumber = on.isoNumber % DateTime.daysPerWeek + 1;

      final WeeklySchedule earlier = _shiftWeekly(
        WeeklySchedule(on: on, at: _midnight),
        -_oneMinute,
      );
      final WeeklySchedule later = _shiftWeekly(
        WeeklySchedule(on: on, at: _lastMinute),
        _oneMinute,
      );

      expect(earlier.on.isoNumber % DateTime.daysPerWeek + 1, on.isoNumber);
      expect(formatScheduleTime(earlier.at), '23:59');
      expect(later.on.isoNumber, nextIsoNumber);
      expect(formatScheduleTime(later.at), '00:00');
    }
  });

  test('test_time_at_property_huge_shifts_still_give_clock_times', () {
    final Random random = seededRandom(88504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScheduleTime at = _randomScheduleTime(random);
      final int shift =
          random.nextInt(2 * _widestShiftInMinutes + 1) -
          _widestShiftInMinutes;

      final ScheduleTime shifted = _shiftDailyTime(at, shift);

      expect(shifted.hour, inInclusiveRange(0, Duration.hoursPerDay - 1));
      expect(shifted.minute, inInclusiveRange(0, Duration.minutesPerHour - 1));
      expect(parseScheduleTime(formatScheduleTime(shifted)), isNotNull);
    }
  });

  test('test_time_at_property_every_minute_of_the_day_is_reached_once', () {
    final Set<String> reached = <String>{};

    for (int shift = 0; shift < Duration.minutesPerDay; shift += 1) {
      reached.add(formatScheduleTime(_shiftDailyTime(_midnight, shift)));
    }

    expect(reached.length, Duration.minutesPerDay);
  });

  test('test_time_at_property_splits_minutes_into_hours_and_minutes', () {
    final Random random = seededRandom(88506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int shift = random.nextInt(Duration.minutesPerDay);

      final ScheduleTime shifted = _shiftDailyTime(_midnight, shift);

      expect(shifted.hour, shift ~/ Duration.minutesPerHour);
      expect(shifted.minute, shift % Duration.minutesPerHour);
    }
  });
}
