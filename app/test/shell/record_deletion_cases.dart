import 'dart:math';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes/fake_task_work.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/fake_task_work_links.dart';
import '../support/random_inputs.dart';

const String _repositoryAddress = 'github.com/acme/app';

typedef RecordDeletionCase = ({
  List<AppRoute> routes,
  Future<void> Function() deleteRecord,
});

typedef _CaseBuilder = RecordDeletionCase Function(
  Random random,
  AppDependencies dependencies,
);

List<AppRoute> _withOptionalTop(
  Random random,
  List<AppRoute> stack,
  AppRoute top,
) {
  if (random.nextBool()) {
    return stack;
  }
  return <AppRoute>[...stack, top];
}

bool _hasOnlyStoppedRuns(AppDependencies dependencies, TaskId taskId) {
  final List<Run> runs = dependencies.taskRepository.listRuns(taskId);
  return runs.every((Run run) => !isRunActive(run));
}

RecordDeletionCase _buildSkillCase(
  Random random,
  AppDependencies dependencies,
) {
  final Skill skill = pickOne(
    random,
    dependencies.skillRepository.listSkills(),
  );
  return (
    routes: _withOptionalTop(random, <AppRoute>[
      const SectionRoute(AppSection.skills),
      SkillDetailRoute(skill.id),
    ], EditSkillRoute(skill.id)),
    deleteRecord: () => dependencies.skillRepository.deleteSkill(skill.id),
  );
}

RecordDeletionCase _buildRuleCase(
  Random random,
  AppDependencies dependencies,
) {
  final Rule rule = pickOne(random, dependencies.ruleRepository.listRules());
  return (
    routes: _withOptionalTop(random, <AppRoute>[
      const SectionRoute(AppSection.rules),
      RuleDetailRoute(rule.id),
    ], EditRuleRoute(rule.id)),
    deleteRecord: () => dependencies.ruleRepository.deleteRule(rule.id),
  );
}

RecordDeletionCase _buildJobCase(Random random, AppDependencies dependencies) {
  final List<Task> jobs = <Task>[
    for (final Task job in dependencies.jobRepository.listJobs())
      if (_hasOnlyStoppedRuns(dependencies, job.id)) job,
  ];
  final Task job = pickOne(random, jobs);
  return (
    routes: <AppRoute>[
      const SectionRoute(AppSection.jobs),
      EditJobRoute(job.id),
    ],
    deleteRecord: () => dependencies.jobRepository.deleteJob(job.id),
  );
}

RecordDeletionCase _buildTaskCase(
  Random random,
  AppDependencies dependencies,
) {
  final List<Run> stoppedRuns = <Run>[
    for (final Task task in dependencies.taskRepository.listTasks())
      if (_hasOnlyStoppedRuns(dependencies, task.id))
        ...dependencies.taskRepository.listRuns(task.id),
  ];
  final Run run = pickOne(random, stoppedRuns);
  final List<AppRoute> runPages = _withOptionalTop(random, <AppRoute>[
    const SectionRoute(AppSection.tasks),
    TaskRunRoute(run.id),
  ], ChatRoute(run.id));
  final List<AppRoute> routes = random.nextBool()
      ? runPages
      : <AppRoute>[
          const SectionRoute(AppSection.tasks),
          EditTaskRoute(run.taskId),
        ];
  return (
    routes: routes,
    deleteRecord: () => dependencies.taskRepository.deleteTask(run.taskId),
  );
}

RecordDeletionCase _buildWorkflowCase(
  Random random,
  AppDependencies dependencies,
) {
  final FakeTaskWork taskWork = buildTaskWorkOf(dependencies);
  final List<Workflow> unusedWorkflows = <Workflow>[
    for (final Workflow workflow
        in dependencies.workflowRepository.listWorkflows())
      if (!taskWork.isWorkflowInUse(workflow.id)) workflow,
  ];
  final WorkflowId workflowId = pickOne(random, unusedWorkflows).id;
  final AppRoute top = random.nextBool()
      ? WorkflowBuilderRoute(workflowId, opening: BuilderOpening.forEditing)
      : NewWorkflowTaskRoute(workflowId);
  return (
    routes: _withOptionalTop(random, <AppRoute>[
      const SectionRoute(AppSection.workflows),
      WorkflowDetailRoute(workflowId),
    ], top),
    deleteRecord: () =>
        dependencies.workflowRepository.deleteWorkflow(workflowId),
  );
}

RecordDeletionCase _buildProjectCase(
  Random random,
  AppDependencies dependencies,
) {
  final FakeTaskWork taskWork = buildTaskWorkOf(dependencies);
  final WorkspaceId workspaceId = dependencies.workspaceRepository
      .currentWorkspace()
      .id;
  final List<Project> quietProjects = <Project>[
    for (final Project project in dependencies.projectRepository.listProjects(
      workspaceId,
    ))
      if (!taskWork.hasActiveRunInProjects(<ProjectId>{project.id})) project,
  ];
  final ProjectId projectId = pickOne(random, quietProjects).id;
  final AppRoute top = random.nextBool()
      ? NewRuleRoute(presetProjectId: projectId)
      : ProjectFilesRoute(
          projectId: projectId,
          repositoryAddress: _repositoryAddress,
        );
  return (
    routes: _withOptionalTop(random, <AppRoute>[
      const SectionRoute(AppSection.projects),
      ProjectRoute(projectId),
    ], top),
    deleteRecord: () =>
        dependencies.projectRepository.deleteProject(projectId),
  );
}

RecordDeletionCase _buildRunnerCase(
  Random random,
  AppDependencies dependencies,
) {
  final DeviceId currentDeviceId = dependencies.deviceRepository
      .currentDevice()
      .id;
  final List<Runner> otherRunners = <Runner>[
    for (final Runner runner in dependencies.runnerRepository.listRunners())
      if (runner.deviceId != currentDeviceId) runner,
  ];
  final DeviceId deviceId = pickOne(random, otherRunners).deviceId;
  final WorkspaceId workspaceId = dependencies.workspaceRepository
      .currentWorkspace()
      .id;
  return (
    routes: <AppRoute>[
      const SectionRoute(AppSection.devices),
      RunnerDetailRoute(deviceId),
    ],
    deleteRecord: () => dependencies.deviceRepository
        .removeDeviceFromWorkspace(deviceId, workspaceId),
  );
}

const List<_CaseBuilder> _caseBuilders = <_CaseBuilder>[
  _buildSkillCase,
  _buildRuleCase,
  _buildJobCase,
  _buildTaskCase,
  _buildWorkflowCase,
  _buildProjectCase,
  _buildRunnerCase,
];

RecordDeletionCase randomRecordDeletionCase(
  Random random,
  AppDependencies dependencies,
) {
  final _CaseBuilder buildCase = pickOne(random, _caseBuilders);
  return buildCase(random, dependencies);
}
