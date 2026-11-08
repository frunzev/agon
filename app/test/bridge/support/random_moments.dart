import 'dart:math';

import '../../support/random_inputs.dart';

const List<int> _unusualOffsetMinutes = <int>[0, 330, 345, -570, 840, -720];
const int _widestOffsetMinutes = 14 * Duration.minutesPerHour;
const int _offsetMinuteSpan = 2 * _widestOffsetMinutes + 1;
const int _offsetDigitCount = 2;
const String _utcZoneLetter = 'Z';

DateTime randomPreciseUtcMoment(Random random) {
  final Duration fraction = _randomSecondFraction(random);
  return randomUtcMoment(random).add(fraction);
}

DateTime randomPreciseMoment(Random random) {
  if (random.nextBool()) {
    return randomPreciseUtcMoment(random);
  }

  final Duration fraction = _randomSecondFraction(random);
  return randomLocalMoment(random).add(fraction);
}

DateTime? randomOptionalMoment(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return randomPreciseMoment(random);
}

int randomOffsetMinutes(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _unusualOffsetMinutes);
  }
  return random.nextInt(_offsetMinuteSpan) - _widestOffsetMinutes;
}

String textWithoutZone(DateTime utcMoment) {
  final String utcText = utcMoment.toIso8601String();
  if (!utcText.endsWith(_utcZoneLetter)) {
    throw ArgumentError.value(utcMoment, 'utcMoment', 'is not a UTC moment');
  }
  return utcText.substring(0, utcText.length - _utcZoneLetter.length);
}

String textAtOffset(DateTime moment, int offsetMinutes) {
  final Duration offset = Duration(minutes: offsetMinutes);
  final DateTime wallClock = moment.toUtc().add(offset);
  return '${textWithoutZone(wallClock)}${_writeOffset(offsetMinutes)}';
}

String writeMomentWithRandomOffset(Random random, DateTime moment) {
  return textAtOffset(moment, randomOffsetMinutes(random));
}

Duration _randomSecondFraction(Random random) {
  return Duration(
    microseconds: random.nextInt(Duration.microsecondsPerSecond),
  );
}

String _writeOffset(int offsetMinutes) {
  final String sign = offsetMinutes < 0 ? '-' : '+';
  final int magnitude = offsetMinutes.abs();
  final int hours = magnitude ~/ Duration.minutesPerHour;
  final int minutes = magnitude % Duration.minutesPerHour;
  final String hoursText = hours.toString().padLeft(_offsetDigitCount, '0');
  final String minutesText = minutes.toString().padLeft(
    _offsetDigitCount,
    '0',
  );

  return '$sign$hoursText:$minutesText';
}
