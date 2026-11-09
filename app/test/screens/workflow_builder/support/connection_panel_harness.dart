import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../../support/widget_harness.dart';
import 'random_connection_scenes.dart';

const String removedEvent = 'removed';
const String doneEvent = 'done';

final class ConnectionPanelLog {
  final List<AgentConnection> changes = <AgentConnection>[];
  final List<String> events = <String>[];

  ConnectionSettingsPanel buildPanel(ConnectionScene scene, {Key? key}) {
    return ConnectionSettingsPanel(
      key: key,
      workflow: scene.workflow,
      connection: scene.connection,
      onConnectionChanged: changes.add,
      onRemoved: () => events.add(removedEvent),
      onDone: () => events.add(doneEvent),
    );
  }
}

TextField findShownOutcomeField(WidgetTester tester) {
  return tester.widget<TextField>(find.byType(TextField));
}

String? findShownOutcomeProblem(WidgetTester tester) {
  return findShownOutcomeField(tester).decoration?.errorText;
}

Future<void> pumpFreshConnectionPanel(
  WidgetTester tester, {
  required double width,
  required ConnectionSettingsPanel panel,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScrollableAtWidth(tester, width: width, child: panel);
}
