import 'dart:math';

import '../../../support/random_inputs.dart';

const List<int> _clockChangeYears = <int>[2024, 2025, 2026, 2027];
const int _hoursPerLeapYear = 366 * Duration.hoursPerDay;
const int _minutesAroundClockChange = 3 * Duration.minutesPerHour;
const int _minuteSpan = 2 * _minutesAroundClockChange + 1;

List<DateTime> findLocalClockChanges() {
  final List<DateTime> clockChanges = <DateTime>[];
  for (final int year in _clockChangeYears) {
    final DateTime yearStart = DateTime.utc(year);
    DateTime previous = yearStart.toLocal();
    for (int hour = 1; hour < _hoursPerLeapYear; hour += 1) {
      final DateTime current = yearStart.add(Duration(hours: hour)).toLocal();
      if (current.timeZoneOffset != previous.timeZoneOffset) {
        clockChanges.add(current);
      }
      previous = current;
    }
  }
  return clockChanges;
}

DateTime randomMomentNearClockChange(
  Random random,
  List<DateTime> clockChanges,
) {
  final int shiftInMinutes =
      random.nextInt(_minuteSpan) - _minutesAroundClockChange;
  final DateTime moment = clockChanges.isEmpty
      ? randomLocalMoment(random)
      : pickOne(random, clockChanges);
  final Duration secondFraction = Duration(
    microseconds: random.nextInt(Duration.microsecondsPerMinute),
  );
  return moment.add(Duration(minutes: shiftInMinutes)).add(secondFraction);
}
