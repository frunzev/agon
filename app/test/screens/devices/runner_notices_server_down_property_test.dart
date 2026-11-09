import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';

import '../../support/random_inputs.dart';
import 'support/random_devices_page.dart';

const String _serverDownTitle = "Can't reach the app server";
const String _tryNowLabel = 'Try now';

void main() {
  testWidgets('test_build_server_down_banner_property_names_relay_runners', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73509);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await pumpRandomDevicesPage(
        tester,
        random,
      );
      final List<Runner> runners = dependencies.runnerRepository.listRunners();
      if (!isAppServerDown(dependencies) || runners.isEmpty) {
        continue;
      }

      final List<String> waitingNames = <String>[
        for (final Runner runner in runners)
          if (runner.online && runner.link == RunnerLink.relay)
            dependencies.deviceRepository.findDevice(runner.deviceId).name,
      ];
      final String notice = describeServerDownNotice(waitingNames);
      expect(findBannerText(_serverDownTitle, notice), findsOneWidget);
    }
  });

  testWidgets('test_build_server_down_banner_property_tells_the_retry_pace', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73510);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await pumpRandomDevicesPage(
        tester,
        random,
      );
      final List<Runner> runners = dependencies.runnerRepository.listRunners();
      if (!isAppServerDown(dependencies) || runners.isEmpty) {
        continue;
      }

      final AppServerStatus status = dependencies.workspaceRepository
          .findAppServerStatus();
      final String retry = describeServerRetry(status);
      expect(findBannerText(_serverDownTitle, retry), findsOneWidget);
      expect(findBannerText(_serverDownTitle, _tryNowLabel), findsOneWidget);
    }
  });

  testWidgets('test_build_server_down_banner_property_retry_clears_it', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73511);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await pumpRandomDevicesPage(
        tester,
        random,
      );
      final bool showsBanner =
          isAppServerDown(dependencies) &&
          dependencies.runnerRepository.listRunners().isNotEmpty;
      if (!showsBanner) {
        continue;
      }

      final Finder tryNow = findBannerText(_serverDownTitle, _tryNowLabel);
      await tester.ensureVisible(tryNow);
      await tester.tap(tryNow);
      await tester.pump();
      await tester.pump();

      expect(find.text(_serverDownTitle), findsNothing);
      expect(isAppServerDown(dependencies), isFalse);
    }
  });
}
