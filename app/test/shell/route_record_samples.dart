import 'dart:math';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/random_inputs.dart';

typedef SampledRoute = ({AppRoute route, bool usesUnknownRecord});

const String _unknownPrefix = 'unknown-record';
const int _identifierSpan = 1 << 30;

List<AppRoute> listPagesWithoutRecords(Random random) {
  return <AppRoute>[
    SectionRoute(pickOne(random, AppSection.values)),
    const NewTaskRoute(),
    const NewJobRoute(),
    const NewSkillRoute(),
    const NewProjectRoute(),
    const NewWorkflowRoute(),
    const ManualWorkflowRoute(),
    WorkflowDraftingRoute(WorkflowDraft(description: randomText(random))),
    const WorkspaceSwitcherRoute(),
    const PairingCodeRoute(),
    const PairingApprovalRoute(),
    const SetupRoleRoute(),
    PairingCodeEntryRoute(pickOne(random, DeviceRole.values)),
    const NewRuleRoute(presetProjectId: null),
    NewItemFormRoute(pickOne(random, DraftKind.values)),
  ];
}

String _unknownIdentifier(Random random) {
  final int number = random.nextInt(_identifierSpan);
  return '$_unknownPrefix-$number-${randomText(random)}';
}

List<RunId> _listRunIds(AppDependencies dependencies) {
  final List<RunId> runIds = <RunId>[];
  for (final Task task in dependencies.taskRepository.listTasks()) {
    for (final Run run in dependencies.taskRepository.listRuns(task.id)) {
      runIds.add(run.id);
    }
  }
  return runIds;
}

T _pickKnownOrUnknown<T>(
  Random random, {
  required List<T> known,
  required T Function(String identifier) unknown,
  required List<bool> usedUnknown,
}) {
  final bool usesUnknown = known.isEmpty || random.nextBool();
  usedUnknown.add(usesUnknown);
  if (usesUnknown) {
    return unknown(_unknownIdentifier(random));
  }
  return pickOne(random, known);
}

SampledRoute sampleRecordRoute(Random random, AppDependencies dependencies) {
  final List<bool> usedUnknown = <bool>[];
  final SkillId skillId = _pickKnownOrUnknown<SkillId>(
    random,
    known: <SkillId>[
      for (final Skill skill in dependencies.skillRepository.listSkills())
        skill.id,
    ],
    unknown: SkillId.new,
    usedUnknown: usedUnknown,
  );
  final RuleId ruleId = _pickKnownOrUnknown<RuleId>(
    random,
    known: <RuleId>[
      for (final Rule rule in dependencies.ruleRepository.listRules()) rule.id,
    ],
    unknown: RuleId.new,
    usedUnknown: usedUnknown,
  );
  final TaskId taskId = _pickKnownOrUnknown<TaskId>(
    random,
    known: <TaskId>[
      for (final Task task in dependencies.taskRepository.listTasks()) task.id,
    ],
    unknown: TaskId.new,
    usedUnknown: usedUnknown,
  );
  final TaskId jobId = _pickKnownOrUnknown<TaskId>(
    random,
    known: <TaskId>[
      for (final Task job in dependencies.jobRepository.listJobs()) job.id,
    ],
    unknown: TaskId.new,
    usedUnknown: usedUnknown,
  );
  final RunId runId = _pickKnownOrUnknown<RunId>(
    random,
    known: _listRunIds(dependencies),
    unknown: RunId.new,
    usedUnknown: usedUnknown,
  );
  final WorkflowId workflowId = _pickKnownOrUnknown<WorkflowId>(
    random,
    known: <WorkflowId>[
      for (final Workflow workflow
          in dependencies.workflowRepository.listWorkflows())
        workflow.id,
    ],
    unknown: WorkflowId.new,
    usedUnknown: usedUnknown,
  );
  final ProjectId projectId = _pickKnownOrUnknown<ProjectId>(
    random,
    known: <ProjectId>[
      for (final Project project in _listAllProjects(dependencies)) project.id,
    ],
    unknown: ProjectId.new,
    usedUnknown: usedUnknown,
  );
  final DeviceId runnerId = _pickKnownOrUnknown<DeviceId>(
    random,
    known: <DeviceId>[
      for (final Runner runner in dependencies.runnerRepository.listRunners())
        runner.deviceId,
    ],
    unknown: DeviceId.new,
    usedUnknown: usedUnknown,
  );
  final ProjectFilesRoute filesRoute = ProjectFilesRoute(
    projectId: projectId,
    repositoryAddress: randomText(random),
  );
  final List<(AppRoute, int)> choices = <(AppRoute, int)>[
    (SkillDetailRoute(skillId), 0),
    (EditSkillRoute(skillId), 0),
    (RuleDetailRoute(ruleId), 1),
    (EditRuleRoute(ruleId), 1),
    (EditTaskRoute(taskId), 2),
    (EditJobRoute(jobId), 3),
    (TaskRunRoute(runId), 4),
    (ChatRoute(runId), 4),
    (WorkflowDetailRoute(workflowId), 5),
    (WorkflowChangeRoute(workflowId), 5),
    (
      WorkflowBuilderRoute(
        workflowId,
        opening: pickOne(random, BuilderOpening.values),
      ),
      5,
    ),
    (NewWorkflowTaskRoute(workflowId), 5),
    (NewItemFormRoute(DraftKind.task, presetWorkflowId: workflowId), 5),
    (ProjectRoute(projectId), 6),
    (filesRoute, 6),
    (NewRuleRoute(presetProjectId: projectId), 6),
    (NewItemFormRoute(DraftKind.rule, presetProjectId: projectId), 6),
    (RunnerDetailRoute(runnerId), 7),
  ];
  final (AppRoute route, int recordIndex) = pickOne(random, choices);
  return (route: route, usesUnknownRecord: usedUnknown[recordIndex]);
}

List<Project> _listAllProjects(AppDependencies dependencies) {
  final List<Project> projects = <Project>[];
  final List<Workspace> workspaces = dependencies.workspaceRepository
      .listWorkspaces();
  for (final Workspace workspace in workspaces) {
    projects.addAll(dependencies.projectRepository.listProjects(workspace.id));
  }
  return projects;
}
