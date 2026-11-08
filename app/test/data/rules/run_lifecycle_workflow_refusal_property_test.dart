import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import '../../support/sample_records.dart';
import '../fakes/support/startable_drafts.dart';

const int _largestRunNumber = 500;

Task _randomTaskWithDoer(Random random, TaskDoer doer) {
  return Task.fromDraft(
    id: TaskId('task-${randomText(random)}'),
    draft: replaceDraftDoer(randomTaskDraft(random), doer),
    schedule: random.nextBool() ? randomJobSchedule(random) : null,
    status: TaskStatus.toDo,
    createdAt: randomUtcMoment(random),
  );
}

Run _createRun(Random random, Task task, Workflow? workflow) {
  return createRun(
    runId: RunId('run-${randomText(random)}'),
    task: task,
    workflow: workflow,
    number: 1 + random.nextInt(_largestRunNumber),
    startedBy: GalleryDeviceIds.airLaptop,
    at: randomUtcMoment(random),
  );
}

Workflow _withoutAgents(Workflow workflow) {
  return workflow.withGraph(
    agents: const <WorkflowAgent>[],
    connections: const <AgentConnection>[],
  );
}

Workflow _withRepeatedAgent(Workflow workflow) {
  return workflow.withGraph(
    agents: <WorkflowAgent>[...workflow.agents, workflow.agents.first],
    connections: workflow.connections,
  );
}

void main() {
  test('test_refuse_unrunnable_workflow_property_one_agent_tasks_take_'
      'none', () {
    final Random random = seededRandom(89001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = _randomTaskWithDoer(
        random,
        OneAgentDoer(pickOne(random, AgentKind.values)),
      );
      final Workflow workflow = randomAcyclicWorkflow(random);

      expect(
        () => _createRun(random, task, workflow),
        throwsA(isA<ArgumentError>()),
      );
    }
  });

  test('test_refuse_unrunnable_workflow_property_refuses_a_workflow_the_'
      'task_does_not_run', () {
    final Random random = seededRandom(89002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final WorkflowId otherId = WorkflowId('other ${randomText(random)}');
      final Task task = _randomTaskWithDoer(random, WorkflowDoer(otherId));

      expect(
        () => _createRun(random, task, workflow),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.invalidValue,
            'invalidValue',
            workflow.id.value,
          ),
        ),
      );
    }
  });

  test('test_refuse_unrunnable_workflow_property_refuses_an_invalid_'
      'workflow', () {
    final Random random = seededRandom(89003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow valid = randomAcyclicWorkflow(random);
      final Workflow broken = valid.agents.isEmpty || random.nextBool()
          ? _withoutAgents(valid)
          : _withRepeatedAgent(valid);
      final String? problem = describeWorkflowProblem(broken);
      final Task task = _randomTaskWithDoer(random, WorkflowDoer(broken.id));

      expect(problem, isNotNull);
      expect(
        () => _createRun(random, task, broken),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.message,
            'message',
            problem,
          ),
        ),
      );
    }
  });
}
