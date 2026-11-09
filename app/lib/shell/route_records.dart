import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/shell/app_route.dart';

bool isRouteRecordMissing({
  required AppRoute route,
  required AppDependencies dependencies,
}) {
  try {
    _lookUpRouteRecords(route: route, dependencies: dependencies);
  } on RecordNotFound {
    return true;
  }
  return false;
}

void _lookUpRouteRecords({
  required AppRoute route,
  required AppDependencies dependencies,
}) {
  switch (route) {
    case SkillDetailRoute(:final SkillId skillId) ||
        EditSkillRoute(:final SkillId skillId):
      dependencies.skillRepository.findSkill(skillId);
    case RuleDetailRoute(:final RuleId ruleId) ||
        EditRuleRoute(:final RuleId ruleId):
      dependencies.ruleRepository.findRule(ruleId);
    case EditTaskRoute(:final TaskId taskId):
      dependencies.taskRepository.findTask(taskId);
    case EditJobRoute(:final TaskId jobId):
      dependencies.jobRepository.findJob(jobId);
    case RunPageRoute(:final RunId runId):
      final Run run = dependencies.taskRepository.findRun(runId);
      dependencies.taskRepository.findTask(run.taskId);
    case WorkflowDetailRoute(:final WorkflowId workflowId) ||
        WorkflowChangeRoute(:final WorkflowId workflowId) ||
        WorkflowBuilderRoute(:final WorkflowId workflowId) ||
        NewWorkflowTaskRoute(:final WorkflowId workflowId) ||
        NewItemFormRoute(presetWorkflowId: final WorkflowId workflowId):
      dependencies.workflowRepository.findWorkflow(workflowId);
    case ProjectRoute(:final ProjectId projectId) ||
        ProjectFilesRoute(:final ProjectId projectId) ||
        RepositoryFileRoute(
          filesRoute: ProjectFilesRoute(:final ProjectId projectId),
        ) ||
        NewRuleRoute(presetProjectId: final ProjectId projectId) ||
        NewItemFormRoute(presetProjectId: final ProjectId projectId):
      dependencies.projectRepository.findProject(projectId);
    case RunnerDetailRoute(:final DeviceId deviceId):
      dependencies.runnerRepository.findRunner(deviceId);
      dependencies.deviceRepository.findDevice(deviceId);
    case SectionRoute() ||
        NewTaskRoute() ||
        NewJobRoute() ||
        NewProjectRoute() ||
        NewWorkflowRoute() ||
        NewSkillRoute() ||
        NewRuleRoute() ||
        NewItemFormRoute() ||
        ManualWorkflowRoute() ||
        WorkflowDraftingRoute() ||
        WorkspaceSwitcherRoute() ||
        PairingCodeRoute() ||
        PairingApprovalRoute() ||
        SetupRoute():
      return;
  }
}
