import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/screens/workflows.dart';

import '../../data/fakes/support/task_inputs.dart';
import '../../support/random_inputs.dart';
import '../../support/random_scope_catalogs.dart';
import '../../support/random_workflows.dart';
import '../../support/sample_records.dart';

const int _largestWorkspaceCount = 5;
const int _largestListedCount = 8;
const String _namesSeparator = ', ';

List<Workspace> _randomWorkspaces(Random random) {
  final int count = random.nextInt(_largestWorkspaceCount + 1);
  return <Workspace>[
    for (int index = 0; index < count; index += 1)
      buildNamedWorkspace(
        WorkspaceId('workspace-$index'),
        'space-$index-${random.nextInt(99)}',
      ),
  ];
}

List<WorkspaceId> _randomListedIds(Random random, List<Workspace> known) {
  final int count = random.nextInt(_largestListedCount + 1);
  final List<WorkspaceId> listed = <WorkspaceId>[];
  for (int index = 0; index < count; index += 1) {
    final bool isUnknown = known.isEmpty || random.nextInt(4) == 0;
    if (isUnknown) {
      listed.add(WorkspaceId('gone-${random.nextInt(9)}'));
    } else {
      listed.add(pickOne(random, known).id);
    }
  }
  return listed;
}

List<Run> _listRunsOf(List<Run> runs, TaskId taskId) {
  return <Run>[
    for (final Run run in runs)
      if (run.taskId == taskId) run,
  ];
}

List<Run> _listWorkflowRuns(TaskSeed seed, WorkflowId workflowId) {
  final List<Run> workflowRuns = <Run>[];
  for (final Task task in seed.tasks) {
    if (task.doer == WorkflowDoer(workflowId)) {
      workflowRuns.addAll(_listRunsOf(seed.runs, task.id));
    }
  }
  return workflowRuns;
}

DateTime? _findLastUse(TaskSeed seed, WorkflowId workflowId) {
  return findLastWorkflowUse(
    workflowId: workflowId,
    tasks: seed.tasks,
    listRuns: (TaskId taskId) => _listRunsOf(seed.runs, taskId),
  );
}

void main() {
  test('test_describe_availability_property_names_each_workspace_once', () {
    final Random random = seededRandom(12311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workspace> workspaces = _randomWorkspaces(random);
      final List<WorkspaceId> listed = _randomListedIds(random, workspaces);

      final String text = describeAvailability(
        OnlyWorkspaces(listed),
        workspaces,
      );

      final List<String> expectedNames = <String>[];
      for (final WorkspaceId workspaceId in listed.toSet()) {
        for (final Workspace workspace in workspaces) {
          if (workspace.id == workspaceId) {
            expectedNames.add(workspace.name);
          }
        }
      }
      if (expectedNames.isEmpty) {
        expect(text, 'No workspace');
      } else {
        expect(text, expectedNames.join(_namesSeparator));
      }
    }
  });

  test('test_describe_availability_property_all_ignores_the_list', () {
    final Random random = seededRandom(12312);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workspace> workspaces = _randomWorkspaces(random);

      expect(
        describeAvailability(const AllWorkspaces(), workspaces),
        'All workspaces',
      );
    }
  });

  test('test_describe_agent_names_property_agent_order_is_irrelevant', () {
    final Random random = seededRandom(12313);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final List<WorkflowAgent> shuffled = List<WorkflowAgent>.of(
        workflow.agents,
      );
      shuffled.shuffle(random);
      final Workflow reordered = workflow.withGraph(
        agents: shuffled,
        connections: workflow.connections,
      );

      expect(describeAgentNames(reordered), describeAgentNames(workflow));
    }
  });

  test('test_describe_agent_names_property_steps_come_before_followers', () {
    final Random random = seededRandom(12314);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      if (workflow.agents.isEmpty) {
        expect(describeAgentNames(workflow), 'No agents yet');
        continue;
      }

      final List<String> names = describeAgentNames(workflow)
          .split(_namesSeparator);

      expect(names.toSet(), hasLength(workflow.agents.length));
      for (final AgentConnection connection in workflow.connections) {
        final String from = workflow.findAgent(connection.from).name;
        final String to = workflow.findAgent(connection.to).name;
        expect(names.indexOf(from), lessThan(names.indexOf(to)));
      }
    }
  });

  test('test_describe_last_use_property_unused_reads_never_at_any_now', () {
    final Random random = seededRandom(12315);

    for (int i = 0; i < propertyIterations; i += 1) {
      expect(describeLastUse(null, randomUtcMoment(random)), 'Never');
    }
  });

  test('test_describe_last_use_property_recent_use_counts_minutes', () {
    final Random random = seededRandom(12316);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final int minutes = 1 + random.nextInt(Duration.minutesPerHour - 1);
      final DateTime usedAt = now.subtract(Duration(minutes: minutes));

      final String text = describeLastUse(usedAt, now);

      expect(text, '$minutes min ago');
      expect(text, isNot('Never'));
    }
  });

  test('test_find_last_workflow_use_property_is_the_latest_own_start', () {
    final Random random = seededRandom(12317);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final WorkflowId workflowId = pickOne(random, sampleWorkflowIds);
      final List<Run> ownRuns = _listWorkflowRuns(seed, workflowId);

      final DateTime? lastUse = _findLastUse(seed, workflowId);

      if (ownRuns.isEmpty) {
        expect(lastUse, isNull);
        continue;
      }
      final List<DateTime> starts = <DateTime>[
        for (final Run run in ownRuns) run.startedAt,
      ];
      expect(starts, contains(lastUse));
      for (final DateTime start in starts) {
        expect(start.isAfter(lastUse!), isFalse);
      }
    }
  });

  test('test_find_last_workflow_use_property_task_order_is_irrelevant', () {
    final Random random = seededRandom(12318);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskSeed seed = randomTaskSeed(random);
      final WorkflowId workflowId = pickOne(random, sampleWorkflowIds);
      final List<Task> shuffledTasks = List<Task>.of(seed.tasks);
      shuffledTasks.shuffle(random);
      final TaskSeed shuffled = (
        tasks: shuffledTasks,
        runs: seed.runs.reversed.toList(),
      );

      expect(
        _findLastUse(shuffled, workflowId),
        _findLastUse(seed, workflowId),
      );
    }
  });
}
