import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../../support/random_inputs.dart';
import 'task_contract_rigs.dart';
import 'task_contract_steps.dart';

const int contractSequenceIterations = 25;
const int _settlingTurns = 6;
const int contractLongestSequence = 8;

Future<TaskContractWorld> openTaskWorldAfterRandomSteps(Random random) async {
  final TaskContractWorld world = await openTaskContractWorld(random);
  await performRandomTaskSteps(
    random,
    world,
    stepCount: random.nextInt(contractLongestSequence),
    actions: TaskContractAction.values,
  );
  return world;
}

Future<void> expectTaskAgreementOn(
  int seed,
  List<TaskContractAction> actions,
) async {
  final Random random = seededRandom(seed);
  for (int i = 0; i < contractSequenceIterations; i += 1) {
    final TaskContractWorld world = await openTaskWorldAfterRandomSteps(
      random,
    );
    await performRandomTaskSteps(
      random,
      world,
      stepCount: 1 + random.nextInt(contractLongestSequence),
      actions: actions,
    );
    closeTaskContractWorld(world);
  }
}

Task? findListedTaskByKey(TaskContractWorld world, String key) {
  final ContractTaskImplementation first = world.implementations.first;
  for (final Task task in first.repository.listTasks()) {
    if (first.findKey(task.id.value) == key) {
      return task;
    }
  }
  return null;
}

Run? findListedRunByKey(TaskContractWorld world, String key) {
  final ContractTaskImplementation first = world.implementations.first;
  for (final Task task in first.repository.listTasks()) {
    for (final Run run in first.repository.listRuns(task.id)) {
      if (first.findKey(run.id.value) == key) {
        return run;
      }
    }
  }
  return null;
}

bool hasActiveRun(TaskContractWorld world, Task task) {
  final ContractTaskImplementation first = world.implementations.first;
  return first.repository.listRuns(task.id).any(isRunActive);
}

List<Run> listRunsOfKey(TaskContractWorld world, String taskKey) {
  final Task? task = findListedTaskByKey(world, taskKey);
  if (task == null) {
    return const <Run>[];
  }
  return world.implementations.first.repository.listRuns(task.id);
}

Future<void> expectRefusedWithoutChange(
  Random random,
  TaskContractWorld world, {
  required TaskContractAction action,
  required String key,
}) async {
  final List<String> before = describeContractWork(
    world.implementations.first,
  );

  final List<TaskOutcome> outcomes = await performKeyedTaskAction(
    random,
    world,
    action: action,
    key: key,
  );

  expectTaskOutcomesAgree(outcomes);
  expect(isTaskStepRefused(outcomes), isTrue, reason: '$action $key');
  expectTaskStateAgrees(world);
  expect(describeContractWork(world.implementations.first), before);
}

Future<void> letContractTurnsPass() async {
  for (int turn = 0; turn < _settlingTurns; turn += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

typedef TaskWorldCase = Future<void> Function(
  Random random,
  TaskContractWorld world,
);

typedef TaskImplementationCheck = Future<void> Function(
  TaskContractWorld world,
  ContractTaskImplementation implementation,
);

Future<void> forEachTaskWorld(int seed, TaskWorldCase check) async {
  final Random random = seededRandom(seed);
  for (int i = 0; i < contractSequenceIterations; i += 1) {
    final TaskContractWorld world = await openTaskWorldAfterRandomSteps(
      random,
    );
    await check(random, world);
    closeTaskContractWorld(world);
  }
}

Future<void> forEveryTaskImplementation(
  int seed,
  TaskImplementationCheck check,
) async {
  final Random random = seededRandom(seed);
  for (int i = 0; i < contractSequenceIterations; i += 1) {
    final TaskContractWorld world = await openTaskWorldAfterRandomSteps(
      random,
    );
    for (final ContractTaskImplementation implementation
        in world.implementations) {
      await check(world, implementation);
    }
    closeTaskContractWorld(world);
  }
}
