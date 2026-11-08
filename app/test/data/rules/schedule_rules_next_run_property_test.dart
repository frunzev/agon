import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';

import '../../support/random_inputs.dart';
import 'support/local_clock_changes.dart';
import 'support/schedule_scope_run_tables.dart';

const Duration _oneHour = Duration(hours: 1);

HourlySchedule _randomHourlySchedule(Random random) {
  return HourlySchedule(minute: random.nextInt(Duration.minutesPerHour));
}

DateTime _randomLocalMoment(Random random, List<DateTime> clockChanges) {
  if (random.nextBool()) {
    return randomLocalMoment(random);
  }
  return randomMomentNearClockChange(random, clockChanges);
}

void main() {
  test('test_find_next_run_after_property_matches_the_shared_next_run_'
      'table', () {
    final List<SharedNextRunCase> cases = readSharedNextRunCases();

    for (final SharedNextRunCase sharedCase in cases) {
      final DateTime nextRun = findNextRunAfter(
        sharedCase.schedule,
        sharedCase.after,
      );

      expect(nextRun, sharedCase.next, reason: '${sharedCase.after}');
      expect(nextRun.isUtc, isTrue);
    }
  });

  test('test_find_hour_start_property_hourly_runs_wait_at_most_an_hour', () {
    final Random random = seededRandom(88201);
    final List<DateTime> clockChanges = findLocalClockChanges();

    for (int i = 0; i < propertyIterations * 2; i += 1) {
      final HourlySchedule schedule = _randomHourlySchedule(random);
      final DateTime moment = _randomLocalMoment(random, clockChanges);

      final DateTime nextRun = findNextRunAfter(schedule, moment);

      final Duration wait = nextRun.difference(moment);
      expect(wait > Duration.zero, isTrue, reason: '$moment -> $nextRun');
      expect(wait <= _oneHour, isTrue, reason: '$moment -> $nextRun');
    }
  });

  test('test_find_hour_start_property_hourly_runs_keep_their_local_'
      'minute', () {
    final Random random = seededRandom(88202);
    final List<DateTime> clockChanges = findLocalClockChanges();

    for (int i = 0; i < propertyIterations * 2; i += 1) {
      final HourlySchedule schedule = _randomHourlySchedule(random);
      final DateTime moment = _randomLocalMoment(random, clockChanges);

      final DateTime nextRun = findNextRunAfter(schedule, moment);

      expect(nextRun.minute, schedule.minute, reason: '$moment -> $nextRun');
      expect(nextRun.second, 0);
    }
  });

  test('test_find_hour_start_property_hourly_runs_come_one_hour_apart', () {
    final Random random = seededRandom(88203);
    final List<DateTime> clockChanges = findLocalClockChanges();

    for (int i = 0; i < propertyIterations * 2; i += 1) {
      final HourlySchedule schedule = _randomHourlySchedule(random);
      final DateTime moment = _randomLocalMoment(random, clockChanges);
      final DateTime nextRun = findNextRunAfter(schedule, moment);

      final DateTime runAfterThat = findNextRunAfter(schedule, nextRun);

      expect(runAfterThat.difference(nextRun), _oneHour, reason: '$nextRun');
    }
  });
}
