import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'support/random_diagram_layouts.dart';

const double _smallestTextScale = 0.5;
const double _largestTextScale = 3;
const double _sizeTolerance = 1e-6;
const double _designPaddingAcross = AppSpacing.space2;
const int _longLabelRepeats = 200;
const int _keyValueCount = 1000;

String _randomEdgeLabel(Random random) {
  final List<String> labels = <String>[
    for (final DiagramEdge edge in describeSavedEdges(
      randomValidWorkflow(random),
    ))
      ?edge.label,
  ];
  if (labels.isEmpty) {
    return pickOne(random, <String>['approved', 'changes · ≤ 3', '≤ 1']);
  }
  return pickOne(random, labels);
}

Widget _placeLabel(String label, EdgeLook look, double textScale) {
  return MediaQuery.withClampedTextScaling(
    minScaleFactor: textScale,
    maxScaleFactor: textScale,
    child: Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: 0,
          top: 0,
          child: EdgeLabelBox(label: label, look: look),
        ),
      ],
    ),
  );
}

Future<void> _pumpLabel(
  WidgetTester tester,
  Random random, {
  required String label,
  required EdgeLook look,
}) async {
  final double textScale = randomWidth(
    random,
    least: _smallestTextScale,
    most: _largestTextScale,
  );
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: _placeLabel(label, look, textScale),
  );
}

BoxDecoration _readDecoration(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(EdgeLabelBox),
      matching: find.byType(DecoratedBox),
    ),
  );
  return box.decoration as BoxDecoration;
}

Text _readText(WidgetTester tester) {
  return tester.widget<Text>(
    find.descendant(
      of: find.byType(EdgeLabelBox),
      matching: find.byType(Text),
    ),
  );
}

void main() {
  testWidgets('test_measure_edge_label_property_matches_the_drawn_box', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(119401);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String label = _randomEdgeLabel(random);
      await _pumpLabel(
        tester,
        random,
        label: label,
        look: pickOne(random, EdgeLook.values),
      );

      final Size drawn = tester.getSize(find.byType(EdgeLabelBox));
      final Size measured = measureEdgeLabel(label);

      expect(drawn.width, closeTo(measured.width, _sizeTolerance));
      expect(drawn.height, closeTo(measured.height, _sizeTolerance));
      expect(tester.takeException(), isNull);
    }
  });

  test('test_measure_edge_label_property_every_label_is_one_line_high', () {
    final Random random = seededRandom(119402);
    final double oneLine = measureEdgeLabel('approved').height;

    for (int i = 0; i < propertyIterations; i += 1) {
      final String label = _randomEdgeLabel(random);

      expect(measureEdgeLabel(label).height, closeTo(oneLine, _sizeTolerance));
    }
  });

  test('test_measure_edge_label_property_width_adds_up_with_padding', () {
    final Random random = seededRandom(119403);
    final double emptyWidth = measureEdgeLabel('').width;

    for (int i = 0; i < propertyIterations; i += 1) {
      final String first = _randomEdgeLabel(random);
      final String second = _randomEdgeLabel(random);
      final double joined = measureEdgeLabel('$first$second').width;
      final double apart =
          measureEdgeLabel(first).width + measureEdgeLabel(second).width;

      expect(emptyWidth, closeTo(2 * _designPaddingAcross, _sizeTolerance));
      expect(joined, closeTo(apart - emptyWidth, 1));
    }
  });

  test('test_edge_label_box_new_property_keeps_label_and_look', () {
    final Random random = seededRandom(119404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String label = randomHostileText(random);
      final EdgeLook look = pickOne(random, EdgeLook.values);
      final Key key = ValueKey<int>(random.nextInt(_keyValueCount));

      final EdgeLabelBox box = EdgeLabelBox(
        label: label,
        look: look,
        key: key,
      );

      expect(box.label.codeUnits, label.codeUnits);
      expect(box.look, look);
      expect(box.key, key);
    }
  });

  test('test_edge_label_box_new_property_keeps_long_labels_whole', () {
    final Random random = seededRandom(119408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String label = List<String>.filled(
        1 + random.nextInt(_longLabelRepeats),
        _randomEdgeLabel(random),
      ).join();

      final EdgeLabelBox box = EdgeLabelBox(
        label: label,
        look: pickOne(random, EdgeLook.values),
      );

      expect(box.label.length, label.length);
      expect(box.label, label);
    }
  });

  test('test_edge_label_box_new_property_has_no_key_unless_given', () {
    final Random random = seededRandom(119409);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeLabelBox box = EdgeLabelBox(
        label: _randomEdgeLabel(random),
        look: pickOne(random, EdgeLook.values),
      );

      expect(box.key, isNull);
    }
  });

  testWidgets('test_edge_label_box_build_property_shows_one_line', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(119405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String label = random.nextBool()
          ? _randomEdgeLabel(random)
          : randomHostileText(random);
      await _pumpLabel(
        tester,
        random,
        label: label,
        look: pickOne(random, EdgeLook.values),
      );

      final Text text = _readText(tester);

      expect(text.data, label);
      expect(text.maxLines, 1);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_edge_label_box_build_property_selection_uses_action', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(119406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final EdgeLook look = pickOne(random, EdgeLook.values);
      await _pumpLabel(
        tester,
        random,
        label: _randomEdgeLabel(random),
        look: look,
      );
      final bool isSelected = look == EdgeLook.selected;
      final Color expectedBorder = isSelected
          ? AppColors.action
          : AppColors.line;
      final Color expectedInk = isSelected
          ? AppColors.action
          : AppColors.inkMuted;

      final Border border = _readDecoration(tester).border! as Border;

      expect(border.top.color, expectedBorder);
      expect(_readText(tester).style!.color, expectedInk);
    }
  });

  testWidgets('test_edge_label_box_build_property_is_a_pill_like_design', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(119407);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpLabel(
        tester,
        random,
        label: _randomEdgeLabel(random),
        look: pickOne(random, EdgeLook.values),
      );

      final BoxDecoration decoration = _readDecoration(tester);

      expect(decoration.borderRadius, BorderRadius.circular(AppRadii.pill));
      expect(decoration.color, AppColors.sunken);
    }
  });
}
