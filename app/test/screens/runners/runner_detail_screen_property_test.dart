import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';
import 'package:agent_orchestration/screens/runners.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/route_line.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/runner_pages.dart';
import '../support/runner_detail_harness.dart';

const String _pauseLabel = 'Pause new runs';
const String _resumeLabel = 'Resume new runs';

Device _findDevice(RunnerDetailPage page) {
  return buildRunnerDevices(peerAddressProblem: null)
      .findDevice(page.runnerId);
}

String _describeExpectedSummary(RunnerDetailPage page) {
  final Runner runner = page.findRunner();
  final Device device = _findDevice(page);
  final String lastSeen = describeLastSeen(
    device.lastSeen,
    buildGalleryDependencies().clock.now(),
  );
  return describeRunnerSummary(
    runner: runner,
    reach: findRunnerReach(runner, page.serverState),
    lastSeen: lastSeen.toLowerCase(),
  );
}

RunnerDetailScreen _buildScreen(
  AppDependencies dependencies,
  DeviceId deviceId,
) {
  return RunnerDetailScreen(
    deviceId: deviceId,
    runnerRepository: dependencies.runnerRepository,
    agentLoginRepository: dependencies.agentLoginRepository,
    deviceRepository: dependencies.deviceRepository,
    workspaceRepository: dependencies.workspaceRepository,
    taskRepository: dependencies.taskRepository,
    jobRepository: dependencies.jobRepository,
    workflowRepository: dependencies.workflowRepository,
    clock: dependencies.clock,
    navigation: AppNavigation(
      initialRoute: const SectionRoute(AppSection.devices),
    ),
  );
}

void main() {
  test('test_runner_detail_screen_constructor_property_keeps_fields', () {
    final Random random = seededRandom(108801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = AppNavigation(
        initialRoute: const SectionRoute(AppSection.devices),
      );

      final RunnerDetailScreen screen = RunnerDetailScreen(
        deviceId: pickOne(random, runnerPageDeviceIds),
        runnerRepository: dependencies.runnerRepository,
        agentLoginRepository: dependencies.agentLoginRepository,
        deviceRepository: dependencies.deviceRepository,
        workspaceRepository: dependencies.workspaceRepository,
        taskRepository: dependencies.taskRepository,
        jobRepository: dependencies.jobRepository,
        workflowRepository: dependencies.workflowRepository,
        clock: dependencies.clock,
        navigation: navigation,
      );

      expect(screen.runnerRepository, same(dependencies.runnerRepository));
      expect(screen.deviceRepository, same(dependencies.deviceRepository));
      expect(screen.taskRepository, same(dependencies.taskRepository));
      expect(screen.clock, same(dependencies.clock));
      expect(screen.navigation, same(navigation));
      expect(runnerPageDeviceIds, contains(screen.deviceId));
    }
  });

  test('test_runner_detail_screen_constructor_property_any_device', () {
    final AppDependencies dependencies = buildGalleryDependencies();

    for (final DeviceId deviceId in runnerPageDeviceIds) {
      final RunnerDetailScreen screen = _buildScreen(dependencies, deviceId);

      expect(screen.deviceId, deviceId);
      expect(screen.key, isNull);
    }
  });

  test('test_runner_detail_screen_constructor_property_calls_nothing', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final FakeRunnerRepository runners =
        dependencies.runnerRepository as FakeRunnerRepository;
    final List<Runner> before = runners.listRunners();

    for (final DeviceId deviceId in runnerPageDeviceIds) {
      final RunnerDetailScreen screen = _buildScreen(dependencies, deviceId);

      expect(screen.navigation.currentRoute, isA<SectionRoute>());
      expect(runners.listRunners(), before);
    }
  });

  testWidgets('test_runner_detail_screen_build_property_every_runner_shows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);

      expect(tester.takeException(), isNull);
      expect(find.text(_findDevice(page).name), findsWidgets);
      expect(find.text(_describeExpectedSummary(page)), findsOneWidget);
      expect(find.text('How runs work here'), findsOneWidget);
      expect(find.text('Running now'), findsOneWidget);
    }
  });

  testWidgets('test_runner_detail_screen_build_property_follows_the_runner', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);

      if (page.findRunner().acceptingNewRuns) {
        await page.runners.pauseRunner(page.runnerId);
      } else {
        await page.runners.resumeRunner(page.runnerId);
      }
      await pumpFrames(tester);

      final bool isAccepting = page.findRunner().acceptingNewRuns;
      expect(find.text(isAccepting ? _pauseLabel : _resumeLabel), findsOne);
      expect(find.text(_describeExpectedSummary(page)), findsOneWidget);
    }
  });

  testWidgets(
    'test_runner_detail_screen_build_property_back_goes_to_devices',
    (WidgetTester tester) async {
      final Random random = seededRandom(108804);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final RunnerDetailPage page = await openAnyRunnerPage(tester, random);

        await tester.tap(find.text('Devices').last);
        await pumpFrames(tester);

        expect(
          page.navigation.currentRoute,
          const SectionRoute(AppSection.devices),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('test_build_page_property_offers_only_on_this_device', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108805);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);

      final bool isThisDevice = page.isThisDevice();
      expect(
        find.byType(AgentOffersSection),
        findsNWidgets(isThisDevice ? 1 : 0),
      );
      expect(
        find.text(agentOffersTitle),
        isThisDevice ? findsWidgets : findsNothing,
      );
      expect(find.byType(RouteLine), findsNWidgets(isThisDevice ? 0 : 1));
    }
  });

  testWidgets('test_build_page_property_one_login_section_per_offer', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);

      final List<PlaceOffer>? offers = page.runners.findThisDeviceOffers();
      final int expected = page.isThisDevice() ? offers!.length : 0;
      expect(find.byType(AgentLoginSection), findsNWidgets(expected));
    }
  });

  testWidgets('test_build_page_property_summary_names_the_reach', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108807);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);
      final Runner runner = page.findRunner();

      final bool waitsForServer =
          runner.online &&
          runner.link == RunnerLink.relay &&
          page.serverState == AppServerState.unreachable;
      final Matcher waiting = waitsForServer ? findsOneWidget : findsNothing;
      expect(find.text('Unreachable · waits for the app server'), waiting);
      final Matcher offline = runner.online ? findsNothing : findsOneWidget;
      expect(find.textContaining('Offline · last seen '), offline);
    }
  });
}
