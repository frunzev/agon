import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/screens/shared/live_run_watch.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/watch_counting_task_repository.dart';

const int _runPoolSize = 3;
const int _repositoryPoolSize = 2;
const int _largestKeyNumber = 1000;
const int _longestUpdateSequence = 8;

final List<RunId> _runPool = <RunId>[
  for (int i = 0; i < _runPoolSize; i += 1) RunId('run-$i'),
];

LiveRunWatch _buildWatch(RunId runId, TaskRepository repository) {
  return LiveRunWatch(
    runId: runId,
    taskRepository: repository,
    child: Text('Run ${runId.value}'),
  );
}

Future<void> _pumpWatch(
  WidgetTester tester,
  Random random,
  LiveRunWatch watch,
) async {
  await pumpScrollableOnPlatform(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    platform: desktopPlatform,
    child: watch,
  );
}

void _expectOnlyWatching({
  required List<WatchCountingTaskRepository> repositories,
  required WatchCountingTaskRepository watchingRepository,
  required RunId watchedRun,
}) {
  for (final WatchCountingTaskRepository repository in repositories) {
    for (final RunId runId in _runPool) {
      final bool isWatched =
          repository == watchingRepository && runId == watchedRun;
      expect(repository.countWatchers(runId), isWatched ? 1 : 0);
    }
  }
}

void main() {
  test('test_live_run_watch_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(111801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunId runId = pickOne(random, _runPool);
      final WatchCountingTaskRepository repository =
          WatchCountingTaskRepository();
      final Widget child = Text(randomText(random));
      final Key key = ValueKey<int>(random.nextInt(_largestKeyNumber));

      final LiveRunWatch watch = LiveRunWatch(
        runId: runId,
        taskRepository: repository,
        key: key,
        child: child,
      );

      expect(watch.runId, runId);
      expect(watch.taskRepository, same(repository));
      expect(watch.child, same(child));
      expect(watch.key, key);
    }
  });

  test('test_live_run_watch_constructor_property_watches_nothing_yet', () {
    final Random random = seededRandom(111802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WatchCountingTaskRepository repository =
          WatchCountingTaskRepository();

      _buildWatch(pickOne(random, _runPool), repository);

      expect(repository.watchCalls, 0);
      expect(repository.stopCalls, 0);
    }
  });

  test('test_live_run_watch_create_state_property_fresh_state_that_'
      'watches_nothing', () {
    final Random random = seededRandom(111803);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WatchCountingTaskRepository repository =
          WatchCountingTaskRepository();
      final LiveRunWatch watch = _buildWatch(
        pickOne(random, _runPool),
        repository,
      );

      final State<LiveRunWatch> first = watch.createState();
      final State<LiveRunWatch> second = watch.createState();

      expect(first, isNot(same(second)));
      expect(first.mounted, isFalse);
      expect(repository.watchCalls, 0);
    }
  });

  testWidgets('test_live_run_watch_init_state_property_mounting_watches_'
      'once', (WidgetTester tester) async {
    final Random random = seededRandom(111804);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunId runId = pickOne(random, _runPool);
      final WatchCountingTaskRepository repository =
          WatchCountingTaskRepository();
      await tester.pumpWidget(const SizedBox.shrink());

      await _pumpWatch(tester, random, _buildWatch(runId, repository));

      expect(tester.takeException(), isNull);
      expect(repository.watchCalls, 1);
      expect(repository.countWatchers(runId), 1);
      expect(repository.stopCalls, 0);
    }
  });

  testWidgets('test_live_run_watch_init_state_property_each_watch_counts_'
      'once', (WidgetTester tester) async {
    final Random random = seededRandom(111805);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WatchCountingTaskRepository repository =
          WatchCountingTaskRepository();
      final int watchCount = 1 + random.nextInt(_runPoolSize);
      final List<RunId> runIds = <RunId>[
        for (int j = 0; j < watchCount; j += 1) pickOne(random, _runPool),
      ];
      await tester.pumpWidget(const SizedBox.shrink());

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: <Widget>[
              for (final RunId runId in runIds) _buildWatch(runId, repository),
            ],
          ),
        ),
      );

      for (final RunId runId in _runPool) {
        expect(
          repository.countWatchers(runId),
          runIds.where((RunId listed) => listed == runId).length,
        );
      }
    }
  });

  testWidgets('test_live_run_watch_init_state_property_rebuilds_never_'
      'watch_again', (WidgetTester tester) async {
    final Random random = seededRandom(111806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunId runId = pickOne(random, _runPool);
      final WatchCountingTaskRepository repository =
          WatchCountingTaskRepository();
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpWatch(tester, random, _buildWatch(runId, repository));

      await _pumpWatch(tester, random, _buildWatch(runId, repository));
      await _pumpWatch(tester, random, _buildWatch(runId, repository));

      expect(repository.watchCalls, 1);
      expect(repository.stopCalls, 0);
    }
  });

  testWidgets('test_live_run_watch_did_update_widget_property_watches_'
      'exactly_the_shown_run', (WidgetTester tester) async {
    final Random random = seededRandom(111807);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<WatchCountingTaskRepository> repositories =
          <WatchCountingTaskRepository>[
            for (int j = 0; j < _repositoryPoolSize; j += 1)
              WatchCountingTaskRepository(),
          ];
      await tester.pumpWidget(const SizedBox.shrink());
      final int updateCount = 1 + random.nextInt(_longestUpdateSequence);

      for (int j = 0; j < updateCount; j += 1) {
        final RunId runId = pickOne(random, _runPool);
        final WatchCountingTaskRepository repository = pickOne(
          random,
          repositories,
        );
        await _pumpWatch(tester, random, _buildWatch(runId, repository));

        _expectOnlyWatching(
          repositories: repositories,
          watchingRepository: repository,
          watchedRun: runId,
        );
      }
    }
  });

  testWidgets('test_live_run_watch_did_update_widget_property_same_run_'
      'calls_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(111808);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunId runId = pickOne(random, _runPool);
      final WatchCountingTaskRepository repository =
          WatchCountingTaskRepository();
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpWatch(tester, random, _buildWatch(runId, repository));

      await _pumpWatch(
        tester,
        random,
        LiveRunWatch(
          runId: RunId(runId.value),
          taskRepository: repository,
          child: Text(randomText(random)),
        ),
      );

      expect(repository.watchCalls, 1);
      expect(repository.stopCalls, 0);
    }
  });

  testWidgets('test_live_run_watch_did_update_widget_property_switching_'
      'runs_moves_the_watch', (WidgetTester tester) async {
    final Random random = seededRandom(111809);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunId firstRun = _runPool.first;
      final RunId secondRun = pickOne(random, _runPool.sublist(1));
      final WatchCountingTaskRepository repository =
          WatchCountingTaskRepository();
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpWatch(tester, random, _buildWatch(firstRun, repository));

      await _pumpWatch(tester, random, _buildWatch(secondRun, repository));

      expect(repository.countWatchers(firstRun), 0);
      expect(repository.countWatchers(secondRun), 1);
      expect(repository.watchCalls, 2);
      expect(repository.stopCalls, 1);
    }
  });
}
