import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/spinning_box.dart';

import '../support/random_inputs.dart';
import 'support/spinning_box_harness.dart';

const int _largestStepCount = 6;
const int _largestBoxCount = 8;
const Size _smallChildSize = Size.square(10);

Widget _placeBoxes(int boxCount, {required MediaQueryData motion}) {
  return MediaQuery(
    data: motion,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < boxCount; i += 1)
            SpinningBox(
              key: ValueKey<int>(i),
              child: SizedBox.fromSize(size: _smallChildSize),
            ),
        ],
      ),
    ),
  );
}

Widget _placeRandomBox(Random random, {required MediaQueryData motion}) {
  return placeSpinningBox(
    SpinningBox(child: SizedBox.fromSize(size: randomChildSize(random))),
    motion: motion,
  );
}

void main() {
  testWidgets('test_spinning_box_state_did_change_dependencies_property_'
      'turns_follow_the_clock', (WidgetTester tester) async {
    final Random random = seededRandom(91201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_placeRandomBox(random, motion: fullMotion));
      Duration elapsed = Duration.zero;

      final int stepCount = 1 + random.nextInt(_largestStepCount);
      for (int step = 0; step < stepCount; step += 1) {
        final Duration pause = randomPumpDuration(random);
        await tester.pump(pause);
        elapsed += pause;

        final double expectedTurns = computeExpectedTurns(elapsed);
        expect(
          measureTurnDistance(readShownTurns(tester), expectedTurns),
          lessThan(turnTolerance),
          reason: 'after $elapsed',
        );
        expect(tester.hasRunningAnimations, isTrue);
      }
    }
  });

  testWidgets('test_spinning_box_state_did_change_dependencies_property_'
      'reduced_motion_keeps_it_still', (WidgetTester tester) async {
    final Random random = seededRandom(91202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_placeRandomBox(random, motion: reducedMotion));
      await tester.pump(randomPumpDuration(random));

      expect(readShownTurns(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    }
  });

  testWidgets('test_spinning_box_state_did_change_dependencies_property_'
      'spins_exactly_while_motion_is_allowed', (WidgetTester tester) async {
    final Random random = seededRandom(91203);
    final Size childSize = randomChildSize(random);
    final SpinningBox box = SpinningBox(
      child: SizedBox.fromSize(size: childSize),
    );

    for (int i = 0; i < widgetPropertyIterations * _largestStepCount; i += 1) {
      final MediaQueryData motion = pickOne(random, <MediaQueryData>[
        fullMotion,
        reducedMotion,
      ]);
      await tester.pumpWidget(placeSpinningBox(box, motion: motion));
      await tester.pump(randomPumpDuration(random));

      final bool isReduced = motion.disableAnimations;
      expect(tester.hasRunningAnimations, !isReduced);
      if (isReduced) {
        expect(readShownTurns(tester), 0);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_spinning_box_state_did_change_dependencies_property_'
      'muted_tickers_hold_the_turn', (WidgetTester tester) async {
    final Random random = seededRandom(91204);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        TickerMode(
          enabled: false,
          child: _placeRandomBox(random, motion: fullMotion),
        ),
      );
      final double turnsBefore = readShownTurns(tester);
      await tester.pump(randomPumpDuration(random));

      expect(readShownTurns(tester), turnsBefore);
    }
  });

  testWidgets('test_spinning_box_state_dispose_property_removal_stops_the_'
      'spinning', (WidgetTester tester) async {
    final Random random = seededRandom(91205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await tester.pumpWidget(_placeRandomBox(random, motion: fullMotion));
      await tester.pump(randomPumpDuration(random));

      await tester.pumpWidget(const SizedBox());

      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    }
  });

  testWidgets('test_spinning_box_state_dispose_property_boxes_come_and_go_'
      'cleanly', (WidgetTester tester) async {
    final Random random = seededRandom(91206);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int boxCount = random.nextInt(_largestBoxCount + 1);
      await tester.pumpWidget(_placeBoxes(boxCount, motion: fullMotion));
      await tester.pump(randomPumpDuration(random));

      expect(tester.takeException(), isNull);
      expect(find.byType(SpinningBox), findsNWidgets(boxCount));
      expect(tester.hasRunningAnimations, boxCount > 0);
    }

    await tester.pumpWidget(_placeBoxes(0, motion: fullMotion));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('test_spinning_box_state_dispose_property_a_still_box_leaves_'
      'cleanly', (WidgetTester tester) async {
    final Random random = seededRandom(91207);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await tester.pumpWidget(_placeRandomBox(random, motion: reducedMotion));
      await tester.pump(randomPumpDuration(random));

      await tester.pumpWidget(const SizedBox());

      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    }
  });
}
