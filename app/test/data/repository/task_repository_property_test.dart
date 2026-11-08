import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import 'support/contract_step_failures.dart';
import 'support/task_contract_checks.dart';
import 'support/task_contract_rigs.dart';
import 'support/task_contract_steps.dart';

const String _typePrefix = 'test_task_repository';

typedef _KeyLookup = Future<Object?> Function(
  ContractTaskImplementation implementation,
  String key,
);

typedef _LookedUpKeys = List<String> Function(
  TaskContractWorld world,
  String doomedTaskKey,
);

Future<void> _expectListingIsUnique(
  TaskContractWorld world,
  ContractTaskImplementation implementation,
) async {
  final List<Task> listed = implementation.repository.listTasks();
  final Set<TaskId> identifiers = <TaskId>{
    for (final Task task in listed) task.id,
  };
  expect(identifiers, hasLength(listed.length), reason: implementation.name);
  for (final Task task in listed) {
    expect(task.schedule, isNull, reason: implementation.name);
  }
}

Future<void> _expectListingIsUnmodifiable(
  TaskContractWorld world,
  ContractTaskImplementation implementation,
) async {
  final List<Task> listed = implementation.repository.listTasks();
  final List<String> before = describeContractWork(implementation);
  final Object? failure = await findStepFailure(() async {
    listed.clear();
  });
  expect(failure, isA<UnsupportedError>(), reason: implementation.name);
  expect(describeContractWork(implementation), before);
}

Future<void> _expectEveryListedTaskIsFound(
  TaskContractWorld world,
  ContractTaskImplementation implementation,
) async {
  for (final Task listed in implementation.repository.listTasks()) {
    final Task found = implementation.repository.findTask(listed.id);
    expect(
      describeContractTask(implementation, found),
      describeContractTask(implementation, listed),
      reason: implementation.name,
    );
  }
}

Future<void> _expectRunsOrderedAndOwned(
  TaskContractWorld world,
  ContractTaskImplementation implementation,
) async {
  for (final Task task in implementation.repository.listTasks()) {
    final List<Run> runs = implementation.repository.listRuns(task.id);
    for (int i = 0; i < runs.length; i += 1) {
      expect(runs[i].taskId, task.id, reason: implementation.name);
      if (i > 0) {
        expect(runs[i].number, lessThan(runs[i - 1].number));
      }
    }
    final int activeCount = runs.where(isRunActive).length;
    expect(activeCount, lessThanOrEqualTo(1), reason: implementation.name);
  }
}

Future<void> _expectEveryListedRunIsFound(
  TaskContractWorld world,
  ContractTaskImplementation implementation,
) async {
  for (final Task task in implementation.repository.listTasks()) {
    for (final Run listed in implementation.repository.listRuns(task.id)) {
      final Run found = implementation.repository.findRun(listed.id);
      expect(
        describeContractRun(implementation, found),
        describeContractRun(implementation, listed),
        reason: implementation.name,
      );
    }
  }
}

Future<void> _expectMissingNotFound(int seed, _KeyLookup find) async {
  final Random random = seededRandom(seed);
  for (int i = 0; i < contractSequenceIterations; i += 1) {
    final TaskContractWorld world = await openTaskWorldAfterRandomSteps(
      random,
    );
    final String key = missingWorkKey(random);
    for (final ContractTaskImplementation implementation
        in world.implementations) {
      final Object? failure = await findStepFailure(
        () => find(implementation, key),
      );
      expect(failure, isA<RecordNotFound>(), reason: implementation.name);
    }
    closeTaskContractWorld(world);
  }
}

Future<Object?> _findTask(
  ContractTaskImplementation implementation,
  String key,
) async {
  final TaskId taskId = TaskId(implementation.resolveKey(key));
  return implementation.repository.findTask(taskId);
}

Future<Object?> _findRun(
  ContractTaskImplementation implementation,
  String key,
) async {
  final RunId runId = RunId(implementation.resolveKey(key));
  return implementation.repository.findRun(runId);
}

List<String> _listDoomedTaskKey(TaskContractWorld world, String doomed) {
  return <String>[doomed];
}

List<String> _listDoomedRunKeys(TaskContractWorld world, String doomed) {
  return <String>[
    for (final Run run in listRunsOfKey(world, doomed))
      world.implementations.first.findKey(run.id.value),
  ];
}

Future<void> _expectDeletedIdleTaskForgotten(
  int seed,
  _KeyLookup find,
  _LookedUpKeys listLookedUpKeys,
) async {
  final Random random = seededRandom(seed);
  int deletedCount = 0;
  for (int i = 0; i < contractSequenceIterations; i += 1) {
    final TaskContractWorld world = await openTaskWorldAfterRandomSteps(
      random,
    );
    final List<String> idle = <String>[
      for (final String key in listTaskKeys(world))
        if (!hasActiveRun(world, findListedTaskByKey(world, key)!)) key,
    ];
    if (idle.isEmpty) {
      closeTaskContractWorld(world);
      continue;
    }
    final String doomed = pickOne(random, idle);
    final List<String> lookedUp = listLookedUpKeys(world, doomed);

    final List<TaskOutcome> outcomes = await performKeyedTaskAction(
      random,
      world,
      action: TaskContractAction.deleteTask,
      key: doomed,
    );

    expectTaskOutcomesAgree(outcomes);
    expect(isTaskStepRefused(outcomes), isFalse);
    deletedCount += 1;
    for (final String key in lookedUp) {
      for (final ContractTaskImplementation implementation
          in world.implementations) {
        final Object? failure = await findStepFailure(
          () => find(implementation, key),
        );
        expect(failure, isA<RecordNotFound>(), reason: implementation.name);
      }
    }
    closeTaskContractWorld(world);
  }
  expect(deletedCount, greaterThan(0));
}

void main() {
  test('${_typePrefix}_list_tasks_property_every_implementation_lists_the_'
      'same_tasks', () async {
    await expectTaskAgreementOn(86601, TaskContractAction.values);
  });

  test('${_typePrefix}_list_tasks_property_lists_each_one_time_task_'
      'once', () async {
    await forEveryTaskImplementation(86602, _expectListingIsUnique);
  });

  test('${_typePrefix}_list_tasks_property_callers_cannot_change_the_'
      'listing', () async {
    await forEveryTaskImplementation(86603, _expectListingIsUnmodifiable);
  });

  test('${_typePrefix}_find_task_property_finds_every_listed_task_'
      'unchanged', () async {
    await forEveryTaskImplementation(86604, _expectEveryListedTaskIsFound);
  });

  test('${_typePrefix}_find_task_property_missing_tasks_are_not_'
      'found', () async {
    await _expectMissingNotFound(86605, _findTask);
  });

  test('${_typePrefix}_find_task_property_deleted_tasks_are_not_'
      'found', () async {
    await _expectDeletedIdleTaskForgotten(
      86606,
      _findTask,
      _listDoomedTaskKey,
    );
  });

  test('${_typePrefix}_list_runs_property_every_implementation_lists_the_'
      'same_runs', () async {
    await expectTaskAgreementOn(86607, const <TaskContractAction>[
      TaskContractAction.startTask,
      TaskContractAction.cancelRun,
      TaskContractAction.retryRun,
    ]);
  });

  test('${_typePrefix}_list_runs_property_newest_first_with_at_most_one_'
      'active_run', () async {
    await forEveryTaskImplementation(86608, _expectRunsOrderedAndOwned);
  });

  test('${_typePrefix}_list_runs_property_unknown_tasks_have_no_'
      'runs', () async {
    final Random random = seededRandom(86609);
    for (int i = 0; i < contractSequenceIterations; i += 1) {
      final TaskContractWorld world = await openTaskWorldAfterRandomSteps(
        random,
      );
      final TaskId missing = TaskId(missingWorkKey(random));
      for (final ContractTaskImplementation implementation
          in world.implementations) {
        expect(
          implementation.repository.listRuns(missing),
          isEmpty,
          reason: implementation.name,
        );
      }
      closeTaskContractWorld(world);
    }
  });

  test('${_typePrefix}_find_run_property_finds_every_listed_run_'
      'unchanged', () async {
    await forEveryTaskImplementation(86610, _expectEveryListedRunIsFound);
  });

  test(
    '${_typePrefix}_find_run_property_missing_runs_are_not_found',
    () async {
      await _expectMissingNotFound(86611, _findRun);
    },
  );

  test('${_typePrefix}_find_run_property_runs_of_deleted_tasks_are_not_'
      'found', () async {
    await _expectDeletedIdleTaskForgotten(86612, _findRun, _listDoomedRunKeys);
  });
}
