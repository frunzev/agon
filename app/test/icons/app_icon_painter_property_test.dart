import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/icons/app_icon_painter.dart';
import 'package:agent_orchestration/icons/icon_path_parser.dart';
import 'package:agent_orchestration/icons/icon_shape.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../support/random_inputs.dart';
import 'support/random_icon_paths.dart';

const double _largestSide = 400;
const double _boundsTolerance = 1e-3;
const int _colorSpan = 1 << 32;

final class _RecordingCanvas extends Fake implements Canvas {
  final List<String> calls = <String>[];
  final List<Path> paths = <Path>[];
  final List<Paint> paints = <Paint>[];
  final List<double> scales = <double>[];

  @override
  void save() => calls.add('save');

  @override
  void restore() => calls.add('restore');

  @override
  void scale(double horizontal, [double? vertical]) {
    calls.add('scale');
    scales.add(horizontal);
    if (vertical != null && vertical != horizontal) {
      throw StateError('the icon must keep its proportions');
    }
  }

  @override
  void drawPath(Path path, Paint paint) {
    calls.add('drawPath');
    paths.add(path);
    paints.add(paint);
  }
}

Color _randomColor(Random random) => Color(random.nextInt(_colorSpan));

Size _randomSize(Random random) {
  return Size(
    random.nextDouble() * _largestSide,
    random.nextDouble() * _largestSide,
  );
}

_RecordingCanvas _paintIcon(AppIconPainter painter, Size size) {
  final _RecordingCanvas canvas = _RecordingCanvas();
  painter.paint(canvas, size);
  return canvas;
}

List<String> _describeShapes(_RecordingCanvas canvas) {
  final List<String> descriptions = <String>[];
  for (final Path path in canvas.paths) {
    descriptions.add(describePathGeometry(path));
  }
  return descriptions;
}

void main() {
  test('test_app_icon_painter_constructor_property_keeps_kind_and_color', () {
    final Random random = seededRandom(90701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppIconKind kind = pickOne(random, AppIconKind.values);
      final Color color = _randomColor(random);

      final AppIconPainter painter = AppIconPainter(kind: kind, color: color);

      expect(painter.kind, kind);
      expect(painter.color, color);
    }
  });

  test('test_app_icon_painter_constructor_property_equal_inputs_need_no_'
      'repaint', () {
    final Random random = seededRandom(90702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppIconKind kind = pickOne(random, AppIconKind.values);
      final Color color = _randomColor(random);

      final AppIconPainter first = AppIconPainter(kind: kind, color: color);
      final AppIconPainter second = AppIconPainter(kind: kind, color: color);

      expect(first.shouldRepaint(second), isFalse);
      expect(second.shouldRepaint(first), isFalse);
    }
  });

  test('test_app_icon_painter_constructor_property_paints_the_kind_it_was_'
      'given', () {
    final Random random = seededRandom(90703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppIconKind kind = pickOne(random, AppIconKind.values);
      final AppIconPainter painter = AppIconPainter(
        kind: kind,
        color: _randomColor(random),
      );

      final _RecordingCanvas canvas = _paintIcon(painter, _randomSize(random));

      final List<String> expectedShapes = <String>[];
      for (final IconShape shape in kind.shapes) {
        expectedShapes.add(describePathGeometry(buildIconShapePath(shape)));
      }
      expect(_describeShapes(canvas), expectedShapes, reason: kind.name);
    }
  });

  test('test_app_icon_painter_paint_property_one_stroked_path_per_shape', () {
    final Random random = seededRandom(90704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppIconKind kind = pickOne(random, AppIconKind.values);
      final Color color = _randomColor(random);
      final AppIconPainter painter = AppIconPainter(kind: kind, color: color);

      final _RecordingCanvas canvas = _paintIcon(painter, _randomSize(random));

      expect(canvas.paths.length, kind.shapes.length, reason: kind.name);
      for (final Paint paint in canvas.paints) {
        expect(paint.color.toARGB32(), color.toARGB32());
        expect(paint.style, PaintingStyle.stroke);
        expect(paint.strokeWidth, AppSizes.iconStroke);
        expect(paint.strokeCap, StrokeCap.round);
        expect(paint.strokeJoin, StrokeJoin.round);
      }
    }
  });

  test('test_app_icon_painter_paint_property_scales_the_view_box_into_the_'
      'shortest_side', () {
    final Random random = seededRandom(90705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppIconKind kind = pickOne(random, AppIconKind.values);
      final Size size = _randomSize(random);
      final AppIconPainter painter = AppIconPainter(
        kind: kind,
        color: _randomColor(random),
      );

      final _RecordingCanvas canvas = _paintIcon(painter, size);

      final double scale = size.shortestSide / AppSizes.iconViewBox;
      expect(canvas.calls.first, 'save');
      expect(canvas.calls[1], 'scale');
      expect(canvas.calls.last, 'restore');
      expect(canvas.scales, <double>[scale]);
      for (final Path path in canvas.paths) {
        final Rect scaledBounds = measureDrawnBounds(
          path,
        ).inflate(AppSizes.iconStroke / 2);
        expect(scaledBounds.left * scale, greaterThan(-_boundsTolerance));
        expect(scaledBounds.top * scale, greaterThan(-_boundsTolerance));
        final double farthestEdge = size.shortestSide + _boundsTolerance;
        expect(scaledBounds.right * scale, lessThan(farthestEdge));
        expect(scaledBounds.bottom * scale, lessThan(farthestEdge));
      }
    }
  });

  test('test_app_icon_painter_paint_property_geometry_ignores_color_and_'
      'size', () {
    final Random random = seededRandom(90706);
    final PictureRecorder recorder = PictureRecorder();
    final Canvas realCanvas = Canvas(recorder);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppIconKind kind = pickOne(random, AppIconKind.values);
      final AppIconPainter first = AppIconPainter(
        kind: kind,
        color: _randomColor(random),
      );
      final AppIconPainter second = AppIconPainter(
        kind: kind,
        color: _randomColor(random),
      );

      final _RecordingCanvas firstCanvas = _paintIcon(
        first,
        _randomSize(random),
      );
      final _RecordingCanvas secondCanvas = _paintIcon(
        second,
        _randomSize(random),
      );
      second.paint(realCanvas, _randomSize(random));

      expect(_describeShapes(secondCanvas), _describeShapes(firstCanvas));
    }
    recorder.endRecording().dispose();
  });

  test('test_should_repaint_property_any_color_change_repaints', () {
    final Random random = seededRandom(90707);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppIconKind kind = pickOne(random, AppIconKind.values);
      final Color color = _randomColor(random);
      final Color otherColor = _randomColor(random);
      final AppIconPainter painter = AppIconPainter(kind: kind, color: color);
      final AppIconPainter recolored = AppIconPainter(
        kind: kind,
        color: otherColor,
      );

      expect(painter.shouldRepaint(recolored), color != otherColor);
    }
  });

  test('test_should_repaint_property_is_symmetric', () {
    final Random random = seededRandom(90708);
    final List<Color> colors = <Color>[
      _randomColor(random),
      _randomColor(random),
    ];

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppIconPainter first = AppIconPainter(
        kind: pickOne(random, AppIconKind.values),
        color: pickOne(random, colors),
      );
      final AppIconPainter second = AppIconPainter(
        kind: pickOne(random, AppIconKind.values),
        color: pickOne(random, colors),
      );

      expect(first.shouldRepaint(second), second.shouldRepaint(first));
    }
  });

  test('test_build_icon_shape_path_property_rectangles_fill_their_box', () {
    final Random random = seededRandom(90709);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double width = 1 + random.nextDouble() * _largestSide;
      final double height = 1 + random.nextDouble() * _largestSide;
      final IconRectangleShape shape = IconRectangleShape(
        left: randomGridNumber(random),
        top: randomGridNumber(random),
        width: width,
        height: height,
        cornerRadius: random.nextDouble() * min(width, height) / 2,
      );

      final Rect bounds = buildIconShapePath(shape).getBounds();

      final Rect expected = Rect.fromLTWH(shape.left, shape.top, width, height);
      expect(bounds.left, closeTo(expected.left, _boundsTolerance));
      expect(bounds.top, closeTo(expected.top, _boundsTolerance));
      expect(bounds.right, closeTo(expected.right, _boundsTolerance));
      expect(bounds.bottom, closeTo(expected.bottom, _boundsTolerance));
    }
  });

  test('test_build_icon_shape_path_property_path_shapes_parse_their_'
      'data', () {
    final Random random = seededRandom(90710);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String pathData = spellIconPath(
        random,
        randomIconPathCommands(random),
        relativity: IconPathRelativity.mixed,
        letters: IconPathLetters.implicitRepeats,
      );

      final Path built = buildIconShapePath(IconPathShape(pathData));

      expect(
        describePathGeometry(built),
        describePathGeometry(parseIconPath(pathData)),
      );
    }
  });
}
