import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/devices/devices_screen.dart';
import 'package:agent_orchestration/screens/devices/runner_notices.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/inline_link.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'support/random_devices_page.dart';

const String _pageTitle = 'Devices';
const String _pairLabel = 'Pair a device';

List<String> _readHeaderSummary(WidgetTester tester) {
  final PageHeader header = tester.widget<PageHeader>(find.byType(PageHeader));
  return <String>[
    for (final TextSegment segment in header.summary) segment.text,
  ];
}

String? _describeSummaryByModel(
  AppDependencies dependencies,
  List<Runner> runners,
) {
  return describeRunnerSummary(
    runners: runners,
    serverState: dependencies.workspaceRepository.findAppServerStatus().state,
  );
}

double _readTop(WidgetTester tester, Finder target) {
  return tester.getTopLeft(target.first).dy;
}

Future<void> _tapAllDevicesLink(WidgetTester tester) async {
  final Finder link = find.widgetWithText(InlineLink, allDevicesSectionTitle);
  await tester.ensureVisible(link);
  await pumpFrames(tester);
  await tester.tap(link);
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_build_page_property_header_sums_up_runners', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await pumpRandomDevicesPage(
        tester,
        random,
      );

      final String? summary = _describeSummaryByModel(
        dependencies,
        dependencies.runnerRepository.listRunners(),
      );
      final PageHeader header = tester.widget<PageHeader>(
        find.byType(PageHeader),
      );
      expect(header.title, _pageTitle);
      expect(_readHeaderSummary(tester), <String>[?summary]);
    }
  });

  testWidgets('test_build_page_property_sections_in_page_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRandomDevicesPage(tester, random);

      final double headerTop = _readTop(tester, find.byType(PageHeader));
      final double workspaceTop = _readTop(
        tester,
        findDevicesSection(workspaceSectionTitle),
      );
      final double allDevicesTop = _readTop(
        tester,
        findDevicesSection(allDevicesSectionTitle),
      );
      expect(headerTop, lessThan(workspaceTop));
      expect(workspaceTop, lessThan(allDevicesTop));
    }
  });

  testWidgets('test_build_page_property_revoked_runner_not_summed', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73610);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await pumpRandomDevicesPage(
        tester,
        random,
      );
      final DeviceId thisDeviceId = dependencies.deviceRepository
          .currentDevice()
          .id;
      final List<Runner> otherRunners = <Runner>[
        for (final Runner runner
            in dependencies.runnerRepository.listRunners())
          if (runner.deviceId != thisDeviceId) runner,
      ];
      if (otherRunners.isEmpty) {
        continue;
      }
      final DeviceId revokedId = pickOne(random, otherRunners).deviceId;
      final List<Runner> keptRunners = <Runner>[
        for (final Runner runner
            in dependencies.runnerRepository.listRunners())
          if (runner.deviceId != revokedId) runner,
      ];

      await dependencies.deviceRepository.revokeDevice(revokedId);
      await pumpFrames(tester);

      final String? summary = _describeSummaryByModel(
        dependencies,
        keptRunners,
      );
      expect(_readHeaderSummary(tester), <String>[?summary]);
    }
  });

  testWidgets('test_show_all_devices_property_puts_pairing_in_view', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRandomDevicesPage(tester, random);

      await _tapAllDevicesLink(tester);

      final double pairTop = _readTop(tester, find.text(_pairLabel));
      final double windowHeight = tester.view.physicalSize.height;
      expect(tester.takeException(), isNull);
      expect(pairTop, inInclusiveRange(0, windowHeight));
    }
  });

  testWidgets('test_show_all_devices_property_is_idempotent', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRandomDevicesPage(tester, random);
      final Finder heading = findDevicesSection(allDevicesSectionTitle);

      await _tapAllDevicesLink(tester);
      final double firstTop = _readTop(tester, heading);
      await _tapAllDevicesLink(tester);
      final double secondTop = _readTop(tester, heading);

      expect(secondTop, moreOrLessEquals(firstTop));
    }
  });

  testWidgets('test_show_all_devices_property_stays_on_the_devices_route', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = await pumpDevicesPage(
        tester,
        random: random,
        dependencies: buildRandomDevicesDependencies(random),
      );
      final List<AppRoute> routesBefore = navigation.routes.toList();

      await _tapAllDevicesLink(tester);

      expect(navigation.routes, routesBefore);
    }
  });

  testWidgets('test_devices_screen_create_state_property_fresh_each_time', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73607);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRandomDevicesPage(tester, random);
      final DevicesScreen screen = tester.widget<DevicesScreen>(
        find.byType(DevicesScreen),
      );

      final State<DevicesScreen> first = screen.createState();
      final State<DevicesScreen> second = screen.createState();

      expect(identical(first, second), isFalse);
      expect(first.mounted, isFalse);
    }
  });

  testWidgets('test_devices_screen_create_state_property_state_shows_screen', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73608);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRandomDevicesPage(tester, random);

      final Finder screenFinder = find.byType(DevicesScreen);
      final State<DevicesScreen> state = tester.state<State<DevicesScreen>>(
        screenFinder,
      );
      expect(state.mounted, isTrue);
      expect(identical(state.widget, tester.widget(screenFinder)), isTrue);
    }
  });

  testWidgets('test_devices_screen_create_state_property_survives_changes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73609);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await pumpRandomDevicesPage(
        tester,
        random,
      );
      final Finder screenFinder = find.byType(DevicesScreen);
      final State<DevicesScreen> before = tester.state(screenFinder);

      await dependencies.workspaceRepository.retryAppServer();
      await pumpFrames(tester);

      final State<DevicesScreen> after = tester.state(screenFinder);
      expect(identical(after, before), isTrue);
    }
  });
}
