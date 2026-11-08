import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/notification_counter.dart';
import 'support/chat_repository_rig.dart';

const String _typePrefix = 'test_recorded_run_source_refresh_run';
const String _missingRunPrefix = 'missing-run-';
const int _largestRefreshCount = 6;
const int _largestStoredRunCount = 4;
const int _missingRunNumberSpan = 1000;

RecordedRunSource _sourceWithRandomRuns(Random random) {
  final RecordedRunSource source = RecordedRunSource();
  final int count = 1 + random.nextInt(_largestStoredRunCount);
  for (int i = 0; i < count; i += 1) {
    source.storeRun(randomMappedRun(random));
  }
  return source;
}

RunId _missingRunId(Random random) {
  return RunId('$_missingRunPrefix${random.nextInt(_missingRunNumberSpan)}');
}

void main() {
  test('${_typePrefix}_property_unknown_run_is_refused_silently', () async {
    final Random random = seededRandom(88301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordedRunSource source = _sourceWithRandomRuns(random);
      final NotificationCounter notifications = NotificationCounter();
      source.addListener(notifications.record);
      final RunId runId = _missingRunId(random);

      await expectLater(
        source.refreshRun(runId),
        throwsA(isA<RecordNotFound>()),
      );

      expect(notifications.count, 0);
    }
  });

  test('${_typePrefix}_property_known_run_is_returned_and_notified', () async {
    final Random random = seededRandom(88302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordedRunSource source = _sourceWithRandomRuns(random);
      final NotificationCounter notifications = NotificationCounter();
      source.addListener(notifications.record);
      final Run stored = pickOne(random, source.runs.values.toList());

      final Run refreshed = await source.refreshRun(stored.id);

      expect(identical(refreshed, stored), isTrue);
      expect(notifications.count, 1);
    }
  });

  test('${_typePrefix}_property_notifies_once_per_known_refresh', () async {
    final Random random = seededRandom(88303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordedRunSource source = _sourceWithRandomRuns(random);
      final NotificationCounter notifications = NotificationCounter();
      source.addListener(notifications.record);
      final List<RunId> knownRunIds = source.runs.keys.toList();
      final List<RunId> requested = <RunId>[];
      int knownRefreshCount = 0;

      final int refreshCount = random.nextInt(_largestRefreshCount);
      for (int refresh = 0; refresh < refreshCount; refresh += 1) {
        final bool isKnown = random.nextBool();
        final RunId runId = isKnown
            ? pickOne(random, knownRunIds)
            : _missingRunId(random);
        requested.add(runId);
        if (isKnown) {
          knownRefreshCount += 1;
          await source.refreshRun(runId);
        } else {
          await expectLater(source.refreshRun(runId), throwsA(anything));
        }
      }

      expect(source.refreshedRunIds, requested);
      expect(notifications.count, knownRefreshCount);
    }
  });
}
