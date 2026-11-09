import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../support/random_inputs.dart';

const List<RunStatus> _activeStatuses = <RunStatus>[
  RunStatus.queued,
  RunStatus.running,
  RunStatus.waitingForApproval,
];
const int _largestMinutesAhead = 60 * 24 * 9;
final RegExp _clockTime = RegExp(r'\d{2}:\d{2}');

Run _randomActiveRun(Random random) {
  final Run base = pickOne(random, galleryRuns);
  return base.withProgress(
    nextStatus: pickOne(random, _activeStatuses),
    nextSteps: base.steps,
    nextFinishedAt: null,
  );
}

DateTime _randomMomentNextDay(Random random, DateTime moment) {
  final DateTime localMoment = moment.toLocal();
  return DateTime(
    localMoment.year,
    localMoment.month,
    localMoment.day + 1,
    random.nextInt(Duration.hoursPerDay),
    random.nextInt(Duration.minutesPerHour),
  );
}

void main() {
  test('test_describe_start_property_active_yesterday_says_at', () {
    final Random random = seededRandom(615501);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _randomActiveRun(random);
      final DateTime now = _randomMomentNextDay(random, run.startedAt);

      expect(
        describeRunTiming(run, now),
        'started yesterday at ${formatClockTime(run.startedAt)}',
      );
    }
  });

  test('test_describe_start_property_clock_times_follow_at', () {
    final Random random = seededRandom(615502);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _randomActiveRun(random);
      final DateTime now = run.startedAt.add(
        Duration(minutes: random.nextInt(_largestMinutesAhead)),
      );

      final String timing = describeRunTiming(run, now);

      for (final RegExpMatch clock in _clockTime.allMatches(timing)) {
        final String before = timing.substring(0, clock.start);
        expect(before, endsWith(' at '), reason: timing);
      }
    }
  });

  test('test_describe_start_property_start_and_finish_read_alike', () {
    final Random random = seededRandom(615503);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run active = _randomActiveRun(random);
      final DateTime now = _randomMomentNextDay(random, active.startedAt);
      final Run finished = active.withProgress(
        nextStatus: RunStatus.done,
        nextSteps: active.steps,
        nextFinishedAt: active.startedAt,
      );

      final String started = describeRunTiming(active, now);
      final String ended = describeRunTiming(finished, now);

      expect(
        started.replaceFirst('started', ''),
        ended.replaceFirst('finished', ''),
      );
    }
  });
}
