import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/problem_messenger.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/node_startup.dart';
import 'package:agent_orchestration/startup/single_window_app.dart';
import 'package:agent_orchestration/startup/startup_stage.dart';

import 'app_harness.dart';

const SectionRoute galleryStartRoute = SectionRoute(AppSection.tasks);

StartedApp readStartedApp(NodeStartup startup) {
  final StartupStage stage = startup.stage;
  if (stage is! StartupFinished) {
    throw StateError('the gallery start did not finish: $stage');
  }
  return stage.started;
}

Future<void> pumpStartedGate(
  WidgetTester tester, {
  required NodeStartup startup,
  required MessengerKey messengerKey,
}) async {
  startup.start();
  await tester.pumpWidget(
    buildSingleWindowGate(startup: startup, messengerKey: messengerKey),
  );
  await tester.pump();
  await tester.pump(settleTime);
}
