import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/skill_names.dart';
import 'package:agent_orchestration/screens/task_form/folder_runner_notice.dart';
import 'package:agent_orchestration/screens/task_form/runner_choices.dart';
import 'package:agent_orchestration/screens/task_form/workflow_to_sign.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

export 'package:agent_orchestration/screens/task_form/runner_choices.dart'
    show buildRunnerOptions;

const String _deletedProjectLabel = 'Deleted project';
const String _deletedWorkflowLabel = 'Deleted workflow';
const String deletedChoiceProblem =
    'This was deleted. Pick one from the list.';
const TaskDoer defaultTaskDoer = OneAgentDoer(AgentKind.claudeCode);

final class TaskFormOptions {
  TaskFormOptions({
    required List<SelectOption<ProjectId>> projects,
    required List<SelectEntry<TaskDoer>> doers,
    required List<SelectOption<RunnerTarget>> runners,
    required List<Skill> skills,
    required Map<ProjectId, MissingFolderRunner> missingFolderRunners,
    required Map<WorkflowId, WorkflowToSign> workflowsToSign,
    required this.deviceNames,
  }) : projects = List<SelectOption<ProjectId>>.unmodifiable(projects),
       doers = List<SelectEntry<TaskDoer>>.unmodifiable(doers),
       runners = List<SelectOption<RunnerTarget>>.unmodifiable(runners),
       skills = List<Skill>.unmodifiable(skills),
       missingFolderRunners = Map<ProjectId, MissingFolderRunner>.unmodifiable(
         missingFolderRunners,
       ),
       workflowsToSign = Map<WorkflowId, WorkflowToSign>.unmodifiable(
         workflowsToSign,
       );

  final List<SelectOption<ProjectId>> projects;
  final List<SelectEntry<TaskDoer>> doers;
  final List<SelectOption<RunnerTarget>> runners;
  final List<Skill> skills;
  final Map<ProjectId, MissingFolderRunner> missingFolderRunners;
  final Map<WorkflowId, WorkflowToSign> workflowsToSign;
  final DeviceNames deviceNames;

  ProjectId get firstProjectId {
    if (projects.isEmpty) {
      throw StateError('Create a project before adding tasks');
    }
    return projects.first.value;
  }

  WorkflowToSign? findWorkflowToSign(TaskDoer doer) {
    if (doer is WorkflowDoer) {
      return workflowsToSign[doer.workflowId];
    }
    return null;
  }

  List<String> describeSkills(List<SkillId> skillIds) {
    return describeSkillNames(skills: skills, skillIds: skillIds);
  }

  SkillId findSkillId(String skillName) {
    return findSkillIdByName(skills: skills, skillName: skillName);
  }

  ProjectId pickShownProject(ProjectId? projectId) {
    for (final SelectOption<ProjectId> option in projects) {
      if (option.value == projectId) {
        return option.value;
      }
    }
    return firstProjectId;
  }

  List<SkillId> pickShownSkills(List<SkillId> skillIds) {
    final Set<SkillId> listedSkillIds = <SkillId>{
      for (final Skill skill in skills) skill.id,
    };
    return <SkillId>[
      for (final SkillId skillId in skillIds)
        if (listedSkillIds.contains(skillId)) skillId,
    ];
  }

  List<SelectOption<RunnerTarget>> listRunnerChoices(
    RunnerTarget shownTarget,
  ) {
    return includeRunnerTarget(
      options: runners,
      target: shownTarget,
      deviceNames: deviceNames,
    );
  }

  List<SelectOption<ProjectId>> listProjectChoices(ProjectId shownProjectId) {
    if (_isListed(projects, shownProjectId)) {
      return projects;
    }
    return <SelectOption<ProjectId>>[
      ...projects,
      SelectOption<ProjectId>.disabled(
        value: shownProjectId,
        label: _deletedProjectLabel,
      ),
    ];
  }

  List<SelectEntry<TaskDoer>> listDoerChoices(TaskDoer shownDoer) {
    if (_isListed(doers, shownDoer)) {
      return doers;
    }
    return <SelectEntry<TaskDoer>>[
      ...doers,
      SelectOption<TaskDoer>.disabled(
        value: shownDoer,
        label: _describeDeletedDoerLabel(shownDoer),
      ),
    ];
  }

  String? describeProjectProblem(ProjectId projectId) {
    if (_isListed(projects, projectId)) {
      return null;
    }
    return deletedChoiceProblem;
  }

  String? describeDoerProblem(TaskDoer doer) {
    if (_isListed(doers, doer)) {
      return null;
    }
    return deletedChoiceProblem;
  }

  TaskDoer pickShownDoer(TaskDoer doer) {
    if (_isListed(doers, doer)) {
      return doer;
    }
    return defaultTaskDoer;
  }
}

bool _isListed<T>(List<SelectEntry<T>> entries, T value) {
  for (final SelectEntry<T> entry in entries) {
    if (entry is SelectOption<T> && entry.value == value) {
      return true;
    }
  }
  return false;
}

String _describeDeletedDoerLabel(TaskDoer doer) {
  switch (doer) {
    case OneAgentDoer(:final AgentKind agent):
      return agent.label;
    case WorkflowDoer():
      return _deletedWorkflowLabel;
  }
}

String _describeWorkflowChoice(
  Workflow workflow,
  Map<WorkflowId, WorkflowToSign> workflowsToSign,
) {
  if (workflowsToSign.containsKey(workflow.id)) {
    return '${workflow.name}, not signed';
  }
  return workflow.name;
}

List<SelectEntry<TaskDoer>> _buildDoerEntries(
  List<Workflow> workflows,
  Map<WorkflowId, WorkflowToSign> workflowsToSign,
) {
  return <SelectEntry<TaskDoer>>[
    const SelectGroupHeading<TaskDoer>('One agent'),
    for (final AgentKind agent in AgentKind.values)
      SelectOption<TaskDoer>(value: OneAgentDoer(agent), label: agent.label),
    const SelectGroupHeading<TaskDoer>('A workflow'),
    for (final Workflow workflow in workflows)
      SelectOption<TaskDoer>(
        value: WorkflowDoer(workflow.id),
        label: _describeWorkflowChoice(workflow, workflowsToSign),
      ),
  ];
}

TaskFormOptions buildTaskFormOptions({
  required List<Project> projects,
  required List<Workflow> workflows,
  required PendingChangeFinder findPendingChange,
  required List<Runner> runners,
  required DeviceNames deviceNames,
  required List<Skill> skills,
  required RunnerTarget chosenTarget,
}) {
  final Map<WorkflowId, WorkflowToSign> workflowsToSign = findWorkflowsToSign(
    workflows: workflows,
    findPendingChange: findPendingChange,
  );

  return TaskFormOptions(
    projects: <SelectOption<ProjectId>>[
      for (final Project project in projects)
        SelectOption<ProjectId>(value: project.id, label: project.name),
    ],
    doers: _buildDoerEntries(workflows, workflowsToSign),
    runners: buildRunnerOptions(
      runners: runners,
      deviceNames: deviceNames,
      chosenTarget: chosenTarget,
    ),
    skills: skills,
    missingFolderRunners: _findMissingFolderRunners(
      projects: projects,
      runners: runners,
      deviceNames: deviceNames,
    ),
    workflowsToSign: workflowsToSign,
    deviceNames: deviceNames,
  );
}

Map<ProjectId, MissingFolderRunner> _findMissingFolderRunners({
  required List<Project> projects,
  required List<Runner> runners,
  required DeviceNames deviceNames,
}) {
  final Map<ProjectId, MissingFolderRunner> missingRunners =
      <ProjectId, MissingFolderRunner>{};
  for (final Project project in projects) {
    final MissingFolderRunner? missing = findMissingFolderRunner(
      project: project,
      runners: runners,
      deviceNames: deviceNames,
    );
    if (missing != null) {
      missingRunners[project.id] = missing;
    }
  }
  return missingRunners;
}
