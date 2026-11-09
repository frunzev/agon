import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/widgets/forms/removable_tag.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'pairing_flow_harness.dart';

const String workspacesLabel = 'Workspaces';
const int _largestStepCount = 8;

Future<PairingPage> openRandomApproval(
  WidgetTester tester,
  Random random,
  List<Workspace> workspaces,
) {
  return openApprovalPage(
    tester,
    size: randomPairingWindow(random),
    request: randomPairingRequest(random),
    workspaces: workspaces,
  );
}

List<String> readShownTags(WidgetTester tester) {
  return <String>[
    for (final RemovableTag tag in tester.widgetList<RemovableTag>(
      find.byType(RemovableTag),
    ))
      tag.label,
  ];
}

Future<void> removeWorkspaceTag(WidgetTester tester, String name) async {
  final Finder remove = find.descendant(
    of: find.widgetWithText(RemovableTag, name),
    matching: find.byType(InkWell),
  );
  await tapVisible(tester, remove);
  await tester.pump();
}

Workspace renameAsSpare(Workspace workspace) {
  return Workspace(
    id: WorkspaceId('spare-${workspace.id.value}'),
    name: 'spare-${workspace.name}',
    appServerAddress: workspace.appServerAddress,
    protectedFiles: workspace.protectedFiles,
    approvalPolicy: workspace.approvalPolicy,
  );
}

List<String> listWorkspaceNames(List<Workspace> workspaces) {
  return <String>[
    for (final Workspace workspace in workspaces) workspace.name,
  ];
}

WorkspaceId findWorkspaceId(List<Workspace> workspaces, String name) {
  return workspaces.singleWhere((Workspace each) => each.name == name).id;
}

Future<List<String>> changeChosenWorkspacesRandomly(
  WidgetTester tester,
  Random random,
  List<Workspace> workspaces,
) async {
  final List<String> chosen = <String>[workspaces.first.name];
  final int stepCount = random.nextInt(_largestStepCount);
  for (int step = 0; step < stepCount; step += 1) {
    if (chosen.isNotEmpty && random.nextBool()) {
      final String removed = pickOne(random, chosen);
      await removeWorkspaceTag(tester, removed);
      chosen.remove(removed);
    } else {
      final String added = pickOne(random, listWorkspaceNames(workspaces));
      await addFieldTag(tester, label: workspacesLabel, tag: added);
      if (!chosen.contains(added)) {
        chosen.add(added);
      }
    }
    expect(readShownTags(tester), chosen);
  }
  return chosen;
}
