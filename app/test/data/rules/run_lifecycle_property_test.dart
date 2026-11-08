import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/data/rules/run_step_agents.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import '../../support/sample_records.dart';
import '../fakes/support/startable_drafts.dart';
import '../gallery/support/node_run_rules.dart';

const int _largestRunNumber = 500;
const DeviceId _starter = DeviceId('device-that-started-the-run');

Task _randomTask(
  Random random, {
  required TaskDoer doer,
  required RunnerTarget runsOn,
  required Schedule? schedule,
}) {
  final TaskDraft randomDraft = replaceDraftDoer(
    randomTaskDraft(random),
    doer,
  );
  final TaskDraft draft = TaskDraft(
    title: randomHostileText(random),
    details: randomDraft.details,
    projectId: randomDraft.projectId,
    doer: doer,
    runsOn: runsOn,
    agentPlace: randomDraft.agentPlace,
    skills: randomDraft.skills,
    usesAutomaticSkills: randomDraft.usesAutomaticSkills,
    approvalPolicy: randomDraft.approvalPolicy,
  );
  return Task.fromDraft(
    id: TaskId('task-${randomText(random)}'),
    draft: draft,
    schedule: schedule,
    status: TaskStatus.toDo,
    createdAt: randomUtcMoment(random),
  );
}

Task _randomOneAgentTask(Random random) {
  return _randomTask(
    random,
    doer: OneAgentDoer(pickOne(random, AgentKind.values)),
    runsOn: randomRunnerTarget(random),
    schedule: random.nextBool() ? randomJobSchedule(random) : null,
  );
}

Run _createRun(Random random, Task task, Workflow? workflow) {
  return createRun(
    runId: RunId('run-${randomText(random)}'),
    task: task,
    workflow: workflow,
    number: 1 + random.nextInt(_largestRunNumber),
    startedBy: _starter,
    at: randomUtcMoment(random),
  );
}

Workflow _randomRunnableWorkflow(Random random) {
  while (true) {
    final Workflow workflow = randomAcyclicWorkflow(random);
    if (describeWorkflowProblem(workflow) == null) {
      return workflow;
    }
  }
}

({Workflow workflow, Run run}) _createWorkflowRun(Random random) {
  final Workflow workflow = _randomRunnableWorkflow(random);
  final Task task = _randomTask(
    random,
    doer: WorkflowDoer(workflow.id),
    runsOn: randomRunnerTarget(random),
    schedule: null,
  );
  return (workflow: workflow, run: _createRun(random, task, workflow));
}

DeviceId? _pinnedDevice(RunnerTarget target) {
  if (target is SpecificRunner) {
    return target.deviceId;
  }
  return null;
}

void main() {
  test('test_pinned_runner_property_one_agent_steps_take_only_a_named_'
      'runner', () {
    final Random random = seededRandom(88701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = _randomOneAgentTask(random);

      final Run run = _createRun(random, task, null);

      expect(run.steps.single.runner, _pinnedDevice(task.runsOn));
    }
  });

  test('test_pinned_runner_property_workflow_steps_follow_their_agent_'
      'target', () {
    final Random random = seededRandom(88702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final (:Workflow workflow, :Run run) = _createWorkflowRun(random);

      for (final RunStep step in run.steps) {
        final WorkflowAgent agent = workflow.findAgent(step.agentId!);
        expect(step.runner, _pinnedDevice(agent.runsOn), reason: agent.name);
      }
    }
  });

  test('test_pinned_runner_property_the_starting_device_is_never_'
      'assumed', () {
    final Random random = seededRandom(88703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = _randomTask(
        random,
        doer: OneAgentDoer(pickOne(random, AgentKind.values)),
        runsOn: random.nextBool()
            ? const AnyFreeRunner()
            : RunnerWithLabels(<String>[randomText(random)]),
        schedule: null,
      );

      final Run run = _createRun(random, task, null);

      expect(run.steps.single.runner, isNull);
      expect(run.startedBy, _starter);
    }
  });

  test('test_plan_waiting_step_property_new_steps_carry_no_history', () {
    final Random random = seededRandom(88704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = random.nextBool()
          ? _createRun(random, _randomOneAgentTask(random), null)
          : _createWorkflowRun(random).run;

      for (final RunStep step in run.steps) {
        expect(step.status, StepStatus.waiting);
        expect(
          <Object?>[step.startedAt, step.finishedAt],
          <Object?>[null, null],
        );
        expect(
          <Object?>[step.result, step.outcome, step.loopSource],
          <Object?>[null, null, null],
        );
        expect(step.earlierRounds, isEmpty);
      }
    }
  });

  test('test_plan_waiting_step_property_workflow_steps_point_at_their_'
      'agent', () {
    final Random random = seededRandom(88705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final (:Workflow workflow, :Run run) = _createWorkflowRun(random);

      for (final RunStep step in run.steps) {
        final WorkflowAgent? agent = findRunStepAgent(
          step: step,
          workflow: workflow,
        );
        expect(agent?.name, step.name);
      }
      expect(run.steps.length, workflow.agents.length);
    }
  });

  test('test_plan_waiting_step_property_step_identities_are_unique', () {
    final Random random = seededRandom(88706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _createWorkflowRun(random).run;

      final Set<WorkflowAgentId?> agentIds = <WorkflowAgentId?>{
        for (final RunStep step in run.steps) step.agentId,
      };
      expect(agentIds.length, run.steps.length);
      expect(agentIds, isNot(contains(null)));
    }
  });

  test('test_plan_one_agent_step_property_one_step_named_for_the_agent', () {
    final Random random = seededRandom(88707);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = _randomOneAgentTask(random);
      final AgentKind agent = (task.doer as OneAgentDoer).agent;

      final Run run = _createRun(random, task, null);

      expect(run.steps.length, 1);
      expect(run.steps.single.name, nodeOneAgentStepNames[agent]);
    }
  });

  test('test_plan_one_agent_step_property_the_step_has_no_agent_id', () {
    final Random random = seededRandom(88708);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = _randomOneAgentTask(random);

      final Run run = _createRun(random, task, null);

      expect(run.steps.single.agentId, isNull);
      expect(
        findRunStepAgent(
          step: run.steps.single,
          workflow: randomAcyclicWorkflow(random),
        ),
        isNull,
      );
    }
  });

  test('test_plan_one_agent_step_property_a_workflow_task_needs_its_'
      'workflow', () {
    final Random random = seededRandom(88709);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = _randomTask(
        random,
        doer: WorkflowDoer(WorkflowId(randomText(random))),
        runsOn: randomRunnerTarget(random),
        schedule: null,
      );

      expect(
        () => _createRun(random, task, null),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.invalidValue,
            'invalidValue',
            task.id.value,
          ),
        ),
      );
    }
  });
}
