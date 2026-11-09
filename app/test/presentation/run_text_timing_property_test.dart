import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../support/random_inputs.dart';

const List<RunStatus> _finishedStatuses = <RunStatus>[
  RunStatus.done,
  RunStatus.failed,
  RunStatus.cancelled,
];
const List<RunStatus> _activeStatuses = <RunStatus>[
  RunStatus.queued,
  RunStatus.running,
  RunStatus.waitingForApproval,
];
const int _largestDaysAgo = 400;

Run _finishedRun(Random random, DateTime finishedAt) {
  final Run base = pickOne(random, galleryRuns);
  return base.withProgress(
    nextStatus: pickOne(random, _finishedStatuses),
    nextSteps: base.steps,
    nextFinishedAt: finishedAt,
  );
}

String _verbOf(Run run) {
  return run.status == RunStatus.done ? 'finished' : 'stopped';
}

DateTime _randomMomentOnDay(Random random, DateTime now, int daysBack) {
  return DateTime(
    now.year,
    now.month,
    now.day - daysBack,
    random.nextInt(Duration.hoursPerDay),
    random.nextInt(Duration.minutesPerHour),
  );
}

DateTime _randomEarlierToday(Random random, DateTime now) {
  final int minutesSinceMidnight =
      now.hour * Duration.minutesPerHour + now.minute;
  final int minuteOfDay = random.nextInt(minutesSinceMidnight + 1);
  return DateTime(
    now.year,
    now.month,
    now.day,
    minuteOfDay ~/ Duration.minutesPerHour,
    minuteOfDay % Duration.minutesPerHour,
  );
}

void main() {
  test('test_describe_run_timing_property_today_says_today_at_clock', () {
    final Random random = seededRandom(930601);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final DateTime finishedAt = _randomEarlierToday(random, now);
      final Run run = _finishedRun(random, finishedAt);

      expect(
        describeRunTiming(run, now),
        '${_verbOf(run)} today at ${formatClockTime(finishedAt)}',
      );
    }
  });

  test('test_describe_run_timing_property_yesterday_follows_the_calendar', () {
    final Random random = seededRandom(930602);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final DateTime finishedAt = random.nextBool()
          ? _randomMomentOnDay(random, now, 1)
          : DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(Duration(minutes: 1 + random.nextInt(30)));
      final Run run = _finishedRun(random, finishedAt);

      expect(
        describeRunTiming(run, now),
        '${_verbOf(run)} yesterday at ${formatClockTime(finishedAt)}',
      );
    }
  });

  test('test_describe_run_timing_property_older_runs_count_days', () {
    final Random random = seededRandom(930603);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final int daysBack = 2 + random.nextInt(_largestDaysAgo);
      final DateTime finishedAt = _randomMomentOnDay(random, now, daysBack);
      final Run run = _finishedRun(random, finishedAt);

      expect(
        describeRunTiming(run, now),
        '${_verbOf(run)} $daysBack days ago',
      );
    }
  });

  test('test_describe_run_timing_property_active_runs_ignore_finish', () {
    final Random random = seededRandom(930604);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run base = pickOne(random, galleryRuns);
      final DateTime now = base.startedAt.add(
        Duration(minutes: random.nextInt(60 * 24 * 9)),
      );
      final Run active = base.withProgress(
        nextStatus: pickOne(random, _activeStatuses),
        nextSteps: base.steps,
        nextFinishedAt: null,
      );
      final Run withFinish = active.withProgress(
        nextStatus: active.status,
        nextSteps: active.steps,
        nextFinishedAt: randomLocalMoment(random),
      );

      final String timing = describeRunTiming(active, now);

      expect(describeRunTiming(withFinish, now), timing);
      expect(timing, startsWith('started '));
      expect(timing, isNot(contains('finished')));
      expect(timing, isNot(contains('stopped')));
    }
  });
}
