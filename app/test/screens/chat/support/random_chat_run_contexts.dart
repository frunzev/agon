import 'dart:math';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/chat/chat_run_context.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../data/rules/support/random_progress_runs.dart';
import '../../../support/random_inputs.dart';
import '../../../support/random_workflows.dart';
import '../../../support/sample_records.dart';

const int _largestStepCount = 4;
const int _largestAgentCount = 5;
const WorkflowAgentId missingStepAgentId = WorkflowAgentId('no-such-agent');
final DeviceNames galleryDeviceNames = DeviceNames(galleryDevices);
final DateTime _taskCreatedAt = DateTime.utc(2026, 11, 8);

WorkflowAgent _randomStepAgent(Random random, int index) {
  final WorkflowAgent agent = randomAgent(random, index);
  if (random.nextInt(4) != 0) {
    return agent;
  }
  return buildPersonStepAgent(agent);
}

WorkflowAgent buildPersonStepAgent(WorkflowAgent agent) {
  return WorkflowAgent(
    id: agent.id,
    name: agent.name,
    stepKind: StepKind.person,
    kind: null,
    task: agent.task,
    runsOn: agent.runsOn,
    skills: agent.skills,
    usesAutomaticSkills: agent.usesAutomaticSkills,
    approvalPolicy: agent.approvalPolicy,
    position: agent.position,
  );
}

Workflow randomChatWorkflow(Random random) {
  final List<WorkflowAgent> agents = <WorkflowAgent>[
    for (int index = 0; index < random.nextInt(_largestAgentCount); index += 1)
      _randomStepAgent(random, index),
  ];
  final Workflow workflow = galleryWorkflows.first.withGraph(
    agents: agents,
    connections: const <AgentConnection>[],
  );
  return workflow.withName('Workflow ${randomHostileText(random)}');
}

WorkflowAgentId? _randomStepAgentId(Random random, Workflow? workflow) {
  final List<WorkflowAgentId?> choices = <WorkflowAgentId?>[
    null,
    missingStepAgentId,
    for (final WorkflowAgent agent in workflow?.agents ?? <WorkflowAgent>[])
      agent.id,
  ];
  return pickOne(random, choices);
}

DeviceId? randomStepRunner(Random random) {
  return pickOne(random, <DeviceId?>[
    null,
    for (final Device device in galleryDevices) device.id,
  ]);
}

RunStep buildChatRunStep({
  required String name,
  required WorkflowAgentId? agentId,
  required DeviceId? runner,
  required StepStatus status,
}) {
  return RunStep(
    name: name,
    agentId: agentId,
    runner: runner,
    status: status,
    startedAt: null,
    finishedAt: null,
    result: null,
    outcome: null,
    loopSource: null,
    earlierRounds: const <EarlierRound>[],
  );
}

Run randomChatRun(Random random, {required Workflow? workflow}) {
  final int stepCount = 1 + random.nextInt(_largestStepCount);
  final List<RunStep> steps = <RunStep>[
    for (int index = 0; index < stepCount; index += 1)
      buildChatRunStep(
        name: 'step-$index ${randomHostileText(random)}',
        agentId: _randomStepAgentId(random, workflow),
        runner: randomStepRunner(random),
        status: pickOne(random, StepStatus.values),
      ),
  ];
  return buildProgressRun(
    random,
    status: pickOne(random, RunStatus.values),
    steps: steps,
  );
}

Task buildChatTask({required TaskId id, required TaskDraft draft}) {
  return Task.fromDraft(
    id: id,
    draft: draft,
    schedule: null,
    status: TaskStatus.running,
    createdAt: _taskCreatedAt,
  );
}

Task randomChatTask(Random random, {required TaskId id}) {
  return buildChatTask(id: id, draft: randomTaskDraft(random));
}

Task randomChatTaskDoneBy(
  Random random, {
  required TaskId id,
  required TaskDoer doer,
}) {
  final TaskDraft sample = randomTaskDraft(random);
  final TaskDraft draft = TaskDraft(
    title: sample.title,
    details: sample.details,
    projectId: sample.projectId,
    doer: doer,
    runsOn: sample.runsOn,
    agentPlace: sample.agentPlace,
    skills: sample.skills,
    usesAutomaticSkills: sample.usesAutomaticSkills,
    approvalPolicy: sample.approvalPolicy,
  );
  return buildChatTask(id: id, draft: draft);
}

ChatRunContext randomOneStepContext(
  Random random, {
  required TaskDoer doer,
  required Workflow? workflow,
  required WorkflowAgentId? agentId,
}) {
  final RunStep step = buildChatRunStep(
    name: 'only step ${randomHostileText(random)}',
    agentId: agentId,
    runner: randomStepRunner(random),
    status: pickOne(random, StepStatus.values),
  );
  final Run run = buildProgressRun(
    random,
    status: pickOne(random, RunStatus.values),
    steps: <RunStep>[step],
  );
  return ChatRunContext(
    run: run,
    task: randomChatTaskDoneBy(random, id: run.taskId, doer: doer),
    workflow: workflow,
    deviceNames: galleryDeviceNames,
  );
}

ChatRunContext randomChatRunContext(Random random) {
  final Workflow? workflow = random.nextInt(3) == 0
      ? null
      : randomChatWorkflow(random);
  final Run run = randomChatRun(random, workflow: workflow);
  return ChatRunContext(
    run: run,
    task: randomChatTask(random, id: run.taskId),
    workflow: workflow,
    deviceNames: galleryDeviceNames,
  );
}

ChatRunContext rebuildWithDeviceNames(
  ChatRunContext context,
  DeviceNames deviceNames,
) {
  return ChatRunContext(
    run: context.run,
    task: context.task,
    workflow: context.workflow,
    deviceNames: deviceNames,
  );
}
