import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_shell.dart';
import 'package:agent_orchestration/shell/problem_messenger.dart';
import 'package:agent_orchestration/startup/app_startup_choice.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/node_startup.dart';

import 'support/app_harness.dart';
import 'support/main_wiring_harness.dart';
import 'support/random_inputs.dart';
import 'support/widget_harness.dart';

const double _lowestWindowHeight = 600;

Size _randomWindowSize(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  final double height = randomWidth(
    random,
    least: _lowestWindowHeight,
    most: desktopHeight,
  );
  return Size(width, height);
}

void main() {
  test('test_start_gallery_property_every_start_is_fresh', () async {
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StartedApp firstStart = await startGallery();
      final StartedApp secondStart = await startGallery();

      expect(
        identical(firstStart.dependencies, secondStart.dependencies),
        isFalse,
      );
      expect(
        identical(firstStart.navigation, secondStart.navigation),
        isFalse,
      );
    }
  });

  test('test_start_gallery_property_starts_on_tasks_alone', () async {
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StartedApp started = await startGallery();

      expect(started.navigation.routes, <AppRoute>[galleryStartRoute]);
      expect(started.navigation.canOpen(galleryStartRoute), isTrue);
    }
  });

  testWidgets('test_start_gallery_property_renders_at_random_sizes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(91704);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      useViewSize(tester, _randomWindowSize(random));
      await tester.pumpWidget(const SizedBox());

      await pumpStartedGate(
        tester,
        startup: chooseStartup(appDataChoice: galleryAppData),
        messengerKey: MessengerKey(),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AppShell), findsOneWidget);
    }
  });

  testWidgets('test_build_single_window_app_property_shell_gets_the_'
      'started_inputs', (WidgetTester tester) async {
    useViewSize(tester, desktopSize);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeStartup startup = chooseStartup(appDataChoice: galleryAppData);
      await tester.pumpWidget(const SizedBox());

      await pumpStartedGate(
        tester,
        startup: startup,
        messengerKey: MessengerKey(),
      );

      final StartedApp started = readStartedApp(startup);
      final AppShell shell = tester.widget<AppShell>(find.byType(AppShell));
      expect(identical(shell.dependencies, started.dependencies), isTrue);
      expect(identical(shell.navigation, started.navigation), isTrue);
      expect(shell.runWindowOpener, isNull);
    }
  });

  testWidgets('test_build_single_window_app_property_the_messenger_key_'
      'belongs_to_the_app', (WidgetTester tester) async {
    useViewSize(tester, desktopSize);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final MessengerKey messengerKey = MessengerKey();
      await tester.pumpWidget(const SizedBox());

      await pumpStartedGate(
        tester,
        startup: chooseStartup(appDataChoice: galleryAppData),
        messengerKey: messengerKey,
      );

      final ScaffoldMessengerState messenger = tester.state(
        find.byType(ScaffoldMessenger).first,
      );
      expect(identical(messengerKey.currentState, messenger), isTrue);
    }
  });

  testWidgets('test_build_single_window_app_property_starting_again_reuses_'
      'the_key', (WidgetTester tester) async {
    final Random random = seededRandom(91705);
    final ProblemMessenger problemMessenger = ProblemMessenger();
    final MessengerKey messengerKey = problemMessenger.addMessengerKey();
    final NodeStartup startup = chooseStartup(appDataChoice: galleryAppData);
    useViewSize(tester, desktopSize);
    await pumpStartedGate(
      tester,
      startup: startup,
      messengerKey: messengerKey,
    );

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      startup.setUpAgain();
      if (random.nextBool()) {
        await tester.pump();
      }
      await tester.pump();
      await tester.pump(settleTime);

      final String problemText = 'Locked again #$i';
      final bool isShown = problemMessenger.showProblem(
        PeopleFacingRefusal(problemText),
        StackTrace.current,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(isShown, isTrue);
      expect(find.text(problemText), findsOneWidget);
      messengerKey.currentState!.removeCurrentSnackBar();
      await tester.pump();
    }
  });
}
