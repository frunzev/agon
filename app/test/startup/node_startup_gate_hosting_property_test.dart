import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/app.dart';
import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/startup/hosting_problem.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/node_startup.dart';
import 'package:agent_orchestration/startup/node_startup_gate.dart';
import 'package:agent_orchestration/startup/startup_pages.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const String _problemTitle = 'This device could not start';
const int _largestRetries = 3;
const List<String> _nodeHostingProblems = <String>[
  'the app server cannot listen on port 8731: address in use',
  'could not encode or decode JSON: expected value at line 1',
  'the app server cannot listen on port 1: permission denied',
];
const List<node.HostingProblemKind?> _hostingProblemKinds =
    <node.HostingProblemKind?>[...node.HostingProblemKind.values, null];

final class _HostingStarts {
  final List<Completer<StartedApp>> appStarts = <Completer<StartedApp>>[];
  final List<Completer<StartedApp>> newDeviceStarts =
      <Completer<StartedApp>>[];

  Future<StartedApp> startApp() => _record(appStarts);

  Future<StartedApp> startAppAsNewDevice() => _record(newDeviceStarts);

  Future<StartedApp> _record(List<Completer<StartedApp>> starts) {
    final Completer<StartedApp> start = Completer<StartedApp>();
    starts.add(start);
    return start.future;
  }
}

StartedApp _buildStartedApp(AppRoute initialRoute) {
  return StartedApp(
    dependencies: buildGalleryDependencies(),
    navigation: AppNavigation(initialRoute: initialRoute),
  );
}

Widget _buildStartedAppWidget(StartedApp started) {
  return AgentOrchestrationApp(
    dependencies: started.dependencies,
    navigation: started.navigation,
    messengerKey: GlobalKey<ScaffoldMessengerState>(),
    runWindowOpener: null,
  );
}

Size _randomWindowSize(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  return Size(width, pickOne(random, <double>[phoneHeight, desktopHeight]));
}

String _randomHostingText(Random random) {
  final String nodeProblem = pickOne(random, _nodeHostingProblems);
  return '$nodeProblem ${randomWordPhrase(random)}'.trim();
}

HostingProblem _randomHostingProblem(
  Random random, {
  required node.HostingProblemKind? kind,
}) {
  return HostingProblem(_randomHostingText(random), kind: kind);
}

HostingProblem _randomDamagedRecordProblem(Random random) {
  return _randomHostingProblem(
    random,
    kind: node.HostingProblemKind.recordDamaged,
  );
}

HostingProblem _randomAnyHostingProblem(Random random) {
  return _randomHostingProblem(
    random,
    kind: pickOne(random, _hostingProblemKinds),
  );
}

Future<void> _pumpGateFailingWith(
  WidgetTester tester, {
  required int iteration,
  required Size size,
  required _HostingStarts starts,
  required HostingProblem hostingProblem,
}) async {
  useViewSize(tester, size);
  final NodeStartup startup = NodeStartup(
    startApp: starts.startApp,
    startAppAsNewDevice: starts.startAppAsNewDevice,
  );
  startup.start();
  await tester.pumpWidget(
    NodeStartupGate(
      key: ValueKey<int>(iteration),
      startup: startup,
      buildStartedApp: _buildStartedAppWidget,
    ),
  );
  starts.appStarts.last.completeError(hostingProblem);
  await tester.pump();
}

void main() {
  testWidgets('test_choose_set_up_again_action_property_only_a_damaged_'
      'record_offers_setting_up_again', (WidgetTester tester) async {
    final Random random = seededRandom(95301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = _randomWindowSize(random);
      final HostingProblem problem = _randomAnyHostingProblem(random);
      final _HostingStarts starts = _HostingStarts();

      await _pumpGateFailingWith(
        tester,
        iteration: i,
        size: size,
        starts: starts,
        hostingProblem: problem,
      );

      final bool isDamaged =
          problem.kind == node.HostingProblemKind.recordDamaged;
      final String reason = 'size $size, kind ${problem.kind}';
      expect(tester.takeException(), isNull, reason: reason);
      expect(find.text(_problemTitle), findsOneWidget, reason: reason);
      expect(find.text(problem.message), findsOneWidget, reason: reason);
      expect(find.text(retryStartupLabel), findsOneWidget, reason: reason);
      expect(
        find.text(setUpDeviceAgainLabel),
        isDamaged ? findsOneWidget : findsNothing,
        reason: reason,
      );
      expect(starts.newDeviceStarts, isEmpty, reason: reason);
    }
  });

  testWidgets('test_choose_set_up_again_action_property_a_taken_port_'
      'offers_only_try_again', (WidgetTester tester) async {
    final Random random = seededRandom(95302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HostingProblem problem = _randomHostingProblem(
        random,
        kind: node.HostingProblemKind.portUnavailable,
      );
      final _HostingStarts starts = _HostingStarts();
      await _pumpGateFailingWith(
        tester,
        iteration: i,
        size: _randomWindowSize(random),
        starts: starts,
        hostingProblem: problem,
      );

      expect(find.text(problem.message), findsOneWidget);
      expect(find.text(setUpDeviceAgainLabel), findsNothing);
      await tester.tap(find.text(retryStartupLabel));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(StartupWaitingPage), findsOneWidget);
      expect(starts.appStarts, hasLength(2));
      expect(starts.newDeviceStarts, isEmpty);
    }
  });

  testWidgets('test_choose_set_up_again_action_property_set_up_again_'
      'starts_a_new_device_once', (WidgetTester tester) async {
    final Random random = seededRandom(95303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _HostingStarts starts = _HostingStarts();
      await _pumpGateFailingWith(
        tester,
        iteration: i,
        size: _randomWindowSize(random),
        starts: starts,
        hostingProblem: _randomDamagedRecordProblem(random),
      );

      await tester.tap(find.text(setUpDeviceAgainLabel));
      await tester.pump();
      expect(find.byType(StartupWaitingPage), findsOneWidget);
      starts.newDeviceStarts.single.complete(
        _buildStartedApp(const SetupRoleRoute()),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(AgentOrchestrationApp), findsOneWidget);
      expect(starts.appStarts, hasLength(1));
      expect(starts.newDeviceStarts, hasLength(1));
    }
  });

  testWidgets('test_choose_set_up_again_action_property_only_the_latest_'
      'problem_decides', (WidgetTester tester) async {
    final Random random = seededRandom(95304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _HostingStarts starts = _HostingStarts();
      await _pumpGateFailingWith(
        tester,
        iteration: i,
        size: _randomWindowSize(random),
        starts: starts,
        hostingProblem: _randomDamagedRecordProblem(random),
      );
      final HostingProblem portProblem = _randomHostingProblem(
        random,
        kind: node.HostingProblemKind.portUnavailable,
      );

      await tester.tap(find.text(retryStartupLabel));
      await tester.pump();
      starts.appStarts.last.completeError(portProblem);
      await tester.pump();
      expect(find.text(portProblem.message), findsOneWidget);
      expect(find.text(setUpDeviceAgainLabel), findsNothing);

      final HostingProblem damagedProblem = _randomDamagedRecordProblem(
        random,
      );
      await tester.tap(find.text(retryStartupLabel));
      await tester.pump();
      starts.appStarts.last.completeError(damagedProblem);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(damagedProblem.message), findsOneWidget);
      expect(find.text(setUpDeviceAgainLabel), findsOneWidget);
      expect(starts.newDeviceStarts, isEmpty);
    }
  });

  testWidgets('test_node_startup_gate_build_property_try_again_after_'
      'hosting_problems_starts_the_app', (WidgetTester tester) async {
    final Random random = seededRandom(95305);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int retries = random.nextInt(_largestRetries);
      final _HostingStarts starts = _HostingStarts();
      await _pumpGateFailingWith(
        tester,
        iteration: i,
        size: _randomWindowSize(random),
        starts: starts,
        hostingProblem: _randomAnyHostingProblem(random),
      );

      for (int retry = 0; retry < retries; retry += 1) {
        final HostingProblem problem = _randomAnyHostingProblem(random);
        await tester.tap(find.text(retryStartupLabel));
        await tester.pump();
        starts.appStarts.last.completeError(problem);
        await tester.pump();
        expect(find.text(problem.message), findsOneWidget);
      }
      await tester.tap(find.text(retryStartupLabel));
      await tester.pump();
      starts.appStarts.last.complete(_buildStartedApp(const SetupRoleRoute()));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(AgentOrchestrationApp), findsOneWidget);
      expect(starts.appStarts, hasLength(retries + 2));
      expect(starts.newDeviceStarts, isEmpty);
    }
  });
}
