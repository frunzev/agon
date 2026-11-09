import 'dart:math';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';

import '../../../support/random_inputs.dart';
import 'random_shown_runs.dart';

const RunId shownRunId = RunId('shown-run');

typedef RunPageScene = ({
  AppDependencies dependencies,
  FakeTaskRepository tasks,
  Run run,
  Task task,
});

List<Task> listGalleryWork() => <Task>[...galleryTasks, ...galleryJobs];

Run randomRunOfTask(Random random, {required Task task}) {
  final Workflow? workflow = findWorkflowForDoer(task.doer, galleryWorkflows);
  final List<RunStep> steps = workflow == null
      ? randomOneAgentSteps(random, galleryNow)
      : randomStepsOfWorkflow(random, workflow: workflow, now: galleryNow);
  return buildShownRun(
    random,
    runId: shownRunId,
    taskId: task.id,
    steps: steps,
    now: galleryNow,
  );
}

RunPageScene buildRunPageScene({
  required Run run,
  required List<OpenPersonStep> openSteps,
  required List<ApprovalRequest> approvals,
}) {
  final AppDependencies base = buildGalleryDependencies();
  final FakeTaskRepository tasks = FakeTaskRepository(
    tasks: listGalleryWork(),
    runs: <Run>[...galleryRuns, run],
    clock: base.clock,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    workflowRepository: base.workflowRepository as FakeWorkflowRepository,
  );
  final AppDependencies dependencies = replaceShownRunRepositories(
    base,
    tasks: tasks,
    openSteps: openSteps,
    approvals: approvals,
  );
  return (
    dependencies: dependencies,
    tasks: tasks,
    run: run,
    task: tasks.findTask(run.taskId),
  );
}

AppDependencies replaceShownRunRepositories(
  AppDependencies base, {
  required FakeTaskRepository tasks,
  required List<OpenPersonStep> openSteps,
  required List<ApprovalRequest> approvals,
}) {
  return AppDependencies(
    clock: base.clock,
    taskRepository: tasks,
    jobRepository: base.jobRepository,
    chatRepository: base.chatRepository,
    approvalRepository: FakeApprovalRepository(
      approvals: approvals,
      clock: base.clock,
      currentDeviceId: GalleryDeviceIds.airLaptop,
    ),
    personStepRepository: FakePersonStepRepository(
      openSteps: openSteps,
      taskRepository: tasks,
    ),
    projectRepository: base.projectRepository,
    workspaceRepository: base.workspaceRepository,
    workflowRepository: base.workflowRepository,
    skillRepository: base.skillRepository,
    ruleRepository: base.ruleRepository,
    runnerRepository: base.runnerRepository,
    agentLoginRepository: base.agentLoginRepository,
    deviceRepository: base.deviceRepository,
    pairingRepository: base.pairingRepository,
    auditRepository: base.auditRepository,
    fileRepository: base.fileRepository,
    itemDraftRepository: base.itemDraftRepository,
    qrCodeScanner: base.qrCodeScanner,
    folderPicker: base.folderPicker,
    runnerPresence: base.runnerPresence,
  );
}

RunPageScene randomRunPageScene(Random random) {
  final Run run = randomRunOfTask(
    random,
    task: pickOne(random, listGalleryWork()),
  );
  return buildRunPageScene(
    run: run,
    openSteps: const <OpenPersonStep>[],
    approvals: const <ApprovalRequest>[],
  );
}
