import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

import '../../support/random_inputs.dart';
import 'support/task_contract_checks.dart';
import 'support/task_contract_rigs.dart';
import 'support/task_contract_steps.dart';

const String _typePrefix = 'test_task_repository';

List<String> _listKeysWhere(
  TaskContractWorld world,
  bool Function(Task task) matches,
) {
  return <String>[
    for (final String key in listTaskKeys(world))
      if (matches(findListedTaskByKey(world, key)!)) key,
  ];
}

Future<void> _createKeepsTheDraft(
  Random random,
  TaskContractWorld world,
) async {
  final TaskDraft draft = randomContractTaskDraft(random);
  final bool isBlank = trimUnicodeWhiteSpace(draft.title).isEmpty;
  final Set<String> keysBefore = world.implementations.first.idsByKey.keys
      .toSet();

  final List<TaskOutcome> outcomes = await createOnEveryTaskRepository(
    world,
    draft,
  );

  expectTaskOutcomesAgree(outcomes);
  expectTaskStateAgrees(world);
  expect(isTaskStepRefused(outcomes), isBlank);
  final Set<String> newKeys = world.implementations.first.idsByKey.keys
      .toSet()
      .difference(keysBefore);
  expect(newKeys, hasLength(isBlank ? 0 : 1));
  for (final String key in newKeys) {
    final Task? created = findListedTaskByKey(world, key);
    expect(created?.title, draft.title);
    expect(created?.details, draft.details);
    expect(created?.status, TaskStatus.toDo);
    expect(listRunsOfKey(world, key), isEmpty);
  }
}

Future<void> _createRefusesBlankTitles(
  Random random,
  TaskContractWorld world,
) async {
  final TaskDraft draft = randomContractTaskDraft(random);
  final TaskDraft blank = TaskDraft(
    title: pickOne(random, <String>['', ' ', '\n\t', ' ']),
    details: draft.details,
    projectId: draft.projectId,
    doer: draft.doer,
    runsOn: draft.runsOn,
    agentPlace: draft.agentPlace,
    skills: draft.skills,
    usesAutomaticSkills: draft.usesAutomaticSkills,
    approvalPolicy: draft.approvalPolicy,
  );
  final List<String> before = describeContractWork(
    world.implementations.first,
  );

  final List<TaskOutcome> outcomes = await createOnEveryTaskRepository(
    world,
    blank,
  );

  expectTaskOutcomesAgree(outcomes);
  expect(isTaskStepRefused(outcomes), isTrue);
  expectTaskStateAgrees(world);
  expect(describeContractWork(world.implementations.first), before);
}

Future<void> _updateKeepsStatusAndRuns(
  Random random,
  TaskContractWorld world,
) async {
  final List<String> keys = listTaskKeys(world);
  if (keys.isEmpty) {
    return;
  }
  final String key = pickOne(random, keys);
  final Task before = findListedTaskByKey(world, key)!;
  final List<Run> runsBefore = listRunsOfKey(world, key);

  final List<TaskOutcome> outcomes = await performKeyedTaskAction(
    random,
    world,
    action: TaskContractAction.updateTask,
    key: key,
  );

  expectTaskOutcomesAgree(outcomes);
  expectTaskStateAgrees(world);
  final Task after = findListedTaskByKey(world, key)!;
  expect(after.status, before.status);
  expect(after.createdAt, before.createdAt);
  expect(listRunsOfKey(world, key), hasLength(runsBefore.length));
}

Future<void> _startAddsTheNextRun(
  Random random,
  TaskContractWorld world,
) async {
  final List<String> idle = _listKeysWhere(
    world,
    (Task task) => !hasActiveRun(world, task),
  );
  if (idle.isEmpty) {
    return;
  }
  final String key = pickOne(random, idle);
  final List<Run> runsBefore = listRunsOfKey(world, key);
  final int expectedNumber = runsBefore.isEmpty
      ? 1
      : runsBefore.first.number + 1;

  final List<TaskOutcome> outcomes = await startOnEveryTaskRepository(
    world,
    key,
  );

  expectTaskOutcomesAgree(outcomes);
  expect(isTaskStepRefused(outcomes), isFalse);
  expectTaskStateAgrees(world);
  final List<Run> runsAfter = listRunsOfKey(world, key);
  expect(runsAfter, hasLength(runsBefore.length + 1));
  expect(runsAfter.first.number, expectedNumber);
  expect(runsAfter.first.status, RunStatus.queued);
  expect(findListedTaskByKey(world, key)!.status, TaskStatus.running);
}

Future<void> _busyTasksRefuse(
  Random random,
  TaskContractWorld world,
  TaskContractAction action,
) async {
  final List<String> busy = _listKeysWhere(
    world,
    (Task task) => hasActiveRun(world, task),
  );
  final String key = busy.isEmpty
      ? missingWorkKey(random)
      : pickOne(random, busy);
  await expectRefusedWithoutChange(random, world, action: action, key: key);
}

Future<void> _startRefusesBusyTasks(Random random, TaskContractWorld world) {
  return _busyTasksRefuse(random, world, TaskContractAction.startTask);
}

Future<void> _deleteRefusesBusyTasks(Random random, TaskContractWorld world) {
  return _busyTasksRefuse(random, world, TaskContractAction.deleteTask);
}

Future<void> _updateRefusesMissingTasks(
  Random random,
  TaskContractWorld world,
) {
  return expectRefusedWithoutChange(
    random,
    world,
    action: TaskContractAction.updateTask,
    key: missingWorkKey(random),
  );
}

Future<void> _deleteRemovesTheTaskAndItsRuns(
  Random random,
  TaskContractWorld world,
) async {
  final List<String> idle = _listKeysWhere(
    world,
    (Task task) => !hasActiveRun(world, task),
  );
  if (idle.isEmpty) {
    return;
  }
  final String key = pickOne(random, idle);
  final List<String> expected = <String>[
    for (final String listed in listTaskKeys(world))
      if (listed != key) listed,
  ];

  final List<TaskOutcome> outcomes = await performKeyedTaskAction(
    random,
    world,
    action: TaskContractAction.deleteTask,
    key: key,
  );

  expectTaskOutcomesAgree(outcomes);
  expect(isTaskStepRefused(outcomes), isFalse);
  expectTaskStateAgrees(world);
  expect(listTaskKeys(world).toSet(), expected.toSet());
}

void main() {
  test('${_typePrefix}_create_task_property_every_implementation_agrees_on_'
      'the_outcome', () async {
    await expectTaskAgreementOn(86701, const <TaskContractAction>[
      TaskContractAction.createTask,
    ]);
  });

  test('${_typePrefix}_create_task_property_lists_the_new_task_with_its_'
      'draft', () async {
    await forEachTaskWorld(86702, _createKeepsTheDraft);
  });

  test('${_typePrefix}_create_task_property_blank_titles_change_'
      'nothing', () async {
    await forEachTaskWorld(86703, _createRefusesBlankTitles);
  });

  test('${_typePrefix}_update_task_property_every_implementation_agrees_on_'
      'the_outcome', () async {
    await expectTaskAgreementOn(86704, const <TaskContractAction>[
      TaskContractAction.updateTask,
    ]);
  });

  test('${_typePrefix}_update_task_property_keeps_status_and_runs', () async {
    await forEachTaskWorld(86705, _updateKeepsStatusAndRuns);
  });

  test('${_typePrefix}_update_task_property_missing_tasks_change_'
      'nothing', () async {
    await forEachTaskWorld(86706, _updateRefusesMissingTasks);
  });

  test('${_typePrefix}_start_task_property_every_implementation_agrees_on_'
      'the_outcome', () async {
    await expectTaskAgreementOn(86707, const <TaskContractAction>[
      TaskContractAction.startTask,
      TaskContractAction.cancelRun,
    ]);
  });

  test(
    '${_typePrefix}_start_task_property_adds_the_next_queued_run',
    () async {
      await forEachTaskWorld(86708, _startAddsTheNextRun);
    },
  );

  test(
    '${_typePrefix}_start_task_property_busy_tasks_change_nothing',
    () async {
      await forEachTaskWorld(86709, _startRefusesBusyTasks);
    },
  );

  test('${_typePrefix}_delete_task_property_every_implementation_agrees_on_'
      'the_outcome', () async {
    await expectTaskAgreementOn(86710, const <TaskContractAction>[
      TaskContractAction.deleteTask,
      TaskContractAction.cancelRun,
    ]);
  });

  test(
    '${_typePrefix}_delete_task_property_removes_exactly_the_task',
    () async {
      await forEachTaskWorld(86711, _deleteRemovesTheTaskAndItsRuns);
    },
  );

  test(
    '${_typePrefix}_delete_task_property_busy_tasks_change_nothing',
    () async {
      await forEachTaskWorld(86712, _deleteRefusesBusyTasks);
    },
  );
}
