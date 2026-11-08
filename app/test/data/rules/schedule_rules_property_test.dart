import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';

import '../../bridge/support/random_moments.dart';
import '../../support/random_inputs.dart';
import '../../support/random_schedules.dart';
import 'schedule_rules_test.dart' show schedulePeriod;
import 'support/local_clock_changes.dart';

const Duration _longestClockChange = Duration(hours: 1);
const int _earliestYear = 2000;
const int _yearSpan = 60;
const int _monthsPerYear = 12;
const int _lateHoursOfTheDay = 6;

DateTime _randomUtcMomentOnLastDayOfMonth(Random random) {
  final DateTime monthStart = DateTime.utc(
    _earliestYear + random.nextInt(_yearSpan),
    1 + random.nextInt(_monthsPerYear),
  );
  final DateTime nextMonthStart = DateTime.utc(
    monthStart.year,
    monthStart.month + 1,
  );
  final int secondsBeforeMonthEnd =
      1 + random.nextInt(Duration.secondsPerHour * _lateHoursOfTheDay);
  return nextMonthStart.subtract(Duration(seconds: secondsBeforeMonthEnd));
}

void main() {
  test('test_find_next_run_after_property_strictly_later_around_local_'
      'clock_changes', () {
    final Random random = seededRandom(88101);
    final List<DateTime> clockChanges = findLocalClockChanges();

    for (int i = 0; i < propertyIterations * 5; i += 1) {
      final Schedule schedule = randomSchedule(random);
      final DateTime moment = randomMomentNearClockChange(
        random,
        clockChanges,
      );

      final DateTime nextRun = findNextRunAfter(schedule, moment);

      final Duration longestWait =
          schedulePeriod(schedule) + _longestClockChange;
      expect(nextRun.isAfter(moment), isTrue, reason: '$moment -> $nextRun');
      expect(nextRun.difference(moment) <= longestWait, isTrue);
      expect(nextRun.isUtc, isFalse);
    }
  });

  test('test_find_next_run_after_property_every_moment_before_the_next_run_'
      'waits_for_it', () {
    final Random random = seededRandom(88102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomSchedule(random);
      final DateTime moment = randomPreciseUtcMoment(random);
      final DateTime nextRun = findNextRunAfter(schedule, moment);
      final int waitInSeconds = nextRun.difference(moment).inSeconds;
      final DateTime laterMoment = moment.add(
        Duration(seconds: random.nextInt(max(waitInSeconds, 1))),
      );

      expect(findNextRunAfter(schedule, laterMoment), nextRun);
      expect(
        findNextRunAfter(schedule, nextRun),
        nextRun.add(schedulePeriod(schedule)),
      );
    }
  });

  test('test_first_slot_after_property_a_moment_on_the_slot_waits_a_whole_'
      'period', () {
    final Random random = seededRandom(88103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomSchedule(random);
      final DateTime moment = randomUtcMoment(random);
      final DateTime slot = findNextRunAfter(schedule, moment);

      final DateTime nextRun = findNextRunAfter(schedule, slot);

      expect(nextRun.difference(slot), schedulePeriod(schedule));
    }
  });

  test('test_first_slot_after_property_weekly_runs_come_on_their_weekday_'
      'within_a_week', () {
    final Random random = seededRandom(88104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Weekday on = pickOne(random, Weekday.values);
      final ScheduleTime at = ScheduleTime(
        hour: random.nextInt(Duration.hoursPerDay),
        minute: random.nextInt(Duration.minutesPerHour),
      );
      final DateTime moment = randomPreciseUtcMoment(random);

      final DateTime nextRun = findNextRunAfter(
        WeeklySchedule(on: on, at: at),
        moment,
      );

      final int daysAway = nextRun.difference(moment).inDays;
      expect(nextRun.weekday, on.isoNumber);
      expect(daysAway, lessThan(DateTime.daysPerWeek));
      expect(nextRun.isAfter(moment), isTrue);
    }
  });

  test('test_first_slot_after_property_daily_runs_today_only_when_the_time_'
      'is_still_ahead', () {
    final Random random = seededRandom(88105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScheduleTime at = ScheduleTime(
        hour: random.nextInt(Duration.hoursPerDay),
        minute: random.nextInt(Duration.minutesPerHour),
      );
      final DateTime moment = randomPreciseUtcMoment(random);
      final DateTime today = DateTime.utc(
        moment.year,
        moment.month,
        moment.day,
      );
      final DateTime slotToday = today.add(
        Duration(hours: at.hour, minutes: at.minute),
      );

      final DateTime nextRun = findNextRunAfter(DailySchedule(at: at), moment);

      final DateTime expected = slotToday.isAfter(moment)
          ? slotToday
          : slotToday.add(const Duration(days: 1));
      expect(nextRun, expected);
    }
  });

  test('test_moment_like_property_rolls_over_month_and_year_ends', () {
    final Random random = seededRandom(88106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = _randomUtcMomentOnLastDayOfMonth(random);
      final ScheduleTime earlierTime = ScheduleTime(
        hour: random.nextInt(moment.hour + 1),
        minute: 0,
      );

      final DateTime nextRun = findNextRunAfter(
        DailySchedule(at: earlierTime),
        moment,
      );

      final DateTime nextMonthStart = DateTime.utc(
        moment.year,
        moment.month + 1,
      );
      expect(nextRun.day, 1);
      expect(nextRun.month, nextMonthStart.month);
      expect(nextRun.year, nextMonthStart.year);
    }
  });

  test('test_moment_like_property_keeps_the_kind_of_clock', () {
    final Random random = seededRandom(88107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomSchedule(random);
      final DateTime moment = randomPreciseMoment(random);

      final DateTime nextRun = findNextRunAfter(schedule, moment);

      expect(nextRun.isUtc, moment.isUtc);
    }
  });

  test('test_moment_like_property_drops_seconds_and_smaller', () {
    final Random random = seededRandom(88108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Schedule schedule = randomSchedule(random);
      final DateTime moment = randomPreciseMoment(random);

      final DateTime nextRun = findNextRunAfter(schedule, moment);

      expect(nextRun.second, 0);
      expect(nextRun.millisecond, 0);
      expect(nextRun.microsecond, 0);
    }
  });
}
