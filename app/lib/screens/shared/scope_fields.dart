import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/tag_input_field.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const String _allWorkspacesHint = 'All workspaces unless you add some.';
const String _allProjectsHint =
    'All projects unless you add some, from the workspaces above.';
const String _noWorkspaceLeftHint =
    'Nowhere: its workspaces are gone. It stays off until you add one.';
const String _noProjectLeftHint =
    'Nowhere: its projects are gone. It stays off until you add one.';

class ScopeFields extends StatelessWidget {
  const ScopeFields({
    required this.catalog,
    required this.selection,
    required this.onChanged,
    super.key,
  });

  final ScopeCatalog catalog;
  final ScopeSelection selection;
  final ValueChanged<ScopeSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<Project> suggestedProjects = catalog.listProjectsIn(
      selection.workspaceIds,
    );
    final Scope knownScope = catalog.keepKnownPlaces(selection.toScope());
    final ScopeSelection shownSelection = ScopeSelection.fromScope(knownScope);
    final String workspacesHint = listsNoWorkspace(knownScope.workspaces)
        ? _noWorkspaceLeftHint
        : _allWorkspacesHint;
    final String projectsHint = listsNoProject(knownScope.projects)
        ? _noProjectLeftHint
        : _allProjectsHint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        FormFieldBlock(
          label: 'Workspaces',
          hint: workspacesHint,
          children: <Widget>[
            TagInputField(
              tags: <String>[
                for (final WorkspaceId workspaceId
                    in shownSelection.workspaceIds)
                  catalog.nameOfWorkspace(workspaceId),
              ],
              suggestions: <String>[
                for (final Workspace workspace in catalog.workspaces)
                  workspace.name,
              ],
              placeholder: 'Add a workspace',
              onTagAdded: _addWorkspace,
              onTagRemoved: _removeWorkspace,
            ),
          ],
        ),
        FormFieldBlock(
          label: 'Projects',
          hint: projectsHint,
          children: <Widget>[
            TagInputField(
              tags: <String>[
                for (final ProjectId projectId in shownSelection.projectIds)
                  catalog.nameOfProject(projectId),
              ],
              suggestions: <String>[
                for (final Project project in suggestedProjects) project.name,
              ],
              placeholder: 'Add a project',
              onTagAdded: _addProject,
              onTagRemoved: _removeProject,
            ),
          ],
        ),
      ], AppSpacing.space5),
    );
  }

  void _addWorkspace(String workspaceName) {
    final WorkspaceId workspaceId = catalog.findWorkspaceId(workspaceName);

    onChanged(selection.withWorkspace(workspaceId, catalog));
  }

  void _removeWorkspace(String workspaceName) {
    final WorkspaceId workspaceId = catalog.findWorkspaceId(workspaceName);

    onChanged(selection.withoutWorkspace(workspaceId, catalog));
  }

  void _addProject(String projectName) {
    final ProjectId projectId = catalog.findProjectId(projectName);

    onChanged(selection.withProject(projectId, catalog));
  }

  void _removeProject(String projectName) {
    onChanged(selection.withoutProject(catalog.findProjectId(projectName)));
  }
}
