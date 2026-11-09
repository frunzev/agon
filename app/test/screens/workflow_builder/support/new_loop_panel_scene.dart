import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../../support/random_inputs.dart';
import '../../../support/widget_harness.dart';
import '../../support/random_page_windows.dart';
import 'random_connection_scenes.dart';

const String loopCancelLabel = 'Cancel';

final class LoopPanelLog {
  final List<AgentConnection> addedLoops = <AgentConnection>[];
  final TapCounter cancels = TapCounter();
}

ConnectionScene randomDrawnLoopScene(Random random) {
  ConnectionScene scene = randomConnectionScene(random);
  while (scene.connection.isLoop) {
    scene = randomConnectionScene(random);
  }
  final AgentConnection forward = scene.connection;
  return ConnectionScene(
    workflow: scene.workflow,
    connection: AgentConnection(
      from: forward.to,
      to: forward.from,
      condition: null,
      roundLimit: null,
    ),
  );
}

double randomLoopPanelWidth(Random random) {
  return randomWidth(random, least: narrowestWidth, most: widestWidth);
}

Future<LoopPanelLog> pumpLoopPanel(
  WidgetTester tester,
  Random random,
  ConnectionScene scene, {
  Key? key,
  double? width,
}) async {
  final LoopPanelLog log = LoopPanelLog();
  await pumpScrollableAtWidth(
    tester,
    width: width ?? randomLoopPanelWidth(random),
    child: NewLoopPanel(
      key: key ?? UniqueKey(),
      workflow: scene.workflow,
      connection: scene.connection,
      onLoopAdded: log.addedLoops.add,
      onCancelled: log.cancels.countTap,
    ),
  );
  return log;
}

Future<void> typeLoopOutcome(WidgetTester tester, String typed) async {
  await tester.enterText(find.byType(TextField), typed);
  await tester.pump();
}

Future<void> tapAddLoop(WidgetTester tester) async {
  await tapShownText(tester, addLoopLabel);
}
