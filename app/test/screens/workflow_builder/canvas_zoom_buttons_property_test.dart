import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const String _zoomOutPress = 'zoom out';
const String _zoomInPress = 'zoom in';
const String _fitPress = 'fit';
const List<String> _documentedLabels = <String>['−', '+', 'Fit'];
const int _largestPressCount = 6;
const List<String> _everyPress = <String>[
  _zoomOutPress,
  _zoomInPress,
  _fitPress,
];

final class _PressLog {
  final List<String> presses = <String>[];

  CanvasZoomButtons buildButtons({Key? key}) {
    return CanvasZoomButtons(
      key: key,
      onZoomOut: () => presses.add(_zoomOutPress),
      onZoomIn: () => presses.add(_zoomInPress),
      onFit: () => presses.add(_fitPress),
    );
  }
}

String _findLabelOfPress(String press) {
  switch (press) {
    case _zoomOutPress:
      return zoomOutLabel;
    case _zoomInPress:
      return zoomInLabel;
  }
  return fitLabel;
}

Future<void> _pumpButtons(
  WidgetTester tester, {
  required double width,
  required Widget buttons,
}) async {
  useViewSize(tester, Size(width, desktopHeight));
  await tester.pumpWidget(
    wrapInApp(
      Align(alignment: Alignment.bottomLeft, child: buttons),
      platform: platformMeantByWidth(width),
    ),
  );
}

List<String> _randomPresses(Random random) {
  final int pressCount = random.nextInt(_largestPressCount);
  final List<String> presses = <String>[];
  for (int press = 0; press < pressCount; press += 1) {
    presses.add(pickOne(random, _everyPress));
  }
  return presses;
}

void _zoomOutNowhere() {}

void _zoomInNowhere() {}

void _fitNowhere() {}

void main() {
  test('test_canvas_zoom_buttons_constructor_property_keeps_callbacks', () {
    final Random random = seededRandom(117701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _PressLog log = _PressLog();
      final CanvasZoomButtons buttons = log.buildButtons();
      final List<String> pressed = _randomPresses(random);

      for (final String press in pressed) {
        switch (press) {
          case _zoomOutPress:
            buttons.onZoomOut();
          case _zoomInPress:
            buttons.onZoomIn();
          default:
            buttons.onFit();
        }
      }

      expect(log.presses, pressed);
    }
  });

  test('test_canvas_zoom_buttons_constructor_property_keeps_the_key', () {
    final Random random = seededRandom(117702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomText(random));

      expect(_PressLog().buildButtons(key: key).key, key);
    }
  });

  test(
    'test_canvas_zoom_buttons_constructor_property_same_callbacks_kept',
    () {
      const CanvasZoomButtons buttons = CanvasZoomButtons(
        onZoomOut: _zoomOutNowhere,
        onZoomIn: _zoomInNowhere,
        onFit: _fitNowhere,
      );

      expect(identical(buttons.onZoomOut, _zoomOutNowhere), isTrue);
      expect(identical(buttons.onZoomIn, _zoomInNowhere), isTrue);
      expect(identical(buttons.onFit, _fitNowhere), isTrue);
    },
  );

  testWidgets(
    'test_canvas_zoom_buttons_build_property_shows_documented_labels',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final Random random = seededRandom(117703);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final double width = randomWidth(
          random,
          least: narrowestWidth,
          most: widestWidth,
        );
        await _pumpButtons(
          tester,
          width: width,
          buttons: _PressLog().buildButtons(),
        );

        expect(tester.takeException(), isNull, reason: 'width $width');
        for (final String label in _documentedLabels) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(find.bySemanticsLabel(RegExp('Zoom out')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('Zoom in')), findsOneWidget);
      }
      semantics.dispose();
    },
  );

  testWidgets(
    'test_canvas_zoom_buttons_build_property_each_tap_runs_its_own',
    (WidgetTester tester) async {
      final Random random = seededRandom(117704);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _PressLog log = _PressLog();
        await _pumpButtons(
          tester,
          width: randomWidth(random, least: narrowestWidth, most: widestWidth),
          buttons: log.buildButtons(),
        );
        final List<String> pressed = _randomPresses(random);

        for (final String press in pressed) {
          await tester.tap(find.text(_findLabelOfPress(press)));
          await tester.pump();
        }

        expect(log.presses, pressed);
      }
    },
  );

  testWidgets('test_canvas_zoom_buttons_build_property_one_row_in_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(117705);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpButtons(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        buttons: _PressLog().buildButtons(),
      );

      final List<Rect> shown = <Rect>[
        for (final String label in _documentedLabels)
          tester.getRect(find.text(label)),
      ];

      for (int index = 1; index < shown.length; index += 1) {
        expect(shown[index - 1].right, lessThanOrEqualTo(shown[index].left));
        expect(shown[index].center.dy, closeTo(shown[0].center.dy, 1));
      }
    }
  });
}
