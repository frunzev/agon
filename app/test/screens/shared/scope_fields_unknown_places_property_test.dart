import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/screens/shared/scope_fields.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';
import 'package:agent_orchestration/widgets/forms/removable_tag.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/random_unknown_scope_places.dart';
import '../../support/sample_records.dart';
import '../../support/sample_scopes.dart';
import '../../support/widget_harness.dart';
import '../rules/rule_form_probe.dart';

const String _workspacesLabel = 'Workspaces';
const String _projectsLabel = 'Projects';
const String _noWorkspaceLeftHint =
    'Nowhere: its workspaces are gone. It stays off until you add one.';
const String _noProjectLeftHint =
    'Nowhere: its projects are gone. It stays off until you add one.';

ScopeSelection _randomSelectionWithUnknownPlaces(Random random) {
  return ScopeSelection(
    workspaceIds: mixInUnknownWorkspaces(
      random,
      pickSome(random, sampleWorkspaceIds),
    ),
    projectIds: mixInUnknownProjects(
      random,
      pickSome(random, sampleProjectIds),
    ),
  );
}

Future<List<ScopeSelection>> _pumpFields(
  WidgetTester tester,
  Random random,
  ScopeSelection selection,
) async {
  final List<ScopeSelection> changes = <ScopeSelection>[];
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: ScopeFields(
      catalog: galleryCatalog,
      selection: selection,
      onChanged: changes.add,
    ),
  );
  return changes;
}

List<String> _nameKnownWorkspaces(List<WorkspaceId> workspaceIds) {
  return <String>[
    for (final WorkspaceId workspaceId in workspaceIds)
      if (sampleWorkspaceIds.contains(workspaceId))
        galleryCatalog.nameOfWorkspace(workspaceId),
  ];
}

List<String> _nameKnownProjects(List<ProjectId> projectIds) {
  return <String>[
    for (final ProjectId projectId in projectIds)
      if (sampleProjectIds.contains(projectId))
        galleryCatalog.nameOfProject(projectId),
  ];
}

void main() {
  testWidgets('test_scope_fields_build_property_unknown_places_are_left_'
      'out', (WidgetTester tester) async {
    final Random random = seededRandom(110421);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScopeSelection selection = _randomSelectionWithUnknownPlaces(
        random,
      );

      await _pumpFields(tester, random, selection);

      expect(tester.takeException(), isNull);
      expect(
        readShownScopeTags(tester, _workspacesLabel),
        _nameKnownWorkspaces(selection.workspaceIds),
      );
      expect(
        readShownScopeTags(tester, _projectsLabel),
        _nameKnownProjects(selection.projectIds),
      );
    }
  });

  testWidgets('test_scope_fields_build_property_only_unknown_places_hint_'
      'nowhere', (WidgetTester tester) async {
    final Random random = seededRandom(110422);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool hasUnknownWorkspaces = random.nextBool();
      final ScopeSelection selection = ScopeSelection(
        workspaceIds: hasUnknownWorkspaces
            ? mixInUnknownWorkspaces(random, const <WorkspaceId>[])
            : const <WorkspaceId>[],
        projectIds: hasUnknownWorkspaces
            ? const <ProjectId>[]
            : mixInUnknownProjects(random, const <ProjectId>[]),
      );

      await _pumpFields(tester, random, selection);

      expect(tester.takeException(), isNull);
      expect(
        findFieldText(_workspacesLabel, _noWorkspaceLeftHint),
        hasUnknownWorkspaces ? findsOneWidget : findsNothing,
      );
      expect(
        findFieldText(_projectsLabel, _noProjectLeftHint),
        hasUnknownWorkspaces ? findsNothing : findsOneWidget,
      );
    }
  });

  testWidgets('test_scope_fields_build_property_removing_a_shown_tag_'
      'removes_only_that_place', (WidgetTester tester) async {
    final Random random = seededRandom(110423);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<WorkspaceId> known = <WorkspaceId>[
        pickOne(random, sampleWorkspaceIds),
      ];
      final ScopeSelection selection = ScopeSelection(
        workspaceIds: mixInUnknownWorkspaces(random, known),
        projectIds: const <ProjectId>[],
      );
      final List<ScopeSelection> changes = await _pumpFields(
        tester,
        random,
        selection,
      );
      final RemovableTag tag = tester.widget<RemovableTag>(
        find.byType(RemovableTag),
      );

      tag.onRemoved(tag.label);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(changes, hasLength(1));
      expect(changes.single.workspaceIds, <WorkspaceId>[
        for (final WorkspaceId workspaceId in selection.workspaceIds)
          if (workspaceId != known.single) workspaceId,
      ]);
    }
  });
}
