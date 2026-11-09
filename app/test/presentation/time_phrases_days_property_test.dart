import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../support/random_inputs.dart';

const int _largestDayShift = 800;
const int _weekLength = 7;
const int _nightEndsBeforeHour = 6;
const int _largestUpcomingDays = 40;

const List<String> _weekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

DateTime _momentDaysLater(DateTime moment, int days, Random random) {
  return DateTime(
    moment.year,
    moment.month,
    moment.day + days,
    random.nextInt(Duration.hoursPerDay),
    random.nextInt(Duration.minutesPerHour),
    random.nextInt(Duration.secondsPerMinute),
  );
}

int _randomDayShift(Random random) {
  return random.nextInt(_largestDayShift * 2 + 1) - _largestDayShift;
}

void main() {
  test('test_count_calendar_days_between_property_counts_shifted_days', () {
    final Random random = seededRandom(95501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime earlier = randomLocalMoment(random);
      final int days = _randomDayShift(random);
      final DateTime later = _momentDaysLater(earlier, days, random);

      expect(countCalendarDaysBetween(earlier, later), days);
      expect(countCalendarDaysBetween(earlier.toUtc(), later.toUtc()), days);
    }
  });

  test('test_count_calendar_days_between_property_swapping_negates', () {
    final Random random = seededRandom(95502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime first = randomLocalMoment(random);
      final DateTime second = randomUtcMoment(random);

      expect(
        countCalendarDaysBetween(second, first),
        -countCalendarDaysBetween(first, second),
      );
      expect(countCalendarDaysBetween(first, first), 0);
    }
  });

  test('test_count_calendar_days_between_property_counts_add_up', () {
    final Random random = seededRandom(95503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime first = randomLocalMoment(random);
      final DateTime second = _momentDaysLater(
        first,
        _randomDayShift(random),
        random,
      );
      final DateTime third = randomUtcMoment(random);

      expect(
        countCalendarDaysBetween(first, second) +
            countCalendarDaysBetween(second, third),
        countCalendarDaysBetween(first, third),
      );
    }
  });

  test('test_describe_upcoming_time_property_day_word_follows_the_'
      'calendar', () {
    final Random random = seededRandom(95504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final int daysAhead = random.nextInt(_largestUpcomingDays);
      final DateTime moment = _momentDaysLater(now, daysAhead, random);
      if (!moment.isAfter(now)) {
        continue;
      }
      final String clock = formatClockTime(moment);
      final String phrase = describeUpcomingTime(moment, now);

      if (daysAhead == 0) {
        expect(phrase, 'Today $clock');
      } else if (daysAhead == 1 && moment.hour < _nightEndsBeforeHour) {
        expect(phrase, 'Tonight $clock');
      } else if (daysAhead == 1) {
        expect(phrase, 'Tomorrow $clock');
      } else if (daysAhead < _weekLength) {
        expect(phrase, '${_weekdayNames[moment.weekday - 1]} $clock');
      } else {
        expect(phrase, startsWith('${moment.day} '));
        expect(phrase, endsWith(' $clock'));
        expect(formatCalendarDate(moment), startsWith(phrase.split(' ')[0]));
        expect(formatCalendarDate(moment), contains(phrase.split(' ')[1]));
      }
    }
  });

  test('test_describe_upcoming_time_property_only_the_day_of_now_'
      'matters', () {
    final Random random = seededRandom(95505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime day = randomLocalMoment(random);
      final DateTime earlyNow = DateTime(day.year, day.month, day.day);
      final DateTime lateNow = DateTime(
        day.year,
        day.month,
        day.day,
        random.nextInt(Duration.hoursPerDay),
        random.nextInt(Duration.minutesPerHour),
      );
      final DateTime moment = _momentDaysLater(
        day,
        1 + random.nextInt(_largestUpcomingDays),
        random,
      );

      expect(
        describeUpcomingTime(moment, lateNow),
        describeUpcomingTime(moment, earlyNow),
      );
    }
  });

  test('test_describe_upcoming_time_property_a_week_ahead_never_reuses_'
      'a_weekday', () {
    final Random random = seededRandom(95506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final List<String> dayWords = <String>[];
      for (int days = 0; days < _weekLength; days += 1) {
        final DateTime moment = DateTime(
          now.year,
          now.month,
          now.day + days,
          Duration.hoursPerDay - 1,
          Duration.minutesPerHour - 1,
        );
        dayWords.add(describeUpcomingTime(moment, now).split(' ').first);
      }

      expect(dayWords.toSet(), hasLength(_weekLength));
      expect(dayWords.first, 'Today');
      expect(dayWords[1], 'Tomorrow');
    }
  });
}
