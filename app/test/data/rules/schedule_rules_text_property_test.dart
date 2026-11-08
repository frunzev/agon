import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

const int _largestTestedNumber = 120;
const List<String> _surroundingWhiteSpace = <String>[
  '',
  ' ',
  '\t',
  '\n',
  '\u00a0',
  '\u2003',
];
final RegExp _clockTextShape = RegExp(r'^\d\d:\d\d$');

ScheduleTime _randomScheduleTime(Random random) {
  return ScheduleTime(
    hour: random.nextInt(Duration.hoursPerDay),
    minute: random.nextInt(Duration.minutesPerHour),
  );
}

int _minuteOfDay(ScheduleTime time) {
  return time.hour * Duration.minutesPerHour + time.minute;
}

String _padClockNumber(int number) => number.toString().padLeft(2, '0');

void main() {
  test('test_format_schedule_time_property_always_two_digit_fields', () {
    final Random random = seededRandom(88301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScheduleTime time = _randomScheduleTime(random);

      final String text = formatScheduleTime(time);

      expect(text, matches(_clockTextShape));
      expect(int.parse(text.substring(0, 2)), time.hour);
      expect(int.parse(text.substring(3)), time.minute);
    }
  });

  test('test_format_schedule_time_property_text_order_is_clock_order', () {
    final Random random = seededRandom(88302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScheduleTime first = _randomScheduleTime(random);
      final ScheduleTime second = _randomScheduleTime(random);

      final int textOrder = formatScheduleTime(first)
          .compareTo(formatScheduleTime(second));

      final int clockOrder = _minuteOfDay(first)
          .compareTo(_minuteOfDay(second));
      expect(textOrder.sign, clockOrder.sign);
    }
  });

  test('test_parse_schedule_time_property_accepts_exactly_real_clock_'
      'times', () {
    final Random random = seededRandom(88303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int hour = random.nextInt(_largestTestedNumber);
      final int minute = random.nextInt(_largestTestedNumber);
      final String text =
          '${_padClockNumber(hour)}:${_padClockNumber(minute)}';

      final ScheduleTime? parsed = parseScheduleTime(text);

      final bool isRealTime =
          hour < Duration.hoursPerDay && minute < Duration.minutesPerHour;
      expect(parsed == null, !isRealTime, reason: text);
      if (parsed != null) {
        expect(<int>[parsed.hour, parsed.minute], <int>[hour, minute]);
      }
    }
  });

  test('test_parse_schedule_time_property_ignores_only_surrounding_white_'
      'space', () {
    final Random random = seededRandom(88304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScheduleTime time = _randomScheduleTime(random);
      final String clock = formatScheduleTime(time);
      final String before = pickOne(random, _surroundingWhiteSpace);
      final String after = pickOne(random, _surroundingWhiteSpace);
      final String noise = randomHostileText(random);

      final ScheduleTime? padded = parseScheduleTime('$before$clock$after');
      final ScheduleTime? withNoise = parseScheduleTime('$clock$noise');

      expect(padded?.hour, time.hour);
      expect(padded?.minute, time.minute);
      if (noise.trim().isNotEmpty) {
        expect(withNoise, isNull, reason: noise);
      }
    }
  });
}
