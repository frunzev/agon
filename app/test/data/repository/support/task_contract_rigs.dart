import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../../screens/support/planned_refusal.dart';
import '../../../screens/support/refusing_work_repositories.dart';
import '../../../support/workflow_repositories.dart';
import '../../node_backed/support/node_backed_harness.dart';
import '../../node_backed/support/simulated_node_replies.dart'
    show buildSimulatedChannel;
import '../../node_backed/support/simulated_work_node.dart';
import '../../node_backed/support/task_repository_rig.dart';
import 'contract_step_failures.dart';
import 'task_contract_nodes.dart';

final class ContractTaskImplementation {
  ContractTaskImplementation({
    required this.name,
    required this.repository,
    required Set<String> seededIdentifiers,
  }) : idsByKey = <String, String>{
         for (final String identifier in seededIdentifiers)
           identifier: identifier,
       };

  final String name;
  final TaskRepository repository;
  final Map<String, String> idsByKey;

  String findKey(String identifier) {
    for (final MapEntry<String, String> entry in idsByKey.entries) {
      if (entry.value == identifier) {
        return entry.key;
      }
    }
    return 'unknown $identifier';
  }

  String resolveKey(String key) => idsByKey[key] ?? key;
}

typedef TaskContractWorld = ({
  RustLikeWorkNode node,
  FakeTaskRepository fake,
  NodeBackedTaskRepository nodeTasks,
  NodeBackedJobRepository nodeJobs,
  List<ContractTaskImplementation> implementations,
});

typedef TaskStep = Future<Object?> Function(
  ContractTaskImplementation implementation,
);

typedef TaskOutcome = ({String name, Object? failure, String? returned});

FakeTaskRepository _buildTwin(NodeBackedTaskRepository source) {
  final List<Run> runs = <Run>[
    for (final Task task in source.listTasks()) ...source.listRuns(task.id),
  ];
  return FakeTaskRepository(
    tasks: source.listTasks(),
    runs: runs,
    clock: FixedClock(DateTime.parse(simulatedMoment)),
    currentDeviceId: const DeviceId(contractDeviceText),
    workflowRepository: buildGalleryWorkflowRepository(),
  );
}

Future<TaskContractWorld> openTaskContractWorld(Random random) async {
  final RustLikeWorkNode node = buildRandomWorkNode(random);
  final WorkspaceRepository workspaces = buildSingleWorkspaceRepository();
  final NodeBackedJobRepository jobs = NodeBackedJobRepository(
    channel: buildSimulatedChannel(node.answer),
    workspaceRepository: workspaces,
    clock: FixedClock(taskRigMoment),
  );
  final NodeBackedTaskRepository nodeTasks = buildRigTaskRepository(
    channel: buildSimulatedChannel(node.answer),
    workspaces: workspaces,
    jobs: jobs,
    livePollInterval: quietLivePollInterval,
  );
  await jobs.load();
  await nodeTasks.load();

  final Set<String> seeded = <String>{
    ...node.work.tasks.keys,
    ...node.work.runs.keys,
  };
  final FakeTaskRepository fake = _buildTwin(nodeTasks);
  return (
    node: node,
    fake: fake,
    nodeTasks: nodeTasks,
    nodeJobs: jobs,
    implementations: <ContractTaskImplementation>[
      ContractTaskImplementation(
        name: 'fake',
        repository: fake,
        seededIdentifiers: seeded,
      ),
      ContractTaskImplementation(
        name: 'node backed',
        repository: nodeTasks,
        seededIdentifiers: seeded,
      ),
      ContractTaskImplementation(
        name: 'refusing double',
        repository: RefusingTaskRepository(
          stored: _buildTwin(nodeTasks),
          refusal: PlannedRefusal(),
        ),
        seededIdentifiers: seeded,
      ),
    ],
  );
}

void closeTaskContractWorld(TaskContractWorld world) {
  world.nodeTasks.dispose();
  world.nodeJobs.dispose();
}

String describeContractTask(
  ContractTaskImplementation implementation,
  Task task,
) {
  return jsonEncode(<Object?>[
    implementation.findKey(task.id.value),
    task.title,
    task.details,
    task.status.name,
    task.projectId.value,
  ]);
}

String describeContractRun(
  ContractTaskImplementation implementation,
  Run run,
) {
  return jsonEncode(<Object?>[
    implementation.findKey(run.id.value),
    implementation.findKey(run.taskId.value),
    run.number,
    run.status.name,
  ]);
}

List<String> describeContractWork(ContractTaskImplementation implementation) {
  final TaskRepository repository = implementation.repository;
  final List<String> descriptions = <String>[];
  for (final Task task in repository.listTasks()) {
    descriptions.add(describeContractTask(implementation, task));
    for (final Run run in repository.listRuns(task.id)) {
      descriptions.add(describeContractRun(implementation, run));
    }
  }
  descriptions.sort();
  return descriptions;
}

String? _describeReturned(
  ContractTaskImplementation implementation,
  Object? returned,
) {
  return switch (returned) {
    Task() => describeContractTask(implementation, returned),
    Run() => describeContractRun(implementation, returned),
    _ => null,
  };
}

Future<TaskOutcome> _runOnTaskRepository(
  ContractTaskImplementation implementation,
  TaskStep step,
) async {
  final Object? returned;
  try {
    returned = await step(implementation);
  } on Object catch (failure) {
    return (name: implementation.name, failure: failure, returned: null);
  }
  return (
    name: implementation.name,
    failure: null,
    returned: _describeReturned(implementation, returned),
  );
}

Future<List<TaskOutcome>> runOnEveryTaskRepository(
  TaskContractWorld world,
  TaskStep step,
) async {
  final List<TaskOutcome> outcomes = <TaskOutcome>[];
  for (final ContractTaskImplementation implementation
      in world.implementations) {
    outcomes.add(await _runOnTaskRepository(implementation, step));
  }
  return outcomes;
}

bool isTaskStepRefused(List<TaskOutcome> outcomes) {
  return outcomes.first.failure != null;
}

void expectTaskOutcomesAgree(List<TaskOutcome> outcomes) {
  final TaskOutcome first = outcomes.first;
  for (final TaskOutcome outcome in outcomes) {
    final Object? failure = outcome.failure;
    final String reason = '${outcome.name}: $failure vs ${first.failure}';
    expect(failure != null, first.failure != null, reason: reason);
    if (failure != null) {
      final bool isExpected =
          isContractRefusal(failure) || failure is RecordNotFound;
      expect(isExpected, isTrue, reason: reason);
    }
    expect(outcome.returned, first.returned, reason: outcome.name);
  }
}

void expectTaskStateAgrees(TaskContractWorld world) {
  final List<String> expected = describeContractWork(
    world.implementations.first,
  );
  for (final ContractTaskImplementation implementation
      in world.implementations) {
    expect(
      describeContractWork(implementation),
      orderedEquals(expected),
      reason: implementation.name,
    );
  }
}
