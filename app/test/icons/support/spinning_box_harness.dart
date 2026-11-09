import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/spinning_box.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../support/random_inputs.dart';

const MediaQueryData fullMotion = MediaQueryData();
const MediaQueryData reducedMotion = MediaQueryData(disableAnimations: true);
const double turnTolerance = 1e-6;
const double _smallestChildSide = 1;
const double _largestChildSide = 300;
const int _longestPumpInMilliseconds = 3000;

Size randomChildSize(Random random) {
  final double width = randomWidth(
    random,
    least: _smallestChildSide,
    most: _largestChildSide,
  );
  final double height = randomWidth(
    random,
    least: _smallestChildSide,
    most: _largestChildSide,
  );
  return Size(width, height);
}

Duration randomPumpDuration(Random random) {
  final int milliseconds = random.nextInt(_longestPumpInMilliseconds);
  return Duration(milliseconds: milliseconds);
}

Widget placeSpinningBox(Widget box, {required MediaQueryData motion}) {
  return MediaQuery(
    data: motion,
    child: Center(child: box),
  );
}

double readShownTurns(WidgetTester tester) {
  final Finder rotation = find.descendant(
    of: find.byType(SpinningBox),
    matching: find.byType(RotationTransition),
  );
  final RotationTransition transition = tester.widget<RotationTransition>(
    rotation,
  );
  return transition.turns.value;
}

double computeExpectedTurns(Duration elapsed) {
  final int spinMicroseconds = AppDurations.spin.inMicroseconds;
  final int elapsedWithinTurn = elapsed.inMicroseconds % spinMicroseconds;
  return elapsedWithinTurn / spinMicroseconds;
}

double measureTurnDistance(double firstTurns, double secondTurns) {
  final double gap = (firstTurns - secondTurns).abs();
  return min(gap, 1 - gap);
}
