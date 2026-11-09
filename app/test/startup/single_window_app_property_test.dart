import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/shell/app_shell.dart';
import 'package:agent_orchestration/shell/problem_messenger.dart';
import 'package:agent_orchestration/startup/app_startup_choice.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/node_startup.dart';
import 'package:agent_orchestration/startup/single_window_app.dart';
import 'package:agent_orchestration/startup/startup_pages.dart';

import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

final class _ScriptedStarts {
  final List<Completer<StartedApp>> pendingStarts = <Completer<StartedApp>>[];

  Future<StartedApp> startOnce() {
    final Completer<StartedApp> pendingStart = Completer<StartedApp>();
    pendingStarts.add(pendingStart);
    return pendingStart.future;
  }
}

Future<NodeStartup> _pumpGate(
  WidgetTester tester,
  _ScriptedStarts scriptedStarts,
  Random random,
) async {
  final NodeStartup startup = NodeStartup(
    startApp: scriptedStarts.startOnce,
    startAppAsNewDevice: scriptedStarts.startOnce,
  );
  final Size windowSize = Size(
    randomWidth(random, least: narrowestWidth, most: widestWidth),
    desktopHeight,
  );
  useViewSize(tester, windowSize);
  await tester.pumpWidget(const SizedBox());
  startup.start();
  await tester.pumpWidget(
    buildSingleWindowGate(startup: startup, messengerKey: MessengerKey()),
  );
  return startup;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(settleTime);
}

void main() {
  testWidgets('test_build_single_window_gate_property_waits_until_the_start_'
      'finishes', (WidgetTester tester) async {
    final Random random = seededRandom(95301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ScriptedStarts scriptedStarts = _ScriptedStarts();
      await _pumpGate(tester, scriptedStarts, random);
      await _settle(tester);

      expect(find.byType(StartupWaitingPage), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);

      scriptedStarts.pendingStarts.single.complete(await startGallery());
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(StartupWaitingPage), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    }
  });

  testWidgets('test_build_single_window_gate_property_a_failed_start_offers_'
      'a_retry', (WidgetTester tester) async {
    final Random random = seededRandom(95302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ScriptedStarts scriptedStarts = _ScriptedStarts();
      final String problemText = 'Start broke ${randomWordPhrase(random)} #$i';
      await _pumpGate(tester, scriptedStarts, random);
      final Completer<StartedApp> failingStart =
          scriptedStarts.pendingStarts.single;
      failingStart.completeError(StateError(problemText));
      await _settle(tester);

      expect(find.byType(StartupProblemPage), findsOneWidget);
      expect(find.textContaining(problemText), findsOneWidget);

      await tester.tap(find.text(retryStartupLabel));
      await _settle(tester);

      expect(scriptedStarts.pendingStarts, hasLength(2));
      expect(find.byType(StartupWaitingPage), findsOneWidget);
      scriptedStarts.pendingStarts.last.complete(await startGallery());
      await _settle(tester);
      expect(find.byType(AppShell), findsOneWidget);
    }
  });

  testWidgets('test_build_single_window_gate_property_only_the_latest_start_'
      'is_shown', (WidgetTester tester) async {
    final Random random = seededRandom(95303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ScriptedStarts scriptedStarts = _ScriptedStarts();
      final NodeStartup startup = await _pumpGate(
        tester,
        scriptedStarts,
        random,
      );
      final StartedApp staleStart = await startGallery();
      final StartedApp latestStart = await startGallery();
      startup.setUpAgain();

      scriptedStarts.pendingStarts.first.complete(staleStart);
      await _settle(tester);
      expect(find.byType(StartupWaitingPage), findsOneWidget);

      scriptedStarts.pendingStarts.last.complete(latestStart);
      await _settle(tester);
      final AppShell shell = tester.widget<AppShell>(find.byType(AppShell));
      expect(identical(shell.dependencies, latestStart.dependencies), isTrue);
      expect(identical(shell.navigation, latestStart.navigation), isTrue);
    }
  });
}
