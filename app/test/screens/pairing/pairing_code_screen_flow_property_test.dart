import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/screens/pairing.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'pairing_flow_harness.dart';
import 'scripted_pairing_repository.dart';

const String _pageTitle = 'Pair a device';
const String _pageSummary =
    'Pair it once, then use it in any of your workspaces.';
const String _stepsTitle = 'On the new device';
const List<String> _newDeviceSteps = <String>[
  'Open the app and choose how the device will be used.',
  'Enter this code, or scan the QR code with a phone.',
  'Come back here, check four words match, then approve.',
];
const String _cancelLabel = 'Cancel';
const String _expiredText = 'This code expired.';
const int _largestStepCount = 6;
const int _largestElapsedSeconds = 400;

String? _randomProblem(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return 'relay ${randomWordPhrase(random)} ${random.nextInt(1000)}';
}

PairingCodeScreen _buildScreen(
  AppDependencies dependencies,
  AppNavigation navigation,
  Key? key,
) {
  return PairingCodeScreen(
    pairingRepository: dependencies.pairingRepository,
    workspaceRepository: dependencies.workspaceRepository,
    clock: dependencies.clock,
    navigation: navigation,
    key: key,
  );
}

Future<void> _changeRandomly(
  ScriptedPairingRepository pairing,
  Random random,
) {
  switch (random.nextInt(3)) {
    case 0:
      pairing.startedProblem = _randomProblem(random);
      return pairing.startPairing();
    case 1:
      final int seconds = random.nextInt(_largestElapsedSeconds);
      pairing.passTime(Duration(seconds: seconds));
      return Future<void>.value();
    default:
      pairing.closeElsewhere();
      return Future<void>.value();
  }
}

void _expectPageFollowsTheSession(ScriptedPairingRepository pairing) {
  final PairingSession? live = pairing.findActiveSession();
  final String? problem = live?.rendezvousProblem;

  expect(
    find.byType(RendezvousProblemBanner),
    findsNWidgets(problem == null ? 0 : 1),
  );
  if (problem != null) {
    expect(find.text(problem), findsOneWidget);
  }
  expect(find.byType(PairingQrCode), findsNWidgets(live == null ? 0 : 1));
  expect(find.text(_expiredText), findsNWidgets(live == null ? 1 : 0));
  if (live != null) {
    expect(find.text(live.code), findsOneWidget);
  }
}

void main() {
  test('test_pairing_code_screen_new_property_keeps_every_dependency', () {
    final Random random = seededRandom(104501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = AppNavigation(
        initialRoute: pickOne(random, <AppRoute>[
          devicesRoute,
          const PairingCodeRoute(),
        ]),
      );

      final PairingCodeScreen screen = _buildScreen(
        dependencies,
        navigation,
        null,
      );

      expect(screen.pairingRepository, same(dependencies.pairingRepository));
      expect(
        screen.workspaceRepository,
        same(dependencies.workspaceRepository),
      );
      expect(screen.clock, same(dependencies.clock));
      expect(screen.navigation, same(navigation));
    }
  });

  test('test_pairing_code_screen_new_property_keeps_its_key', () {
    final Random random = seededRandom(104502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ValueKey<String> key = ValueKey<String>(randomText(random));
      final AppDependencies dependencies = buildGalleryDependencies();

      final PairingCodeScreen screen = _buildScreen(
        dependencies,
        AppNavigation(initialRoute: devicesRoute),
        key,
      );

      expect(screen.key, key);
    }
  });

  testWidgets('test_pairing_code_screen_new_property_builds_one_page_per_'
      'route', (WidgetTester tester) async {
    final Random random = seededRandom(104503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openPairingPage(
        tester,
        size: randomPairingWindow(random),
        route: const PairingCodeRoute(),
        session: buildLiveSession(problem: null),
        request: null,
      );

      expect(find.byType(PairingCodeScreen), findsOneWidget);
      expect(find.text(_pageTitle), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_pairing_code_screen_build_page_property_shows_the_'
      'design_words_at_any_size', (WidgetTester tester) async {
    final Random random = seededRandom(104504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = randomPairingWindow(random);

      await openPairingPage(
        tester,
        size: size,
        route: const PairingCodeRoute(),
        session: random.nextBool() ? buildLiveSession(problem: null) : null,
        request: null,
      );

      expect(find.text(_pageSummary), findsOneWidget, reason: '$size');
      expect(find.text(_stepsTitle), findsOneWidget, reason: '$size');
      for (final String step in _newDeviceSteps) {
        expect(find.text(step), findsOneWidget, reason: step);
      }
      expect(find.text(_cancelLabel), findsOneWidget, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('test_pairing_code_screen_build_page_property_banner_and_'
      'card_follow_every_session_change', (WidgetTester tester) async {
    final Random random = seededRandom(104505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await openPairingPage(
        tester,
        size: randomPairingWindow(random),
        route: const PairingCodeRoute(),
        session: buildLiveSession(problem: _randomProblem(random)),
        request: null,
      );
      _expectPageFollowsTheSession(page.pairing);

      final int stepCount = random.nextInt(_largestStepCount);
      for (int step = 0; step < stepCount; step += 1) {
        await _changeRandomly(page.pairing, random);
        await pumpFrames(tester);

        _expectPageFollowsTheSession(page.pairing);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'test_pairing_code_screen_build_page_property_the_code_comes_before_'
    'the_steps',
    (WidgetTester tester) async {
      final Random random = seededRandom(104506);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final Size size = randomPairingWindow(random);
        final PairingSession session = buildLiveSession(
          problem: _randomProblem(random),
        );

        await openPairingPage(
          tester,
          size: size,
          route: const PairingCodeRoute(),
          session: session,
          request: null,
        );

        final Rect code = tester.getRect(find.text(session.code));
        final Rect steps = tester.getRect(find.text(_stepsTitle));
        final bool isBeside = code.right <= steps.left;
        final bool isAbove = code.bottom <= steps.top;
        expect(isBeside || isAbove, isTrue, reason: '$size');
      }
    },
  );
}
