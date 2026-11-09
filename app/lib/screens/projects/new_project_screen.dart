import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/screens/projects/project_form.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

final DraftedProject _blankProject = DraftedProject(
  name: '',
  repositories: const <RepositoryDraft>[],
  agentAccess: AgentAccess.pushAfterApproval,
  approvalPolicy: null,
);

class NewProjectScreen extends StatelessWidget {
  const NewProjectScreen({
    required this.projectRepository,
    required this.workspaceRepository,
    required this.deviceRepository,
    required this.folderPicker,
    required this.navigation,
    super.key,
  });

  final ProjectRepository projectRepository;
  final WorkspaceRepository workspaceRepository;
  final DeviceRepository deviceRepository;
  final FolderPicker? folderPicker;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: <Widget>[
        PageHeader(
          title: 'New project',
          backLink: BackLink(
            label: 'Projects',
            onPressed: navigation.closeForm,
          ),
        ),
        ProjectForm(
          initialProject: _blankProject,
          deviceRepository: deviceRepository,
          folderPicker: folderPicker,
          actions: <FormAction<DraftedProject>>[
            LeaveFormAction<DraftedProject>(
              label: 'Cancel',
              onPressed: navigation.closeForm,
            ),
            SubmitFormAction<DraftedProject>(
              label: 'Create project',
              tone: ButtonTone.primary,
              onSubmitted: _createProject,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _createProject(DraftedProject drafted) async {
    final AppRoute savedForm = navigation.currentRoute;
    final Project project = await projectRepository.createProject(
      drafted.toProjectDraft(workspaceRepository.currentWorkspace().id),
    );
    navigation.replaceSavedForm(
      savedForm: savedForm,
      destination: ProjectRoute(project.id),
    );
  }
}
