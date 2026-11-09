import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/problem_messenger.dart';
import 'package:agent_orchestration/startup/app_startup_choice.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/node_startup.dart';
import 'package:agent_orchestration/startup/single_window_app.dart';
import 'package:agent_orchestration/startup/startup_pages.dart';
import 'package:agent_orchestration/startup/startup_stage.dart';
import 'package:agent_orchestration/windows/several_windows_support.dart';

import 'support/app_harness.dart';
import 'support/main_wiring_harness.dart';
import 'support/random_inputs.dart';
import 'support/widget_harness.dart';

const int _largestRestartCount = 4;

void main() {
  test('test_main_property_only_mac_opens_several_windows', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final bool hasSeveralWindows = supportsSeveralWindows(platform);

      expect(hasSeveralWindows, platform == TargetPlatform.macOS);
    }
  });

  testWidgets('test_main_property_platform_problems_show_in_the_started_'
      'app', (WidgetTester tester) async {
    final Random random = seededRandom(91701);
    final ProblemMessenger problemMessenger = ProblemMessenger();
    final MessengerKey messengerKey = problemMessenger.addMessengerKey();
    final ErrorCallback platformProblemHandler = problemMessenger.showProblem;
    useViewSize(tester, desktopSize);
    await pumpStartedGate(
      tester,
      startup: chooseStartup(appDataChoice: galleryAppData),
      messengerKey: messengerKey,
    );

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problemText = 'Locked ${randomWordPhrase(random)} #$i';

      final bool isHandled = platformProblemHandler(
        PeopleFacingRefusal(problemText),
        StackTrace.current,
      );
      await tester.pump();

      expect(isHandled, isTrue);
      expect(find.text(problemText), findsOneWidget);
      messengerKey.currentState!.removeCurrentSnackBar();
      await tester.pump();
    }
  });

  testWidgets('test_main_property_problems_before_start_are_left_to_'
      'flutter', (WidgetTester tester) async {
    final Random random = seededRandom(91702);
    final ProblemMessenger problemMessenger = ProblemMessenger();
    final MessengerKey messengerKey = problemMessenger.addMessengerKey();
    final Completer<StartedApp> pendingStart = Completer<StartedApp>();
    final NodeStartup startup = NodeStartup(
      startApp: () => pendingStart.future,
      startAppAsNewDevice: startGallery,
    );
    final ErrorCallback platformProblemHandler = problemMessenger.showProblem;
    startup.start();
    final Widget gate = buildSingleWindowGate(
      startup: startup,
      messengerKey: messengerKey,
    );
    await tester.pumpWidget(gate);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool isHandled = platformProblemHandler(
        PeopleFacingRefusal(randomText(random)),
        StackTrace.current,
      );

      expect(isHandled, isFalse);
    }
    expect(find.byType(StartupWaitingPage), findsOneWidget);
    pendingStart.complete(await startGallery());
    await tester.pump();
    await tester.pump(settleTime);
  });

  test('test_choose_startup_property_gallery_start_opens_tasks', () async {
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeStartup startup = chooseStartup(appDataChoice: galleryAppData);

      startup.start();
      await pumpEventQueue();

      final StartedApp started = readStartedApp(startup);
      expect(started.navigation.currentRoute, galleryStartRoute);
    }
  });

  test('test_choose_startup_property_setting_up_again_opens_tasks', () async {
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeStartup startup = chooseStartup(appDataChoice: galleryAppData);
      startup.start();
      await pumpEventQueue();
      final StartedApp firstStart = readStartedApp(startup);

      startup.setUpAgain();
      await pumpEventQueue();

      final StartedApp secondStart = readStartedApp(startup);
      expect(secondStart.navigation.currentRoute, galleryStartRoute);
      expect(identical(secondStart, firstStart), isFalse);
    }
  });

  test('test_choose_startup_property_the_latest_start_is_shown', () async {
    final Random random = seededRandom(91703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NodeStartup startup = chooseStartup(appDataChoice: galleryAppData);
      final int restartCount = 1 + random.nextInt(_largestRestartCount);

      for (int restart = 0; restart < restartCount; restart += 1) {
        if (random.nextBool()) {
          startup.start();
        } else {
          startup.setUpAgain();
        }
      }
      expect(startup.stage, isA<StartupWaiting>());
      await pumpEventQueue();

      expect(readStartedApp(startup).navigation.routes, <AppRoute>[
        galleryStartRoute,
      ]);
    }
  });
}
