import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import 'support/run_page_retry_harness.dart';

const int _mostNewerRuns = 3;
const List<RunId> _stoppableRunIds = <RunId>[
  GalleryRunIds.release41,
  GalleryRunIds.release42,
];

Future<Run> _stopRun(TaskRepository tasks, RunId runId) async {
  final Run run = tasks.findRun(runId);
  if (!isRunActive(run)) {
    return run;
  }
  return tasks.cancelRun(runId);
}

Future<List<Run>> _stopNewerRuns(
  TaskRepository tasks,
  TaskId taskId,
  int newerRunCount,
) async {
  final List<Run> newerRuns = <Run>[];
  for (int i = 0; i < newerRunCount; i += 1) {
    final Run started = await tasks.startTask(taskId);
    newerRuns.add(await tasks.cancelRun(started.id));
  }
  return newerRuns;
}

Future<List<Run>> _prepareStoppedRuns(
  Random random,
  TaskRepository tasks,
) async {
  final RunId firstRunId = pickOne(random, _stoppableRunIds);
  final Run firstRun = await _stopRun(tasks, firstRunId);
  final int newerRunCount = 1 + random.nextInt(_mostNewerRuns);
  final List<Run> newerRuns = await _stopNewerRuns(
    tasks,
    firstRun.taskId,
    newerRunCount,
  );
  return <Run>[firstRun, ...newerRuns];
}

void main() {
  testWidgets('test_offer_retry_property_an_older_run_never_offers_retry', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(91301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final TaskRepository tasks = dependencies.taskRepository;
      final List<Run> stoppedRuns = await _prepareStoppedRuns(random, tasks);
      final List<Run> olderRuns = stoppedRuns.sublist(
        0,
        stoppedRuns.length - 1,
      );
      final Run shownRun = pickOne(random, olderRuns);

      await openRunPage(
        tester,
        random: random,
        dependencies: dependencies,
        runId: shownRun.id,
      );

      expect(tester.takeException(), isNull);
      expect(findAppButton(retryButtonLabel), findsOneWidget);
      expect(isRetryOffered(tester), isFalse);
    }
  });

  testWidgets('test_offer_retry_property_only_the_latest_run_offers_retry', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(91302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final TaskRepository tasks = dependencies.taskRepository;
      final List<Run> stoppedRuns = await _prepareStoppedRuns(random, tasks);
      final Run shownRun = pickOne(random, stoppedRuns);
      final int latestNumber = stoppedRuns.last.number;

      await openRunPage(
        tester,
        random: random,
        dependencies: dependencies,
        runId: shownRun.id,
      );

      expect(tester.takeException(), isNull);
      expect(isRetryOffered(tester), shownRun.number == latestNumber);
    }
  });

  testWidgets('test_offer_retry_property_tapping_an_older_run_changes_'
      'nothing', (WidgetTester tester) async {
    final Random random = seededRandom(91303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final TaskRepository tasks = dependencies.taskRepository;
      final List<Run> stoppedRuns = await _prepareStoppedRuns(random, tasks);
      final Run shownRun = stoppedRuns.first;
      final TaskId taskId = shownRun.taskId;
      await openRunPage(
        tester,
        random: random,
        dependencies: dependencies,
        runId: shownRun.id,
      );
      final RunStatusSnapshot statusesBefore = snapshotRunStatuses(
        tasks,
        taskId,
      );
      final TaskStatus taskStatusBefore = tasks.findTask(taskId).status;

      await tapAppButton(tester, retryButtonLabel);

      expect(tester.takeException(), isNull);
      expect(snapshotRunStatuses(tasks, taskId), statusesBefore);
      expect(tasks.findTask(taskId).status, taskStatusBefore);
      expect(findAppButton(closeButtonLabel), findsNothing);
    }
  });
}
