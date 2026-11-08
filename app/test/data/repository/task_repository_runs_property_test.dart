import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import 'support/task_contract_checks.dart';
import 'support/task_contract_rigs.dart';
import 'support/task_contract_steps.dart';

const String _typePrefix = 'test_task_repository';
const int _largestWatchSteps = 12;
const List<TaskContractAction> _watchActions = <TaskContractAction>[
  TaskContractAction.watchRun,
  TaskContractAction.stopWatchingRun,
];

List<String> _listRunKeysWhere(
  TaskContractWorld world,
  bool Function(Run run, List<Run> siblings) matches,
) {
  final ContractTaskImplementation first = world.implementations.first;
  final List<String> keys = <String>[];
  for (final Task task in first.repository.listTasks()) {
    final List<Run> siblings = first.repository.listRuns(task.id);
    for (final Run run in siblings) {
      if (matches(run, siblings)) {
        keys.add(first.findKey(run.id.value));
      }
    }
  }
  return keys;
}

bool _isActive(Run run, List<Run> siblings) => isRunActive(run);

bool _isFinished(Run run, List<Run> siblings) => !isRunActive(run);

bool _isRetryable(Run run, List<Run> siblings) {
  final bool isStopped =
      run.status == RunStatus.failed || run.status == RunStatus.cancelled;
  final bool isLatest = siblings.first.id == run.id;
  final bool hasActiveSibling = siblings.any(isRunActive);
  return isStopped && isLatest && !hasActiveSibling;
}

bool _isNotRetryable(Run run, List<Run> siblings) {
  return !_isRetryable(run, siblings);
}

Task _findTaskOfRun(TaskContractWorld world, Run run) {
  return world.implementations.first.repository.findTask(run.taskId);
}

Future<void> _cancelStopsAnActiveRun(
  Random random,
  TaskContractWorld world,
) async {
  final List<String> active = _listRunKeysWhere(world, _isActive);
  if (active.isEmpty) {
    return;
  }
  final String key = pickOne(random, active);

  final List<TaskOutcome> outcomes = await performKeyedTaskAction(
    random,
    world,
    action: TaskContractAction.cancelRun,
    key: key,
  );

  expectTaskOutcomesAgree(outcomes);
  expect(isTaskStepRefused(outcomes), isFalse);
  expectTaskStateAgrees(world);
  final Run cancelled = findListedRunByKey(world, key)!;
  expect(cancelled.status, RunStatus.cancelled);
  expect(_findTaskOfRun(world, cancelled).status, TaskStatus.toDo);
}

Future<void> _cancelRefusesFinishedRuns(
  Random random,
  TaskContractWorld world,
) {
  final List<String> finished = _listRunKeysWhere(world, _isFinished);
  final String key = finished.isEmpty || random.nextInt(4) == 0
      ? missingWorkKey(random)
      : pickOne(random, finished);
  return expectRefusedWithoutChange(
    random,
    world,
    action: TaskContractAction.cancelRun,
    key: key,
  );
}

Future<void> _retryReopensTheLatestStoppedRun(
  Random random,
  TaskContractWorld world,
) async {
  final List<String> retryable = _listRunKeysWhere(world, _isRetryable);
  if (retryable.isEmpty) {
    return;
  }
  final String key = pickOne(random, retryable);

  final List<TaskOutcome> outcomes = await performKeyedTaskAction(
    random,
    world,
    action: TaskContractAction.retryRun,
    key: key,
  );

  expectTaskOutcomesAgree(outcomes);
  expect(isTaskStepRefused(outcomes), isFalse);
  expectTaskStateAgrees(world);
  final Run retried = findListedRunByKey(world, key)!;
  expect(isRunActive(retried), isTrue);
  expect(_findTaskOfRun(world, retried).status, TaskStatus.running);
}

Future<void> _retryRefusesOtherRuns(Random random, TaskContractWorld world) {
  final List<String> refused = _listRunKeysWhere(world, _isNotRetryable);
  final String key = refused.isEmpty || random.nextInt(4) == 0
      ? missingWorkKey(random)
      : pickOne(random, refused);
  return expectRefusedWithoutChange(
    random,
    world,
    action: TaskContractAction.retryRun,
    key: key,
  );
}

Future<void> _watchingNeverThrowsOrChangesWork(
  Random random,
  TaskContractWorld world,
) async {
  final List<String> before = describeContractWork(
    world.implementations.first,
  );
  final int stepCount = 1 + random.nextInt(_largestWatchSteps);

  for (int step = 0; step < stepCount; step += 1) {
    final TaskContractAction action = pickOne(random, _watchActions);
    final List<TaskOutcome> outcomes = await performKeyedTaskAction(
      random,
      world,
      action: action,
      key: pickKeyFor(random, world, action),
    );
    expectTaskOutcomesAgree(outcomes);
    expect(isTaskStepRefused(outcomes), isFalse);
  }

  expect(describeContractWork(world.implementations.first), before);
}

Future<void> _fakeWatchCountsBalance(
  Random random,
  TaskContractWorld world,
) async {
  final RunId runId = RunId(missingWorkKey(random));
  final int watches = 1 + random.nextInt(_largestWatchSteps);
  final int stops = random.nextInt(watches + 2);

  for (int watch = 0; watch < watches; watch += 1) {
    world.fake.watchRun(runId);
    world.nodeTasks.watchRun(runId);
  }
  for (int stop = 0; stop < stops; stop += 1) {
    world.fake.stopWatchingRun(runId);
    world.nodeTasks.stopWatchingRun(runId);
  }

  expect(world.fake.isWatchingRun(runId), stops < watches);
  for (int stop = stops; stop < watches; stop += 1) {
    world.fake.stopWatchingRun(runId);
    world.nodeTasks.stopWatchingRun(runId);
  }
  expect(world.fake.isWatchingRun(runId), isFalse);
}

Future<void> _lastStopTellsTheNode(
  Random random,
  TaskContractWorld world,
) async {
  final RunId runId = RunId(missingWorkKey(random));
  final int watches = 1 + random.nextInt(_largestWatchSteps);
  await letContractTurnsPass();
  final int stopsAtStart = world.node.work.stoppedRuns.length;

  for (int watch = 0; watch < watches; watch += 1) {
    world.nodeTasks.watchRun(runId);
  }
  for (int stop = 0; stop < watches - 1; stop += 1) {
    world.nodeTasks.stopWatchingRun(runId);
  }
  await letContractTurnsPass();
  final int stopsBeforeLast = world.node.work.stoppedRuns.length;
  world.nodeTasks.stopWatchingRun(runId);
  await letContractTurnsPass();

  expect(stopsBeforeLast, stopsAtStart);
  expect(world.node.work.stoppedRuns.sublist(stopsAtStart), <String>[
    runId.value,
  ]);
}

void main() {
  test('${_typePrefix}_cancel_run_property_every_implementation_agrees_on_'
      'the_outcome', () async {
    await expectTaskAgreementOn(86801, const <TaskContractAction>[
      TaskContractAction.cancelRun,
      TaskContractAction.startTask,
    ]);
  });

  test('${_typePrefix}_cancel_run_property_stops_an_active_run', () async {
    await forEachTaskWorld(86802, _cancelStopsAnActiveRun);
  });

  test('${_typePrefix}_cancel_run_property_finished_runs_change_'
      'nothing', () async {
    await forEachTaskWorld(86803, _cancelRefusesFinishedRuns);
  });

  test('${_typePrefix}_retry_run_property_every_implementation_agrees_on_'
      'the_outcome', () async {
    await expectTaskAgreementOn(86804, const <TaskContractAction>[
      TaskContractAction.retryRun,
      TaskContractAction.cancelRun,
      TaskContractAction.startTask,
    ]);
  });

  test('${_typePrefix}_retry_run_property_reopens_only_the_latest_stopped_'
      'run', () async {
    await forEachTaskWorld(86805, _retryReopensTheLatestStoppedRun);
  });

  test(
    '${_typePrefix}_retry_run_property_other_runs_change_nothing',
    () async {
      await forEachTaskWorld(86806, _retryRefusesOtherRuns);
    },
  );

  test('${_typePrefix}_watch_run_property_every_implementation_agrees_on_'
      'the_outcome', () async {
    await expectTaskAgreementOn(86807, _watchActions);
  });

  test('${_typePrefix}_watch_run_property_never_throws_or_changes_'
      'work', () async {
    await forEachTaskWorld(86808, _watchingNeverThrowsOrChangesWork);
  });

  test(
    '${_typePrefix}_watch_run_property_watches_count_until_balanced',
    () async {
      await forEachTaskWorld(86809, _fakeWatchCountsBalance);
    },
  );

  test('${_typePrefix}_stop_watching_run_property_every_implementation_'
      'agrees_on_the_outcome', () async {
    await expectTaskAgreementOn(86810, const <TaskContractAction>[
      TaskContractAction.stopWatchingRun,
      TaskContractAction.watchRun,
      TaskContractAction.startTask,
    ]);
  });

  test('${_typePrefix}_stop_watching_run_property_balanced_stops_end_the_'
      'watch', () async {
    await forEachTaskWorld(86811, _fakeWatchCountsBalance);
  });

  test('${_typePrefix}_stop_watching_run_property_only_the_last_stop_tells_'
      'the_node', () async {
    await forEachTaskWorld(86812, _lastStopTellsTheNode);
  });
}
