import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/screens/shared/deletion_review.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/screens/workflows/workflow_quick_start.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';

const SectionRoute _workflowsRoute = SectionRoute(AppSection.workflows);

class WorkflowDetailScreen extends StatefulWidget {
  const WorkflowDetailScreen({
    required this.workflowId,
    required this.workflowRepository,
    required this.workspaceRepository,
    required this.deviceRepository,
    required this.runnerRepository,
    required this.projectRepository,
    required this.taskRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final WorkflowId workflowId;
  final WorkflowRepository workflowRepository;
  final WorkspaceRepository workspaceRepository;
  final DeviceRepository deviceRepository;
  final RunnerRepository runnerRepository;
  final ProjectRepository projectRepository;
  final TaskRepository taskRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  State<WorkflowDetailScreen> createState() => _WorkflowDetailScreenState();
}

class _WorkflowDetailScreenState extends State<WorkflowDetailScreen> {
  bool _isStarting = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.workflowRepository,
        widget.runnerRepository,
        widget.deviceRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final WorkflowId workflowId = widget.workflowId;
    final AppNavigation navigation = widget.navigation;
    final Workflow workflow = widget.workflowRepository.findWorkflow(
      workflowId,
    );
    final DeviceNames deviceNames = DeviceNames(
      widget.deviceRepository.listDevices(),
    );
    final WorkflowSignature? signature = workflow.signature;
    final SignatureState signatureState = findSignatureState(
      workflow,
      widget.workflowRepository.findPendingChange(workflowId),
    );
    final bool canStartNow =
        signatureState == SignatureState.signed && !_isStarting;

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: workflow.name,
          summary: <TextSegment>[
            TextSegment(
              describeSignedSummary(
                workflow: workflow,
                workspaces: widget.workspaceRepository.listWorkspaces(),
                deviceNames: deviceNames,
                now: widget.clock.now(),
              ),
            ),
          ],
          backLink: BackLink(
            label: 'Workflows',
            onPressed: () => navigation.returnTo(_workflowsRoute),
          ),
          actions: <Widget>[
            AppButton.secondary(
              label: 'Delete',
              onPressed: () => unawaited(_reviewDeletion(workflow)),
            ),
            AppButton.secondary(
              label: 'Edit diagram',
              icon: AppIconKind.edit,
              onPressed: () => navigation.openRoute(
                WorkflowBuilderRoute(
                  workflowId,
                  opening: BuilderOpening.forEditing,
                ),
              ),
            ),
            AppButton.secondary(
              label: 'Use in a task',
              icon: AppIconKind.tasks,
              onPressed: signature == null
                  ? null
                  : () =>
                        navigation.openRoute(NewWorkflowTaskRoute(workflowId)),
            ),
            AppButton.primary(
              label: startNowLabel,
              icon: AppIconKind.play,
              onPressed: canStartNow
                  ? () => unawaited(_startNow(workflow))
                  : null,
            ),
          ],
        ),
        SplitLayout(
          start: PageSection(
            title: 'Steps',
            children: <Widget>[
              ResponsiveList.plain(
                rows: <ListRowData>[
                  for (final WorkflowAgent agent in orderAgents(workflow))
                    _buildStepRow(agent, deviceNames),
                ],
              ),
            ],
          ),
          end: PageSection(
            title: 'Source',
            children: <Widget>[
              if (signature == null)
                const MutedNote('Sign it to see the version runners use.')
              else
                CodeBlock(lines: splitDocumentLines(signature.signedDocument)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _reviewDeletion(Workflow workflow) {
    return reviewDeletion(
      context: context,
      prompt: describeWorkflowDeletion(workflow),
      navigation: widget.navigation,
      leavePage: () => widget.navigation.returnTo(_workflowsRoute),
      deleteRecord: () =>
          widget.workflowRepository.deleteWorkflow(workflow.id),
    );
  }

  ListRowData _buildStepRow(WorkflowAgent agent, DeviceNames deviceNames) {
    final List<Runner> runners = widget.runnerRepository.listRunners();

    return ListRowData(
      key: ValueKey<WorkflowAgentId>(agent.id),
      main: ListRowMain.monospace(
        title: agent.name,
        subtitle: describeStepRunsOn(agent.runsOn, deviceNames),
      ),
      end: buildRunnerMatchLabel(agent.runsOn, runners),
    );
  }

  Future<void> _startNow(Workflow workflow) async {
    if (_isStarting) {
      return;
    }

    final AppNavigation navigation = widget.navigation;
    final WorkspaceId workspaceId = widget.workspaceRepository
        .currentWorkspace()
        .id;
    final List<Project> projects = widget.projectRepository.listProjects(
      workspaceId,
    );
    if (projects.isEmpty) {
      navigation.openRoute(const NewProjectRoute());
      return;
    }

    final AppRoute detailPage = navigation.currentRoute;
    setState(() => _isStarting = true);
    final Future<RunId> startedRun = startWorkflowNow(
      taskRepository: widget.taskRepository,
      workflow: workflow,
      projectId: projects.first.id,
    );
    final ActionOutcome outcome = await runShowingRefusal(
      context: context,
      title: workflow.name,
      actionLabel: startNowLabel,
      action: () => startedRun,
    ).whenComplete(_stopStarting);

    final bool isDetailPageShown = navigation.currentRoute == detailPage;
    if (outcome == ActionOutcome.done && isDetailPageShown) {
      navigation.openRoute(TaskRunRoute(await startedRun));
    }
  }

  void _stopStarting() {
    if (mounted) {
      setState(() => _isStarting = false);
    }
  }
}
