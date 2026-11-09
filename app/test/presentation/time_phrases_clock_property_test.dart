import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../support/random_inputs.dart';

const int _clockFieldWidth = 2;
const int _firstTwoDigitValue = 10;

const List<String> _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

List<int> _readClockFields(String clock) {
  final List<int> fields = <int>[];
  for (final String field in clock.split(':')) {
    fields.add(int.parse(field));
  }
  return fields;
}

DateTime _sameMinuteLater(DateTime moment, Random random) {
  return DateTime(
    moment.year,
    moment.month,
    moment.day,
    moment.hour,
    moment.minute,
    random.nextInt(Duration.secondsPerMinute),
    random.nextInt(Duration.millisecondsPerSecond),
    random.nextInt(Duration.microsecondsPerMillisecond),
  );
}

void main() {
  test('test_pad_clock_field_property_every_field_has_two_digits', () {
    for (int hour = 0; hour < Duration.hoursPerDay; hour += 1) {
      for (int minute = 0; minute < Duration.minutesPerHour; minute += 1) {
        final DateTime moment = DateTime.utc(
          2026,
          1,
          15,
          hour,
          minute,
          minute,
        );
        final String logTime = formatLogTime(moment);

        for (final String field in logTime.split(':')) {
          expect(field, hasLength(_clockFieldWidth), reason: logTime);
        }
      }
    }
  });

  test('test_pad_clock_field_property_leading_zero_only_below_ten', () {
    final Random random = seededRandom(95601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomUtcMoment(random).toLocal();
      final List<String> fields = formatLogTime(moment).split(':');
      final List<int> values = <int>[
        moment.hour,
        moment.minute,
        moment.second,
      ];

      for (int index = 0; index < fields.length; index += 1) {
        final bool startsWithZero = fields[index].startsWith('0');
        expect(startsWithZero, values[index] < _firstTwoDigitValue);
      }
    }
  });

  test('test_pad_clock_field_property_padding_keeps_the_number', () {
    final Random random = seededRandom(95602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomUtcMoment(random);
      final DateTime localMoment = moment.toLocal();

      expect(_readClockFields(formatLogTime(moment)), <int>[
        localMoment.hour,
        localMoment.minute,
        localMoment.second,
      ]);
    }
  });

  test('test_format_clock_time_property_reads_back_local_hour_and_'
      'minute', () {
    final Random random = seededRandom(95603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomUtcMoment(random);
      final DateTime localMoment = moment.toLocal();

      expect(_readClockFields(formatClockTime(moment)), <int>[
        localMoment.hour,
        localMoment.minute,
      ]);
    }
  });

  test('test_format_clock_time_property_seconds_never_change_it', () {
    final Random random = seededRandom(95604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomLocalMoment(random);

      expect(
        formatClockTime(_sameMinuteLater(moment, random)),
        formatClockTime(moment),
      );
    }
  });

  test('test_format_log_time_property_sub_seconds_never_change_it', () {
    final Random random = seededRandom(95605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomLocalMoment(random);
      final DateTime sameSecond = moment.add(
        Duration(microseconds: random.nextInt(Duration.microsecondsPerSecond)),
      );

      expect(formatLogTime(sameSecond), formatLogTime(moment));
      expect(formatLogTime(sameSecond.toUtc()), formatLogTime(moment));
    }
  });

  test('test_format_log_time_property_seconds_step_by_one', () {
    final Random random = seededRandom(95606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomUtcMoment(random);
      final List<int> before = _readClockFields(formatLogTime(moment));
      final List<int> after = _readClockFields(
        formatLogTime(moment.add(const Duration(seconds: 1))),
      );

      expect(after.last, (before.last + 1) % Duration.secondsPerMinute);
    }
  });

  test('test_format_calendar_date_property_reads_back_the_local_day', () {
    final Random random = seededRandom(95607);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomUtcMoment(random);
      final DateTime localMoment = moment.toLocal();
      final List<String> parts = formatCalendarDate(moment).split(' ');

      expect(parts, hasLength(3));
      expect(int.parse(parts[0]), localMoment.day);
      expect(_monthNames.indexOf(parts[1]) + 1, localMoment.month);
      expect(int.parse(parts[2]), localMoment.year);
    }
  });

  test('test_format_calendar_date_property_same_day_same_text', () {
    final Random random = seededRandom(95608);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime day = randomLocalMoment(random);
      final DateTime start = DateTime(day.year, day.month, day.day);
      final DateTime end = DateTime(day.year, day.month, day.day, 23, 59, 59);
      final DateTime nextDay = DateTime(day.year, day.month, day.day + 1);

      expect(formatCalendarDate(day), formatCalendarDate(start));
      expect(formatCalendarDate(end), formatCalendarDate(start));
      expect(formatCalendarDate(nextDay), isNot(formatCalendarDate(start)));
    }
  });
}
