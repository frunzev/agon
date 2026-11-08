import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../../support/random_inputs.dart';
import '../../node_backed/support/node_backed_harness.dart';
import 'task_contract_rigs.dart';

const String _missingPrefix = 'missing-';
const String _createdTaskPrefix = 'created-task-';
const String _startedRunPrefix = 'started-run-';
const int _largestMissingNumber = 1 << 30;
const List<String> _blankTitles = <String>['', ' ', '\t\n', '  '];

enum TaskContractAction {
  createTask,
  updateTask,
  startTask,
  cancelRun,
  retryRun,
  deleteTask,
  watchRun,
  stopWatchingRun,
}

String missingWorkKey(Random random) {
  return '$_missingPrefix${random.nextInt(_largestMissingNumber)}';
}

List<String> listTaskKeys(TaskContractWorld world) {
  final ContractTaskImplementation first = world.implementations.first;
  return <String>[
    for (final Task task in first.repository.listTasks())
      first.findKey(task.id.value),
  ];
}

List<String> listRunKeys(TaskContractWorld world) {
  final ContractTaskImplementation first = world.implementations.first;
  return <String>[
    for (final Task task in first.repository.listTasks())
      for (final Run run in first.repository.listRuns(task.id))
        first.findKey(run.id.value),
  ];
}

String pickKey(Random random, List<String> keys) {
  if (keys.isEmpty || random.nextInt(5) == 0) {
    return missingWorkKey(random);
  }
  return pickOne(random, keys);
}

TaskDraft randomContractTaskDraft(Random random) {
  final TaskDraft draft = randomTaskDraft(random);
  final bool isBlank = random.nextInt(4) == 0;
  return TaskDraft(
    title: isBlank ? pickOne(random, _blankTitles) : draft.title,
    details: draft.details,
    projectId: draft.projectId,
    doer: OneAgentDoer(pickOne(random, AgentKind.values)),
    runsOn: draft.runsOn,
    agentPlace: draft.agentPlace,
    skills: draft.skills,
    usesAutomaticSkills: draft.usesAutomaticSkills,
    approvalPolicy: draft.approvalPolicy,
  );
}

String _nextKey(TaskContractWorld world, String prefix) {
  final int count = world.implementations.first.idsByKey.length;
  return '$prefix$count';
}

Future<Task> _createAndRemember(
  ContractTaskImplementation implementation,
  TaskDraft draft,
  String key,
) async {
  final Task created = await implementation.repository.createTask(draft);
  implementation.idsByKey[key] = created.id.value;
  return created;
}

Future<Run> _startAndRemember(
  ContractTaskImplementation implementation,
  String taskKey,
  String runKey,
) async {
  final TaskId taskId = TaskId(implementation.resolveKey(taskKey));
  final Run started = await implementation.repository.startTask(taskId);
  implementation.idsByKey[runKey] = started.id.value;
  return started;
}

Future<Task> _update(
  ContractTaskImplementation implementation,
  String key,
  TaskDraft draft,
) {
  final TaskId taskId = TaskId(implementation.resolveKey(key));
  return implementation.repository.updateTask(taskId, draft);
}

Future<void> _delete(ContractTaskImplementation implementation, String key) {
  final TaskId taskId = TaskId(implementation.resolveKey(key));
  return implementation.repository.deleteTask(taskId);
}

Future<Run> _cancel(ContractTaskImplementation implementation, String key) {
  final RunId runId = RunId(implementation.resolveKey(key));
  return implementation.repository.cancelRun(runId);
}

Future<Run> _retry(ContractTaskImplementation implementation, String key) {
  final RunId runId = RunId(implementation.resolveKey(key));
  return implementation.repository.retryRun(runId);
}

Future<void> _watch(
  ContractTaskImplementation implementation,
  String key,
) async {
  implementation.repository.watchRun(RunId(implementation.resolveKey(key)));
}

Future<void> _stopWatching(
  ContractTaskImplementation implementation,
  String key,
) async {
  final RunId runId = RunId(implementation.resolveKey(key));
  implementation.repository.stopWatchingRun(runId);
}

Future<List<TaskOutcome>> createOnEveryTaskRepository(
  TaskContractWorld world,
  TaskDraft draft,
) {
  final String key = _nextKey(world, _createdTaskPrefix);
  return runOnEveryTaskRepository(
    world,
    (ContractTaskImplementation implementation) =>
        _createAndRemember(implementation, draft, key),
  );
}

Future<List<TaskOutcome>> startOnEveryTaskRepository(
  TaskContractWorld world,
  String taskKey,
) {
  final String runKey = _nextKey(world, _startedRunPrefix);
  return runOnEveryTaskRepository(
    world,
    (ContractTaskImplementation implementation) =>
        _startAndRemember(implementation, taskKey, runKey),
  );
}

Future<List<TaskOutcome>> performKeyedTaskAction(
  Random random,
  TaskContractWorld world, {
  required TaskContractAction action,
  required String key,
}) {
  final TaskDraft draft = randomContractTaskDraft(random);
  return switch (action) {
    TaskContractAction.createTask => createOnEveryTaskRepository(world, draft),
    TaskContractAction.startTask => startOnEveryTaskRepository(world, key),
    TaskContractAction.updateTask => runOnEveryTaskRepository(
      world,
      (ContractTaskImplementation implementation) =>
          _update(implementation, key, draft),
    ),
    TaskContractAction.deleteTask => runOnEveryTaskRepository(
      world,
      (ContractTaskImplementation implementation) =>
          _delete(implementation, key),
    ),
    TaskContractAction.cancelRun => runOnEveryTaskRepository(
      world,
      (ContractTaskImplementation implementation) =>
          _cancel(implementation, key),
    ),
    TaskContractAction.retryRun => runOnEveryTaskRepository(
      world,
      (ContractTaskImplementation implementation) =>
          _retry(implementation, key),
    ),
    TaskContractAction.watchRun => runOnEveryTaskRepository(
      world,
      (ContractTaskImplementation implementation) =>
          _watch(implementation, key),
    ),
    TaskContractAction.stopWatchingRun => runOnEveryTaskRepository(
      world,
      (ContractTaskImplementation implementation) =>
          _stopWatching(implementation, key),
    ),
  };
}

bool isRunAction(TaskContractAction action) {
  return action == TaskContractAction.cancelRun ||
      action == TaskContractAction.retryRun ||
      action == TaskContractAction.watchRun ||
      action == TaskContractAction.stopWatchingRun;
}

String pickKeyFor(
  Random random,
  TaskContractWorld world,
  TaskContractAction action,
) {
  if (isRunAction(action)) {
    return pickKey(random, listRunKeys(world));
  }
  return pickKey(random, listTaskKeys(world));
}

Future<void> performRandomTaskSteps(
  Random random,
  TaskContractWorld world, {
  required int stepCount,
  required List<TaskContractAction> actions,
}) async {
  for (int step = 0; step < stepCount; step += 1) {
    final TaskContractAction action = pickOne(random, actions);
    final List<TaskOutcome> outcomes = await performKeyedTaskAction(
      random,
      world,
      action: action,
      key: pickKeyFor(random, world, action),
    );
    expectTaskOutcomesAgree(outcomes);
    expectTaskStateAgrees(world);
  }
}
