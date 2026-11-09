import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/screens/shared/live_run_watch.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/watch_counting_task_repository.dart';

const int _runPoolSize = 3;
const int _repositoryPoolSize = 2;
const int _longestUpdateSequence = 6;
const int _mostWatches = 4;

final List<RunId> _runPool = <RunId>[
  for (int i = 0; i < _runPoolSize; i += 1) RunId('run-$i'),
];

Future<void> _pumpOnDesktop(
  WidgetTester tester,
  Random random,
  Widget child,
) async {
  await pumpScrollableOnPlatform(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    platform: desktopPlatform,
    child: child,
  );
}

LiveRunWatch _buildWatch({
  required RunId runId,
  required WatchCountingTaskRepository repository,
  Key? key,
}) {
  return LiveRunWatch(
    key: key,
    runId: runId,
    taskRepository: repository,
    child: Text('Run ${runId.value}'),
  );
}

void main() {
  testWidgets('test_live_run_watch_dispose_property_leaving_stops_the_'
      'watch', (WidgetTester tester) async {
    final Random random = seededRandom(111901);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunId runId = pickOne(random, _runPool);
      final WatchCountingTaskRepository repository =
          WatchCountingTaskRepository();
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpOnDesktop(
        tester,
        random,
        _buildWatch(runId: runId, repository: repository),
      );

      await tester.pumpWidget(const SizedBox.shrink());

      expect(repository.countWatchers(runId), 0);
      expect(repository.stopCalls, 1);
    }
  });

  testWidgets('test_live_run_watch_dispose_property_every_watch_is_'
      'stopped_after_any_updates', (WidgetTester tester) async {
    final Random random = seededRandom(111902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<WatchCountingTaskRepository> repositories =
          <WatchCountingTaskRepository>[
            for (int j = 0; j < _repositoryPoolSize; j += 1)
              WatchCountingTaskRepository(),
          ];
      await tester.pumpWidget(const SizedBox.shrink());
      final int updateCount = 1 + random.nextInt(_longestUpdateSequence);
      for (int j = 0; j < updateCount; j += 1) {
        await _pumpOnDesktop(
          tester,
          random,
          _buildWatch(
            runId: pickOne(random, _runPool),
            repository: pickOne(random, repositories),
          ),
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());

      for (final WatchCountingTaskRepository repository in repositories) {
        expect(repository.countAllWatchers(), 0);
        expect(repository.stopCalls, repository.watchCalls);
      }
    }
  });

  testWidgets('test_live_run_watch_dispose_property_others_keep_watching_'
      'the_same_run', (WidgetTester tester) async {
    final Random random = seededRandom(111903);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunId runId = pickOne(random, _runPool);
      final WatchCountingTaskRepository repository =
          WatchCountingTaskRepository();
      final int watchCount = 2 + random.nextInt(_mostWatches - 1);
      final int removedIndex = random.nextInt(watchCount);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpOnDesktop(
        tester,
        random,
        Column(
          children: <Widget>[
            for (int j = 0; j < watchCount; j += 1)
              _buildWatch(
                runId: runId,
                repository: repository,
                key: ValueKey<int>(j),
              ),
          ],
        ),
      );

      await _pumpOnDesktop(
        tester,
        random,
        Column(
          children: <Widget>[
            for (int j = 0; j < watchCount; j += 1)
              if (j != removedIndex)
                _buildWatch(
                  runId: runId,
                  repository: repository,
                  key: ValueKey<int>(j),
                ),
          ],
        ),
      );

      expect(repository.countWatchers(runId), watchCount - 1);
      expect(repository.stopCalls, 1);
    }
  });

  test('test_live_run_watch_constructor_property_watches_share_'
      'nothing', () {
    final Random random = seededRandom(111907);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WatchCountingTaskRepository firstRepository =
          WatchCountingTaskRepository();
      final WatchCountingTaskRepository secondRepository =
          WatchCountingTaskRepository();
      final RunId firstRun = pickOne(random, _runPool);
      final RunId secondRun = pickOne(random, _runPool);

      final LiveRunWatch first = _buildWatch(
        runId: firstRun,
        repository: firstRepository,
      );
      final LiveRunWatch second = _buildWatch(
        runId: secondRun,
        repository: secondRepository,
      );

      expect(first.runId, firstRun);
      expect(second.runId, secondRun);
      expect(first.taskRepository, same(firstRepository));
      expect(second.taskRepository, same(secondRepository));
    }
  });

  testWidgets('test_live_run_watch_create_state_property_mounted_state_'
      'reads_its_watch', (WidgetTester tester) async {
    final Random random = seededRandom(111908);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunId runId = pickOne(random, _runPool);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpOnDesktop(
        tester,
        random,
        _buildWatch(runId: runId, repository: WatchCountingTaskRepository()),
      );

      final State<LiveRunWatch> state = tester.state(
        find.byType(LiveRunWatch),
      );

      expect(state.mounted, isTrue);
      expect(state.widget.runId, runId);
    }
  });

  testWidgets('test_live_run_watch_create_state_property_a_new_state_'
      'moves_the_watch', (WidgetTester tester) async {
    final Random random = seededRandom(111909);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunId runId = pickOne(random, _runPool);
      final WatchCountingTaskRepository repository =
          WatchCountingTaskRepository();
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpOnDesktop(
        tester,
        random,
        _buildWatch(runId: runId, repository: repository, key: UniqueKey()),
      );

      await _pumpOnDesktop(
        tester,
        random,
        _buildWatch(runId: runId, repository: repository, key: UniqueKey()),
      );

      expect(repository.countWatchers(runId), 1);
      expect(repository.watchCalls, 2);
      expect(repository.stopCalls, 1);
    }
  });

  testWidgets('test_live_run_watch_build_property_shows_its_child_at_any_'
      'width', (WidgetTester tester) async {
    final Random random = seededRandom(111904);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String childText = 'Child ${randomText(random)}';
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: LiveRunWatch(
          runId: pickOne(random, _runPool),
          taskRepository: WatchCountingTaskRepository(),
          child: Text(childText),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(childText), findsOneWidget);
    }
  });

  testWidgets('test_live_run_watch_build_property_child_is_used_as_'
      'given', (WidgetTester tester) async {
    final Random random = seededRandom(111905);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Widget child = Text('Child ${randomText(random)}');
      await _pumpOnDesktop(
        tester,
        random,
        LiveRunWatch(
          runId: pickOne(random, _runPool),
          taskRepository: WatchCountingTaskRepository(),
          child: child,
        ),
      );

      final Widget shownChild = tester.widget(
        find.descendant(
          of: find.byType(LiveRunWatch),
          matching: find.byType(Text),
        ),
      );

      expect(shownChild, same(child));
    }
  });

  testWidgets('test_live_run_watch_build_property_adds_no_layout_of_its_'
      'own', (WidgetTester tester) async {
    final Random random = seededRandom(111906);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpOnDesktop(
        tester,
        random,
        Center(
          child: LiveRunWatch(
            runId: pickOne(random, _runPool),
            taskRepository: WatchCountingTaskRepository(),
            child: Text('Child ${randomText(random)}'),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(LiveRunWatch)),
        tester.getSize(find.byType(Text)),
      );
    }
  });
}
