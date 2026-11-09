import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/rules/agent_kind_label.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';
import 'package:agent_orchestration/data/rules/task_branch.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

const String _baseBranch = 'main';

const Set<RunStatus> _retryableRunStatuses = <RunStatus>{
  RunStatus.failed,
  RunStatus.cancelled,
};

const Set<StepStatus> _requeuedStepStatuses = <StepStatus>{
  StepStatus.failed,
  StepStatus.skipped,
};

bool isRunActive(Run run) => !isRunFinished(run.status);

DeviceId? _pinnedRunner(RunnerTarget target) {
  if (target is SpecificRunner) {
    return target.deviceId;
  }
  return null;
}

RunStep _planWaitingStep({
  required String name,
  required WorkflowAgentId? agentId,
  required RunnerTarget runsOn,
}) {
  return RunStep(
    name: name,
    agentId: agentId,
    runner: _pinnedRunner(runsOn),
    status: StepStatus.waiting,
    startedAt: null,
    finishedAt: null,
    result: null,
    outcome: null,
    loopSource: null,
    earlierRounds: const <EarlierRound>[],
  );
}

RunStep _planOneAgentStep(Task task) {
  final TaskDoer doer = task.doer;
  if (doer is! OneAgentDoer) {
    throw ArgumentError.value(task.id.value, 'task', 'Needs its workflow');
  }

  return _planWaitingStep(
    name: labelAgentKind(doer.agent),
    agentId: null,
    runsOn: task.runsOn,
  );
}

void _refuseUnrunnableWorkflow(Task task, Workflow workflow) {
  final TaskDoer doer = task.doer;
  if (doer is! WorkflowDoer || doer.workflowId != workflow.id) {
    throw ArgumentError.value(
      workflow.id.value,
      'workflow',
      'Task ${task.id.value} does not run this workflow',
    );
  }

  final String? problem = describeWorkflowProblem(workflow);
  if (problem != null) {
    throw PeopleFacingRefusal(problem);
  }
}

List<RunStep> _planSteps(Task task, Workflow? workflow) {
  if (workflow == null) {
    return <RunStep>[_planOneAgentStep(task)];
  }
  _refuseUnrunnableWorkflow(task, workflow);

  return <RunStep>[
    for (final WorkflowAgent agent in orderAgents(workflow))
      _planWaitingStep(
        name: agent.name,
        agentId: agent.id,
        runsOn: agent.runsOn,
      ),
  ];
}

RunStep _requeueStep(RunStep step) {
  return RunStep(
    name: step.name,
    agentId: step.agentId,
    runner: step.runner,
    status: StepStatus.waiting,
    startedAt: null,
    finishedAt: null,
    result: step.result,
    outcome: step.outcome,
    loopSource: step.loopSource,
    earlierRounds: step.earlierRounds,
  );
}

List<RunStep> _requeueStoppedSteps(List<RunStep> steps) {
  final List<RunStep> requeued = <RunStep>[];

  for (final RunStep step in steps) {
    if (_requeuedStepStatuses.contains(step.status)) {
      requeued.add(_requeueStep(step));
    } else {
      requeued.add(step);
    }
  }

  return requeued;
}

String describeRunBranch(Task task, int runNumber) {
  if (task.schedule == null) {
    return describeTaskBranch(title: task.title, taskId: task.id);
  }
  return describeJobRunBranch(
    title: task.title,
    taskId: task.id,
    runNumber: runNumber,
  );
}

Run createRun({
  required RunId runId,
  required Task task,
  required Workflow? workflow,
  required int number,
  required DeviceId startedBy,
  required DateTime at,
}) {
  final List<RunStep> steps = _planSteps(task, workflow);
  final String branch = describeRunBranch(task, number);

  return Run(
    id: runId,
    taskId: task.id,
    number: number,
    status: RunStatus.queued,
    steps: steps,
    log: <LogLine>[
      LogLine(
        at: at,
        stepName: steps.first.name,
        text: 'Created worktree $branch from $_baseBranch',
        isError: false,
      ),
    ],
    chat: const <ChatMessage>[],
    failure: null,
    link: RunnerLink.direct,
    linkLostAt: null,
    agentSession: null,
    worktreeBranch: branch,
    startedBy: startedBy,
    startedAt: at,
    finishedAt: null,
    loopRounds: const <LoopRounds>[],
    notes: const <RunNote>[],
  );
}

Run buildCancelledRun(Run run, DateTime at) {
  if (!isRunActive(run)) {
    throw PeopleFacingRefusal('Run ${run.number} is not active');
  }

  return run.withProgress(
    nextStatus: RunStatus.cancelled,
    nextSteps: skipUnfinishedSteps(run.steps, at),
    nextFinishedAt: at,
  );
}

Run buildRetriedRun(Run run) {
  if (!_retryableRunStatuses.contains(run.status)) {
    throw PeopleFacingRefusal('Run ${run.number} cannot be retried');
  }

  final List<RunStep> steps = _requeueStoppedSteps(run.steps);

  return Run(
    id: run.id,
    taskId: run.taskId,
    number: run.number,
    status: deriveRunStatus(steps),
    steps: steps,
    log: run.log,
    chat: run.chat,
    failure: null,
    link: run.link,
    linkLostAt: run.linkLostAt,
    agentSession: run.agentSession,
    worktreeBranch: run.worktreeBranch,
    startedBy: run.startedBy,
    startedAt: run.startedAt,
    finishedAt: null,
    loopRounds: run.loopRounds,
    notes: run.notes,
  );
}
