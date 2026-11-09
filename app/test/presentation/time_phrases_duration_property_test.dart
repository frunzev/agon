import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../support/random_inputs.dart';

const int _longestDurationSeconds = 50000;

final RegExp _stepDurationPattern = RegExp(r'^(?:(\d+) min)? ?(?:(\d+) s)?$');
final RegExp _wholeMinutesPattern = RegExp(r'^(\d+) min$');

int _readStepDurationSeconds(String phrase) {
  final RegExpMatch? match = _stepDurationPattern.firstMatch(phrase);
  if (match == null || phrase.isEmpty) {
    throw StateError('"$phrase" is not a step duration');
  }
  final int minutes = int.parse(match.group(1) ?? '0');
  final int seconds = int.parse(match.group(2) ?? '0');
  return minutes * Duration.secondsPerMinute + seconds;
}

int _readWholeMinutes(String phrase) {
  final RegExpMatch? match = _wholeMinutesPattern.firstMatch(phrase);
  if (match == null) {
    throw StateError('"$phrase" is not a whole minutes phrase');
  }
  return int.parse(match.group(1)!);
}

Duration _randomDuration(Random random) {
  return Duration(
    seconds: random.nextInt(_longestDurationSeconds),
    microseconds: random.nextInt(Duration.microsecondsPerSecond),
  );
}

void main() {
  test('test_describe_step_duration_property_negative_reads_zero', () {
    final Random random = seededRandom(95701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Duration negative = -_randomDuration(random);
      final String phrase = describeStepDuration(negative);

      expect(phrase, isNot(contains('-')));
      expect(phrase, describeStepDuration(Duration.zero));
    }
  });

  test('test_describe_step_duration_property_longer_never_reads_'
      'shorter', () {
    final Random random = seededRandom(95702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Duration shorter = _randomDuration(random);
      final Duration longer = shorter + _randomDuration(random);

      expect(
        _readStepDurationSeconds(describeStepDuration(longer)),
        greaterThanOrEqualTo(
          _readStepDurationSeconds(describeStepDuration(shorter)),
        ),
      );
    }
  });

  test('test_describe_step_duration_property_drops_parts_of_a_second', () {
    final Random random = seededRandom(95703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Duration duration = _randomDuration(random);
      final Duration wholeSeconds = Duration(seconds: duration.inSeconds);

      expect(
        describeStepDuration(duration),
        describeStepDuration(wholeSeconds),
      );
      expect(
        _readStepDurationSeconds(describeStepDuration(duration)),
        duration.inSeconds,
      );
    }
  });

  test('test_describe_whole_minutes_property_negative_reads_one_minute', () {
    final Random random = seededRandom(95704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Duration negative = -_randomDuration(random);

      expect(describeWholeMinutes(negative), '1 min');
    }
  });

  test('test_describe_whole_minutes_property_longer_never_reads_'
      'shorter', () {
    final Random random = seededRandom(95705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Duration shorter = _randomDuration(random);
      final Duration longer = shorter + _randomDuration(random);

      expect(
        _readWholeMinutes(describeWholeMinutes(longer)),
        greaterThanOrEqualTo(_readWholeMinutes(describeWholeMinutes(shorter))),
      );
    }
  });

  test('test_describe_whole_minutes_property_seconds_inside_a_minute_'
      'never_change_it', () {
    final Random random = seededRandom(95706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int minutes = random.nextInt(_longestDurationSeconds);
      final Duration start = Duration(minutes: minutes);
      final Duration inside =
          start +
          Duration(
            milliseconds: random.nextInt(Duration.millisecondsPerMinute),
          );

      expect(describeWholeMinutes(inside), describeWholeMinutes(start));
    }
  });
}
