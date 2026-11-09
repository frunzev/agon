import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/app.dart';
import 'package:agent_orchestration/shell/problem_messenger.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/node_startup.dart';
import 'package:agent_orchestration/startup/node_startup_gate.dart';

Widget buildSingleWindowGate({
  required NodeStartup startup,
  required MessengerKey messengerKey,
}) {
  return NodeStartupGate(
    startup: startup,
    buildStartedApp: (StartedApp started) =>
        _buildSingleWindowApp(started, messengerKey),
  );
}

Widget _buildSingleWindowApp(StartedApp started, MessengerKey messengerKey) {
  return AgentOrchestrationApp(
    dependencies: started.dependencies,
    navigation: started.navigation,
    messengerKey: messengerKey,
    runWindowOpener: null,
  );
}
