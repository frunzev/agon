import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'pairing_approval_steps.dart';
import 'pairing_flow_harness.dart';

const String _approveLabel = 'Approve';

void main() {
  testWidgets('test_add_workspace_property_each_workspace_is_added_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(104907);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workspace> workspaces = randomWorkspaces(random);
      await openRandomApproval(tester, random, workspaces);
      final String added = pickOne(random, listWorkspaceNames(workspaces));

      final int repeatCount = 1 + random.nextInt(3);
      for (int repeat = 0; repeat < repeatCount; repeat += 1) {
        await addFieldTag(tester, label: workspacesLabel, tag: added);
      }

      final List<String> shown = readShownTags(tester);
      expect(shown.where((String name) => name == added), hasLength(1));
      expect(shown.toSet(), hasLength(shown.length));
    }
  });

  testWidgets('test_add_workspace_property_approval_sends_the_chosen_ids', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(104908);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workspace> workspaces = randomWorkspaces(random);
      final PairingPage page = await openRandomApproval(
        tester,
        random,
        workspaces,
      );
      final List<String> chosen = await changeChosenWorkspacesRandomly(
        tester,
        random,
        workspaces,
      );
      if (chosen.isEmpty) {
        continue;
      }

      await tapButtonLabelled(tester, _approveLabel);

      expect(page.pairing.approvedWorkspaces.single, <WorkspaceId>[
        for (final String name in chosen) findWorkspaceId(workspaces, name),
      ]);
    }
  });

  testWidgets('test_add_workspace_property_names_outside_the_list_are_'
      'ignored', (WidgetTester tester) async {
    final Random random = seededRandom(104909);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workspace> workspaces = randomWorkspaces(random);
      await openRandomApproval(tester, random, workspaces);

      await addFieldTag(
        tester,
        label: workspacesLabel,
        tag: 'missing ${randomText(random)}',
      );

      expect(readShownTags(tester), <String>[workspaces.first.name]);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_remove_workspace_property_removes_only_that_one', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(104910);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workspace> workspaces = randomWorkspaces(random);
      await openRandomApproval(tester, random, workspaces);
      for (final String name in listWorkspaceNames(workspaces)) {
        await addFieldTag(tester, label: workspacesLabel, tag: name);
      }
      final String removed = pickOne(random, listWorkspaceNames(workspaces));

      await removeWorkspaceTag(tester, removed);

      expect(readShownTags(tester), <String>[
        for (final String name in listWorkspaceNames(workspaces))
          if (name != removed) name,
      ]);
    }
  });

  testWidgets('test_remove_workspace_property_removed_workspaces_are_not_'
      'approved', (WidgetTester tester) async {
    final Random random = seededRandom(104911);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workspace> workspaces = randomWorkspaces(random);
      final PairingPage page = await openRandomApproval(
        tester,
        random,
        workspaces,
      );
      final String kept = pickOne(random, listWorkspaceNames(workspaces));
      await addFieldTag(tester, label: workspacesLabel, tag: kept);
      if (kept != workspaces.first.name) {
        await removeWorkspaceTag(tester, workspaces.first.name);
      }

      await tapButtonLabelled(tester, _approveLabel);

      expect(page.pairing.approvedWorkspaces.single, <WorkspaceId>[
        findWorkspaceId(workspaces, kept),
      ]);
    }
  });

  testWidgets('test_remove_workspace_property_removing_all_blocks_'
      'approval', (WidgetTester tester) async {
    final Random random = seededRandom(104912);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workspace> workspaces = randomWorkspaces(random);
      final PairingPage page = await openRandomApproval(
        tester,
        random,
        workspaces,
      );

      await removeWorkspaceTag(tester, workspaces.first.name);
      await tapButtonLabelled(tester, _approveLabel);

      expect(readShownTags(tester), isEmpty);
      expect(page.pairing.approvedWorkspaces, isEmpty);
      expect(page.pairing.findPendingRequest(), isNotNull);
    }
  });
}
