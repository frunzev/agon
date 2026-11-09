import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/spinning_box.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';
import 'support/spinning_box_harness.dart';

const Key _childKey = ValueKey<String>('spinning child');
const Key _otherChildKey = ValueKey<String>('other spinning child');
const double _lowestWindowHeight = 600;
const double _geometryTolerance = 1e-3;

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

SpinningBox _buildBox(Size childSize, {required Key childKey, Key? key}) {
  return SpinningBox(
    key: key,
    child: SizedBox.fromSize(key: childKey, size: childSize),
  );
}

void main() {
  test('test_spinning_box_constructor_property_keeps_the_child', () {
    final Random random = seededRandom(91101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Widget child = SizedBox.fromSize(size: randomChildSize(random));

      final SpinningBox box = SpinningBox(child: child);

      expect(identical(box.child, child), isTrue);
    }
  });

  test('test_spinning_box_constructor_property_keeps_the_given_key', () {
    final Random random = seededRandom(91102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key? key = random.nextBool()
          ? null
          : ValueKey<String>(randomText(random));

      final SpinningBox box = SpinningBox(key: key, child: const SizedBox());

      expect(box.key, key);
    }
  });

  testWidgets('test_spinning_box_constructor_property_a_new_child_replaces_'
      'the_old_and_keeps_turning', (WidgetTester tester) async {
    final Random random = seededRandom(91103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Key boxKey = ValueKey<int>(i);
      final Size childSize = randomChildSize(random);
      await tester.pumpWidget(
        placeSpinningBox(
          _buildBox(childSize, childKey: _childKey, key: boxKey),
          motion: fullMotion,
        ),
      );
      final Duration firstPause = randomPumpDuration(random);
      await tester.pump(firstPause);

      await tester.pumpWidget(
        placeSpinningBox(
          _buildBox(childSize, childKey: _otherChildKey, key: boxKey),
          motion: fullMotion,
        ),
      );
      final Duration secondPause = randomPumpDuration(random);
      await tester.pump(secondPause);

      final double expectedTurns = computeExpectedTurns(
        firstPause + secondPause,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(_childKey), findsNothing);
      expect(find.byKey(_otherChildKey), findsOneWidget);
      expect(
        measureTurnDistance(readShownTurns(tester), expectedTurns),
        lessThan(turnTolerance),
      );
    }
  });

  test('test_spinning_box_create_state_property_each_call_is_a_new_state', () {
    const SpinningBox box = SpinningBox(child: SizedBox());

    final State<SpinningBox> firstState = box.createState();
    final State<SpinningBox> secondState = box.createState();

    expect(identical(firstState, secondState), isFalse);
    expect(firstState.runtimeType, secondState.runtimeType);
  });

  test('test_spinning_box_create_state_property_a_new_state_is_unmounted', () {
    final Random random = seededRandom(91104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SpinningBox box = _buildBox(
        randomChildSize(random),
        childKey: _childKey,
      );

      final State<SpinningBox> state = box.createState();

      expect(state.mounted, isFalse);
    }
  });

  testWidgets('test_spinning_box_create_state_property_the_mounted_state_'
      'holds_the_box', (WidgetTester tester) async {
    final Random random = seededRandom(91105);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SpinningBox box = _buildBox(
        randomChildSize(random),
        childKey: _childKey,
        key: ValueKey<int>(i),
      );
      await tester.pumpWidget(placeSpinningBox(box, motion: fullMotion));

      final State<SpinningBox> state = tester.state<State<SpinningBox>>(
        find.byType(SpinningBox),
      );

      expect(state.mounted, isTrue);
      expect(identical(state.widget, box), isTrue);
    }
  });

  testWidgets('test_spinning_box_build_property_renders_at_random_sizes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(91106);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      useViewSize(tester, _randomWindowSize(random));
      await tester.pumpWidget(
        placeSpinningBox(
          _buildBox(randomChildSize(random), childKey: _childKey),
          motion: fullMotion,
        ),
      );
      await tester.pump(randomPumpDuration(random));

      expect(tester.takeException(), isNull);
      expect(find.byKey(_childKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SpinningBox),
          matching: find.byType(RotationTransition),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('test_spinning_box_build_property_takes_the_size_of_its_child', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(91107);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      useViewSize(tester, _randomWindowSize(random));
      final Size childSize = randomChildSize(random);
      await tester.pumpWidget(
        placeSpinningBox(
          _buildBox(childSize, childKey: _childKey),
          motion: fullMotion,
        ),
      );
      await tester.pump(randomPumpDuration(random));

      final Size boxSize = tester.getSize(find.byType(SpinningBox));

      expect(boxSize.width, closeTo(childSize.width, _geometryTolerance));
      expect(boxSize.height, closeTo(childSize.height, _geometryTolerance));
    }
  });

  testWidgets('test_spinning_box_build_property_turns_about_the_center', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(91108);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size windowSize = _randomWindowSize(random);
      useViewSize(tester, windowSize);
      final Size childSize = randomChildSize(random);
      await tester.pumpWidget(
        placeSpinningBox(
          _buildBox(childSize, childKey: ValueKey<int>(i)),
          motion: fullMotion,
        ),
      );
      await tester.pump(randomPumpDuration(random));

      final Finder child = find.byKey(ValueKey<int>(i));
      final Offset shownCenter = tester.getCenter(child);
      final Offset shownCorner = tester.getTopLeft(child);
      final double cornerDistance = (shownCorner - shownCenter).distance;
      final Offset windowCenter = windowSize.center(Offset.zero);
      final Offset childDiagonal = childSize.bottomRight(Offset.zero);
      final double halfDiagonal = childDiagonal.distance / 2;
      final double centerShift = (shownCenter - windowCenter).distance;

      expect(centerShift, lessThan(_geometryTolerance));
      expect(cornerDistance, closeTo(halfDiagonal, _geometryTolerance));
    }
  });
}
