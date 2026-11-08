import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const String _waitingText = 'Waiting for the new device';
const String _expiredCodeText = 'This code expired.';
const String _showNewCodeLabel = 'Show a new code';
const String _freshFakeCode = '9QX-3MD';
const int _largestMinutesPastExpiry = 600;

Size _randomWindowSize(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  return Size(width, pickOne(random, <double>[phoneHeight, desktopHeight]));
}

Duration _randomTimeAfterExpiry(Random random) {
  final Duration lifetime = galleryPairingSession.expiresAt.difference(
    galleryNow,
  );
  final int minutesPast = random.nextInt(_largestMinutesPastExpiry);
  return lifetime + Duration(minutes: minutesPast);
}

Duration _randomTimeBeforeExpiry(Random random) {
  final Duration lifetime = galleryPairingSession.expiresAt.difference(
    galleryNow,
  );
  return Duration(seconds: random.nextInt(lifetime.inSeconds));
}

AppDependencies _buildDependencies({
  required Duration elapsed,
  required PairingRequest? request,
}) {
  final AppDependencies base = buildGalleryDependencies();
  return replaceRepositories(
    base,
    pairingRepository: FakePairingRepository(
      session: galleryPairingSession,
      request: request,
      clock: FixedClock(galleryNow.add(elapsed)),
      deviceRepository: base.deviceRepository as FakeDeviceRepository,
      joinOutcome: galleryPairingOutcome,
      startedPairingRendezvousProblem: null,
    ),
  );
}

Future<void> _pumpCodeScreen(
  WidgetTester tester, {
  required Size size,
  required AppDependencies dependencies,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: size,
    route: const PairingCodeRoute(),
    dependencies: dependencies,
  );
}

PairingRequest? _randomRequest(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return galleryPairingRequest;
}

int _countSpinners(WidgetTester tester) {
  int spinners = 0;
  for (final StatusLabel label in tester.widgetList<StatusLabel>(
    find.byType(StatusLabel),
  )) {
    if (label.icon == AppIconKind.spinner) {
      spinners += 1;
    }
  }
  return spinners;
}

Finder _findCheckButton() {
  return find.widgetWithText(
    AppButton,
    'Check ${galleryPairingRequest.deviceName}',
  );
}

void main() {
  testWidgets('test_build_request_state_property_an_expired_code_shows_no_'
      'waiting', (WidgetTester tester) async {
    final Random random = seededRandom(94701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = _randomWindowSize(random);
      await _pumpCodeScreen(
        tester,
        size: size,
        dependencies: _buildDependencies(
          elapsed: _randomTimeAfterExpiry(random),
          request: _randomRequest(random),
        ),
      );

      final String reason = 'size $size';
      expect(tester.takeException(), isNull, reason: reason);
      expect(find.text(_expiredCodeText), findsOneWidget, reason: reason);
      expect(find.text(_waitingText), findsNothing, reason: reason);
      expect(_countSpinners(tester), 0, reason: reason);
      expect(_findCheckButton(), findsNothing, reason: reason);
    }
  });

  testWidgets('test_build_request_state_property_a_live_code_waits_or_'
      'offers_the_check', (WidgetTester tester) async {
    final Random random = seededRandom(94702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = _randomWindowSize(random);
      final PairingRequest? request = _randomRequest(random);
      await _pumpCodeScreen(
        tester,
        size: size,
        dependencies: _buildDependencies(
          elapsed: _randomTimeBeforeExpiry(random),
          request: request,
        ),
      );

      final String reason = 'size $size';
      final bool isWaiting = request == null;
      expect(tester.takeException(), isNull, reason: reason);
      expect(find.text(_expiredCodeText), findsNothing, reason: reason);
      expect(
        find.text(_waitingText),
        isWaiting ? findsOneWidget : findsNothing,
        reason: reason,
      );
      expect(_countSpinners(tester), isWaiting ? 1 : 0, reason: reason);
      expect(
        _findCheckButton(),
        isWaiting ? findsNothing : findsOneWidget,
        reason: reason,
      );
    }
  });

  testWidgets('test_build_request_state_property_a_new_code_after_expiry_'
      'waits_again', (WidgetTester tester) async {
    final Random random = seededRandom(94703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = _randomWindowSize(random);
      await _pumpCodeScreen(
        tester,
        size: size,
        dependencies: _buildDependencies(
          elapsed: _randomTimeAfterExpiry(random),
          request: _randomRequest(random),
        ),
      );

      final Finder showNewCode = find.widgetWithText(
        AppButton,
        _showNewCodeLabel,
      );
      await tester.ensureVisible(showNewCode);
      await tester.tap(showNewCode);
      await pumpFrames(tester);

      final String reason = 'size $size';
      expect(tester.takeException(), isNull, reason: reason);
      expect(find.text(_freshFakeCode), findsOneWidget, reason: reason);
      expect(find.text(_expiredCodeText), findsNothing, reason: reason);
      expect(find.text(_waitingText), findsOneWidget, reason: reason);
      expect(_countSpinners(tester), 1, reason: reason);
    }
  });
}
