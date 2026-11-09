import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/runner_text.dart'
    hide describeRunnerSummary;
import 'package:agent_orchestration/screens/devices/runner_notices.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'support/random_devices_page.dart';

const String _serverDownTitle = "Can't reach the app server";
const String _pausedText = 'Paused';

Future<AppDependencies> _pumpCompactRandomPage(
  WidgetTester tester,
  Random random,
) async {
  final AppDependencies dependencies = buildRandomDevicesDependencies(random);
  await pumpCompactDevicesPage(
    tester,
    random: random,
    dependencies: dependencies,
  );
  return dependencies;
}

void main() {
  testWidgets('test_devices_screen_build_property_follows_device_changes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(74201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await _pumpCompactRandomPage(
        tester,
        random,
      );
      final Device thisDevice = dependencies.deviceRepository.currentDevice();
      final List<Device> others = <Device>[
        for (final Device device
            in dependencies.deviceRepository.listDevices())
          if (!device.revoked && device.id != thisDevice.id) device,
      ];
      if (others.isEmpty) {
        continue;
      }
      final Device revoked = pickOne(random, others);

      await dependencies.deviceRepository.revokeDevice(revoked.id);
      await pumpFrames(tester);

      expect(findSectionRow(allDevicesSectionTitle, revoked.id), findsNothing);
      expect(findSectionRow(workspaceSectionTitle, revoked.id), findsNothing);
    }
  });

  testWidgets('test_devices_screen_build_property_follows_server_changes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(74202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await pumpRandomDevicesPage(
        tester,
        random,
      );

      await dependencies.workspaceRepository.retryAppServer();
      await pumpFrames(tester);

      final List<Runner> runners = dependencies.runnerRepository.listRunners();
      final String? summary = describeRunnerSummary(
        runners: runners,
        serverState: AppServerState.online,
      );
      expect(find.text(_serverDownTitle), findsNothing);
      if (summary != null) {
        expect(find.text(summary, findRichText: true), findsOneWidget);
      }
    }
  });

  testWidgets('test_devices_screen_build_property_follows_runner_changes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(74203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await _pumpCompactRandomPage(
        tester,
        random,
      );
      final AppServerState serverState = dependencies.workspaceRepository
          .findAppServerStatus()
          .state;
      final List<Runner> running = <Runner>[
        for (final Runner runner
            in dependencies.runnerRepository.listRunners())
          if (runner.acceptingNewRuns &&
              findRunnerReach(runner, serverState) == RunnerReach.reachable)
            runner,
      ];
      if (running.isEmpty) {
        continue;
      }
      final Runner paused = pickOne(random, running);
      final Finder row = findSectionRow(
        workspaceSectionTitle,
        paused.deviceId,
      );
      expect(findTextInRow(row, _pausedText), findsNothing);

      await dependencies.runnerRepository.pauseRunner(paused.deviceId);
      await pumpFrames(tester);

      expect(findTextInRow(row, _pausedText), findsOneWidget);
    }
  });
}
