import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/widgets/forms/tag_input_field.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'pairing_approval_steps.dart';
import 'pairing_flow_harness.dart';

const String _noWorkspaceProblem = 'Choose at least one workspace';
const String _approveLabel = 'Approve';

void main() {
  testWidgets('test_build_workspace_catalog_property_suggests_every_'
      'workspace', (WidgetTester tester) async {
    final Random random = seededRandom(104901);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workspace> workspaces = randomWorkspaces(random);

      await openRandomApproval(tester, random, workspaces);

      final TagInputField field = tester.widget(find.byType(TagInputField));
      expect(field.suggestions, listWorkspaceNames(workspaces));
    }
  });

  testWidgets('test_build_workspace_catalog_property_follows_created_'
      'workspaces', (WidgetTester tester) async {
    final Random random = seededRandom(104902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workspace> workspaces = randomWorkspaces(random);
      final PairingPage page = await openRandomApproval(
        tester,
        random,
        workspaces,
      );
      final String created = 'new-${random.nextInt(1000)}';

      await page.dependencies.workspaceRepository.createWorkspace(
        name: created,
      );
      await pumpFrames(tester);
      await addFieldTag(tester, label: workspacesLabel, tag: created);

      expect(readShownTags(tester), <String>[workspaces.first.name, created]);
    }
  });

  testWidgets('test_build_workspace_catalog_property_survives_a_deleted_'
      'chosen_workspace', (WidgetTester tester) async {
    final Random random = seededRandom(104903);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workspace> workspaces = <Workspace>[
        ...randomWorkspaces(random),
        ...randomWorkspaces(random).map(renameAsSpare),
      ];
      final PairingPage page = await openRandomApproval(
        tester,
        random,
        workspaces,
      );

      await page.dependencies.workspaceRepository.deleteWorkspace(
        workspaces.first.id,
      );
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(readShownTags(tester), isNot(contains(workspaces.first.name)));
    }
  });

  testWidgets('test_build_workspace_field_property_problem_only_after_'
      'approving_with_none', (WidgetTester tester) async {
    final Random random = seededRandom(104904);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workspace> workspaces = randomWorkspaces(random);
      final PairingPage page = await openRandomApproval(
        tester,
        random,
        workspaces,
      );

      await removeWorkspaceTag(tester, workspaces.first.name);
      expect(find.text(_noWorkspaceProblem), findsNothing);
      await tapButtonLabelled(tester, _approveLabel);

      expect(find.text(_noWorkspaceProblem), findsOneWidget);
      expect(page.pairing.calls, isEmpty);
      await addFieldTag(
        tester,
        label: workspacesLabel,
        tag: pickOne(random, listWorkspaceNames(workspaces)),
      );
      expect(find.text(_noWorkspaceProblem), findsNothing);
    }
  });

  testWidgets('test_build_workspace_field_property_tags_show_names_in_'
      'chosen_order', (WidgetTester tester) async {
    final Random random = seededRandom(104905);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workspace> workspaces = randomWorkspaces(random);
      await openRandomApproval(tester, random, workspaces);

      final List<String> chosen = await changeChosenWorkspacesRandomly(
        tester,
        random,
        workspaces,
      );

      expect(readShownTags(tester), chosen);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_build_workspace_field_property_fits_every_workspace_'
      'at_any_width', (WidgetTester tester) async {
    final Random random = seededRandom(104906);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workspace> workspaces = randomWorkspaces(random);
      await openRandomApproval(tester, random, workspaces);

      for (final String name in listWorkspaceNames(workspaces)) {
        await addFieldTag(tester, label: workspacesLabel, tag: name);
      }

      expect(readShownTags(tester), listWorkspaceNames(workspaces));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_list_chosen_workspace_ids_property_a_deleted_workspace_'
      'is_not_approved', (WidgetTester tester) async {
    final Random random = seededRandom(104916);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workspace> workspaces = <Workspace>[
        ...randomWorkspaces(random),
        ...randomWorkspaces(random).map(renameAsSpare),
      ];
      final PairingPage page = await openRandomApproval(
        tester,
        random,
        workspaces,
      );
      final Workspace kept = workspaces.last;
      await addFieldTag(tester, label: workspacesLabel, tag: kept.name);

      await page.dependencies.workspaceRepository.deleteWorkspace(
        workspaces.first.id,
      );
      await pumpFrames(tester);
      await tapButtonLabelled(tester, _approveLabel);

      expect(page.pairing.approvedWorkspaces.single, <WorkspaceId>[kept.id]);
    }
  });

  testWidgets('test_list_chosen_workspace_ids_property_survivors_keep_'
      'their_order', (WidgetTester tester) async {
    final Random random = seededRandom(104917);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workspace> workspaces = <Workspace>[
        ...randomWorkspaces(random),
        ...randomWorkspaces(random).map(renameAsSpare),
      ];
      final PairingPage page = await openRandomApproval(
        tester,
        random,
        workspaces,
      );
      final List<String> names = listWorkspaceNames(workspaces);
      for (final String name in names) {
        await addFieldTag(tester, label: workspacesLabel, tag: name);
      }
      final Workspace deleted = pickOne(random, workspaces);

      await page.dependencies.workspaceRepository.deleteWorkspace(deleted.id);
      await pumpFrames(tester);

      expect(readShownTags(tester), <String>[
        for (final String name in names)
          if (name != deleted.name) name,
      ]);
    }
  });

  testWidgets('test_list_chosen_workspace_ids_property_losing_every_chosen_'
      'workspace_blocks_approval', (WidgetTester tester) async {
    final Random random = seededRandom(104918);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workspace> workspaces = <Workspace>[
        ...randomWorkspaces(random),
        ...randomWorkspaces(random).map(renameAsSpare),
      ];
      final PairingPage page = await openRandomApproval(
        tester,
        random,
        workspaces,
      );

      await page.dependencies.workspaceRepository.deleteWorkspace(
        workspaces.first.id,
      );
      await pumpFrames(tester);
      await tapButtonLabelled(tester, _approveLabel);

      expect(find.text(_noWorkspaceProblem), findsOneWidget);
      expect(page.pairing.approvedWorkspaces, isEmpty);
      expect(page.pairing.findPendingRequest(), isNotNull);
    }
  });
}
