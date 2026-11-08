import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/notification_counter.dart';
import 'support/chat_repository_rig.dart';
import 'support/task_repository_rig.dart';

const String _typePrefix = 'test_run_source';
const int _worldIterations = 30;
const int _largestMissingNumber = 1 << 30;

typedef _NamedRunSource = ({
  String name,
  RunSource source,
  NotificationCounter notifications,
});

typedef _RunWorld = ({
  List<_NamedRunSource> sources,
  List<RunId> runIds,
  TaskRepositoryRig rig,
});

typedef _RunProjection = ({
  String id,
  String taskId,
  int number,
  RunStatus status,
  int chatLength,
});

Future<_RunWorld> _buildWorld(Random random) async {
  final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
  final RecordedRunSource recorded = RecordedRunSource();
  final List<RunId> runIds = <RunId>[];
  for (final Run run in listEveryListedRun(rig.tasks)) {
    recorded.storeRun(run);
    runIds.add(run.id);
  }
  return (
    sources: <_NamedRunSource>[
      _countNotifications('node backed task repository', rig.tasks),
      _countNotifications('recorded run source', recorded),
    ],
    runIds: runIds,
    rig: rig,
  );
}

_NamedRunSource _countNotifications(String name, RunSource source) {
  final NotificationCounter notifications = NotificationCounter();
  source.addListener(notifications.record);
  return (name: name, source: source, notifications: notifications);
}

_RunProjection _projectRun(Run run) {
  return (
    id: run.id.value,
    taskId: run.taskId.value,
    number: run.number,
    status: run.status,
    chatLength: run.chat.length,
  );
}

RunId _randomMissingRunId(Random random) {
  return RunId('missing-run-${random.nextInt(_largestMissingNumber)}');
}

void main() {
  test('${_typePrefix}_find_run_property_every_source_finds_each_run_'
      'alike', () async {
    final Random random = seededRandom(85101);
    for (int i = 0; i < _worldIterations; i += 1) {
      final _RunWorld world = await _buildWorld(random);

      for (final RunId runId in world.runIds) {
        final _RunProjection expected = _projectRun(
          world.sources.first.source.findRun(runId),
        );
        for (final _NamedRunSource named in world.sources) {
          final Run found = named.source.findRun(runId);
          expect(found.id, runId, reason: named.name);
          expect(_projectRun(found), expected, reason: named.name);
        }
      }
      closeTaskRepositoryRig(world.rig);
    }
  });

  test(
    '${_typePrefix}_find_run_property_unknown_runs_are_not_found',
    () async {
      final Random random = seededRandom(85102);
      for (int i = 0; i < _worldIterations; i += 1) {
        final _RunWorld world = await _buildWorld(random);
        final RunId missing = RunId('absent ${randomText(random)}');

        for (final _NamedRunSource named in world.sources) {
          expect(
            () => named.source.findRun(missing),
            throwsA(
              isA<RecordNotFound>().having(
                (RecordNotFound notFound) => notFound.identifier,
                'identifier',
                missing.value,
              ),
            ),
            reason: named.name,
          );
        }
        closeTaskRepositoryRig(world.rig);
      }
    },
  );

  test('${_typePrefix}_find_run_property_reading_notifies_nobody', () async {
    final Random random = seededRandom(85103);
    for (int i = 0; i < _worldIterations; i += 1) {
      final _RunWorld world = await _buildWorld(random);
      if (world.runIds.isEmpty) {
        closeTaskRepositoryRig(world.rig);
        continue;
      }
      final RunId runId = pickOne(random, world.runIds);

      for (final _NamedRunSource named in world.sources) {
        final int before = named.notifications.count;
        final Run first = named.source.findRun(runId);
        final Run second = named.source.findRun(runId);

        expect(_projectRun(second), _projectRun(first));
        expect(named.notifications.count, before, reason: named.name);
      }
      closeTaskRepositoryRig(world.rig);
    }
  });

  test('${_typePrefix}_refresh_run_property_returns_the_run_it_then_'
      'finds', () async {
    final Random random = seededRandom(85104);
    for (int i = 0; i < _worldIterations; i += 1) {
      final _RunWorld world = await _buildWorld(random);
      if (world.runIds.isEmpty) {
        closeTaskRepositoryRig(world.rig);
        continue;
      }
      final RunId runId = pickOne(random, world.runIds);

      for (final _NamedRunSource named in world.sources) {
        final Run refreshed = await named.source.refreshRun(runId);

        expect(refreshed.id, runId, reason: named.name);
        expect(
          _projectRun(named.source.findRun(runId)),
          _projectRun(refreshed),
          reason: named.name,
        );
      }
      closeTaskRepositoryRig(world.rig);
    }
  });

  test('${_typePrefix}_refresh_run_property_unknown_runs_are_refused_by_'
      'every_source', () async {
    final Random random = seededRandom(85105);
    for (int i = 0; i < _worldIterations; i += 1) {
      final _RunWorld world = await _buildWorld(random);
      final RunId missing = _randomMissingRunId(random);

      for (final _NamedRunSource named in world.sources) {
        await expectLater(
          named.source.refreshRun(missing),
          throwsA(isA<RecordNotFound>()),
          reason: named.name,
        );
      }
      closeTaskRepositoryRig(world.rig);
    }
  });

  test('${_typePrefix}_refresh_run_property_notifies_and_picks_up_changes_'
      'made_elsewhere', () async {
    final Random random = seededRandom(85106);
    for (int i = 0; i < _worldIterations; i += 1) {
      final _RunWorld world = await _buildWorld(random);
      if (world.runIds.isEmpty) {
        closeTaskRepositoryRig(world.rig);
        continue;
      }
      final RunId runId = pickOne(random, world.runIds);
      world.rig.node.changeRunFromElsewhere(random, runId.value);
      final _NamedRunSource nodeBacked = world.sources.first;
      final int before = nodeBacked.notifications.count;

      final Run refreshed = await nodeBacked.source.refreshRun(runId);

      final Map<String, Object?> nodeRun = world.rig.node.runs[runId.value]!;
      expect(
        refreshed.chat.length,
        (nodeRun['chat']! as List<Object?>).length,
      );
      for (final _NamedRunSource named in world.sources) {
        final int countBefore = named == nodeBacked
            ? before
            : named.notifications.count;
        await named.source.refreshRun(runId);
        expect(
          named.notifications.count,
          greaterThan(countBefore),
          reason: named.name,
        );
      }
      closeTaskRepositoryRig(world.rig);
    }
  });
}
