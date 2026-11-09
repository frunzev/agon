import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../support/random_inputs.dart';

const String _justNow = 'Just now';
const int _largestDaysAgo = 400;
const int _latestHourForAheadTests = 12;
const int _hoursAheadAtLeast = 2;
const int _minutesRank = 1;
const int _hoursRank = 100;
const int _yesterdayRank = 10000;
const int _daysRank = 20000;

final RegExp _minutesAgoPattern = RegExp(r'^(\d+) min ago$');
final RegExp _hoursAgoPattern = RegExp(r'^(\d+) h ago$');
final RegExp _daysAgoPattern = RegExp(r'^(\d+) days ago$');

DateTime _shiftCalendarDays(DateTime moment, int days, Random random) {
  return DateTime(
    moment.year,
    moment.month,
    moment.day + days,
    random.nextInt(Duration.hoursPerDay),
    random.nextInt(Duration.minutesPerHour),
  );
}

int _readNumber(RegExp pattern, String phrase) {
  final RegExpMatch? match = pattern.firstMatch(phrase);
  if (match == null) {
    throw StateError('"$phrase" does not match $pattern');
  }
  return int.parse(match.group(1)!);
}

void main() {
  test('test_describe_time_since_property_minute_boundaries', () {
    final Random random = seededRandom(95401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final int wholeMinutes = random.nextInt(Duration.minutesPerHour);
      final Duration age = Duration(
        minutes: wholeMinutes,
        seconds: random.nextInt(Duration.secondsPerMinute),
        milliseconds: random.nextInt(Duration.millisecondsPerSecond),
      );
      final String phrase = describeTimeSince(now.subtract(age), now);

      if (wholeMinutes == 0) {
        expect(phrase, _justNow);
      } else {
        expect(_readNumber(_minutesAgoPattern, phrase), wholeMinutes);
      }
    }
  });

  test('test_describe_time_since_property_older_moments_follow_the_'
      'calendar', () {
    final Random random = seededRandom(95402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final int daysBack = random.nextInt(_largestDaysAgo);
      final DateTime moment = _shiftCalendarDays(now, -daysBack, random);
      final Duration age = now.difference(moment);
      if (age < const Duration(hours: 1)) {
        continue;
      }
      final String phrase = describeTimeSince(moment, now);

      if (daysBack == 0) {
        expect(_readNumber(_hoursAgoPattern, phrase), age.inHours);
      } else if (daysBack == 1) {
        expect(phrase, 'Yesterday ${formatClockTime(moment)}');
      } else {
        expect(_readNumber(_daysAgoPattern, phrase), daysBack);
      }
    }
  });

  test('test_describe_time_since_property_older_never_reads_newer', () {
    final Random random = seededRandom(95403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final DateTime newer = now.subtract(
        Duration(minutes: random.nextInt(Duration.minutesPerDay * 3)),
      );
      final DateTime older = newer.subtract(
        Duration(minutes: random.nextInt(Duration.minutesPerDay * 3)),
      );
      final String newerPhrase = describeTimeSince(newer, now);
      final String olderPhrase = describeTimeSince(older, now);

      expect(
        _rankAge(olderPhrase),
        greaterThanOrEqualTo(_rankAge(newerPhrase)),
        reason: '$olderPhrase vs $newerPhrase',
      );
    }
  });

  test('test_describe_moment_ahead_property_small_clock_skew_reads_just_'
      'now', () {
    final Random random = seededRandom(95404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final DateTime ahead = now.add(
        Duration(milliseconds: random.nextInt(Duration.millisecondsPerMinute)),
      );
      if (countCalendarDaysBetween(now, ahead) != 0) {
        continue;
      }

      expect(describeTimeSince(ahead, now), _justNow);
    }
  });

  test('test_describe_moment_ahead_property_later_today_shows_the_clock', () {
    final Random random = seededRandom(95405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime day = randomLocalMoment(random);
      final int nowHour = random.nextInt(_latestHourForAheadTests);
      final int aheadHour =
          nowHour +
          _hoursAheadAtLeast +
          random.nextInt(Duration.hoursPerDay - nowHour - _hoursAheadAtLeast);
      final DateTime now = DateTime(day.year, day.month, day.day, nowHour);
      final DateTime ahead = DateTime(
        day.year,
        day.month,
        day.day,
        aheadHour,
        random.nextInt(Duration.minutesPerHour),
      );

      expect(describeTimeSince(ahead, now), 'Today ${formatClockTime(ahead)}');
    }
  });

  test('test_describe_moment_ahead_property_another_day_ahead_shows_its_'
      'date', () {
    final Random random = seededRandom(95406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final int daysAhead = 1 + random.nextInt(_largestDaysAgo);
      final DateTime ahead = _shiftCalendarDays(now, daysAhead, random);
      final String phrase = describeTimeSince(ahead, now);

      expect(phrase, isNot(_justNow));
      expect(phrase, isNot(contains('ago')));
      expect(phrase, '${formatCalendarDate(ahead)} ${formatClockTime(ahead)}');
      expect(describeTimeSince(ahead.toUtc(), now), phrase);
    }
  });
}

int _rankAge(String phrase) {
  if (phrase == _justNow) {
    return 0;
  }
  if (_minutesAgoPattern.hasMatch(phrase)) {
    return _minutesRank + _readNumber(_minutesAgoPattern, phrase);
  }
  if (_hoursAgoPattern.hasMatch(phrase)) {
    return _hoursRank + _readNumber(_hoursAgoPattern, phrase);
  }
  if (phrase.startsWith('Yesterday ')) {
    final List<String> clockFields = phrase.split(' ').last.split(':');
    final int minuteOfDay =
        int.parse(clockFields.first) * Duration.minutesPerHour +
        int.parse(clockFields.last);
    return _yesterdayRank + Duration.minutesPerDay - minuteOfDay;
  }
  return _daysRank + _readNumber(_daysAgoPattern, phrase);
}
