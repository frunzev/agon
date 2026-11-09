import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../support/random_inputs.dart';
import 'support/edge_distance_model.dart';
import 'support/random_canvas_points.dart';
import 'support/random_diagram_layouts.dart';

const double _designCornerRadius = AppSpacing.space2;
const double _legReach = 300;
const double _floatTolerance = 0.05;
const double _sampleStep = 2;
const double _shapeTolerance = 0.05;
const int _largestCornerCount = 8;
const int _quadraticSteps = 16;

List<Offset> _randomRightAngleCorners(Random random) {
  final int cornerCount = 2 + random.nextInt(_largestCornerCount - 1);
  Offset corner = randomCanvasPoint(random, reach: _legReach);
  final List<Offset> corners = <Offset>[corner];
  for (int i = 1; i < cornerCount; i += 1) {
    final double leg = random.nextBool()
        ? randomSignedCoordinate(random, reach: _legReach)
        : randomSignedCoordinate(random, reach: _designCornerRadius);
    corner = i.isEven ? corner.translate(leg, 0) : corner.translate(0, leg);
    corners.add(corner);
  }
  return corners;
}

List<List<Offset>> _randomCornerLists(Random random) {
  final List<List<Offset>> cornerLists = <List<Offset>>[
    _randomRightAngleCorners(random),
  ];
  final Workflow workflow = randomLaidOutWorkflow(random);
  for (final DiagramEdge edge in describeSavedEdges(workflow)) {
    final EdgeRoute route = edge.route;
    if (route is LoopRoute) {
      cornerLists.add(route.corners);
    }
  }
  return cornerLists;
}

Path _buildPath(List<Offset> corners) {
  return buildEdgePath(LoopRoute(corners: corners, labelArea: Rect.zero));
}

double _measurePathLength(Path path) {
  double length = 0;
  for (final PathMetric metric in path.computeMetrics()) {
    length += metric.length;
  }
  return length;
}

List<Offset> _sampleQuadratic(Offset start, Offset control, Offset end) {
  return <Offset>[
    for (int step = 0; step <= _quadraticSteps; step += 1)
      Offset.lerp(
        Offset.lerp(start, control, step / _quadraticSteps),
        Offset.lerp(control, end, step / _quadraticSteps),
        step / _quadraticSteps,
      )!,
  ];
}

List<Offset> _modelRoundedShape(List<Offset> corners) {
  final List<Offset> shape = <Offset>[corners.first];
  for (int i = 1; i < corners.length - 1; i += 1) {
    final Offset toPrevious = corners[i - 1] - corners[i];
    final Offset toNext = corners[i + 1] - corners[i];
    final double shortestLeg = min(toPrevious.distance, toNext.distance);
    final double radius = min(_designCornerRadius, shortestLeg / 2);
    if (radius == 0) {
      shape.add(corners[i]);
      continue;
    }
    final Offset turnStart =
        corners[i] + toPrevious / toPrevious.distance * radius;
    final Offset turnEnd = corners[i] + toNext / toNext.distance * radius;
    shape.addAll(_sampleQuadratic(turnStart, corners[i], turnEnd));
  }
  shape.add(corners.last);
  return shape;
}

List<Offset> _samplePath(Path path) {
  final List<Offset> samples = <Offset>[];
  for (final PathMetric metric in path.computeMetrics()) {
    for (double at = 0; at < metric.length; at += _sampleStep) {
      samples.add(metric.getTangentForOffset(at)!.position);
    }
    samples.add(metric.getTangentForOffset(metric.length)!.position);
  }
  return samples;
}

void _expectPathFollowsModel(Path path, List<Offset> corners) {
  final List<Offset> model = _modelRoundedShape(corners);
  final List<Offset> samples = _samplePath(path);
  if (samples.length < 2) {
    expect(model.toSet().length, 1);
    return;
  }

  for (final Offset sample in samples) {
    expect(
      measureReferenceDistanceToPoints(model, sample),
      lessThan(_shapeTolerance),
    );
  }
  for (final Offset point in model) {
    double nearestSample = double.infinity;
    for (final Offset sample in samples) {
      nearestSample = min(nearestSample, (sample - point).distance);
    }
    expect(nearestSample, lessThan(_sampleStep));
  }
}

List<Offset> _repeatSomeCorners(Random random, List<Offset> corners) {
  final List<Offset> repeated = <Offset>[];
  for (final Offset corner in corners) {
    repeated.add(corner);
    if (random.nextBool()) {
      repeated.add(corner);
    }
  }
  return repeated;
}

void main() {
  test('test_build_rounded_path_property_follows_the_corner_model', () {
    final Random random = seededRandom(119001);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final List<Offset> corners in _randomCornerLists(random)) {
        _expectPathFollowsModel(_buildPath(corners), corners);
      }
    }
  });

  test('test_build_rounded_path_property_straight_corners_keep_length', () {
    final Random random = seededRandom(119002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset start = randomCanvasPoint(random, reach: _legReach);
      final Offset end = randomCanvasPoint(random, reach: _legReach);
      final int middleCount = random.nextInt(_largestCornerCount);
      final List<double> shares = <double>[
        0,
        for (int j = 0; j < middleCount; j += 1) random.nextDouble(),
        1,
      ];
      shares.sort();
      final List<Offset> corners = <Offset>[
        for (final double share in shares) Offset.lerp(start, end, share)!,
      ];

      expect(
        _measurePathLength(_buildPath(corners)),
        closeTo((end - start).distance, _floatTolerance),
      );
    }
  });

  test('test_build_rounded_path_property_is_one_open_line_end_to_end', () {
    final Random random = seededRandom(119003);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final List<Offset> corners in _randomCornerLists(random)) {
        final List<PathMetric> metrics = _buildPath(corners)
            .computeMetrics()
            .toList();
        if (metrics.isEmpty) {
          expect(corners.toSet().length, 1);
          continue;
        }
        final PathMetric line = metrics.single;
        final Offset first = line.getTangentForOffset(0)!.position;
        final Offset last = line.getTangentForOffset(line.length)!.position;

        expect(line.isClosed, isFalse);
        expect((first - corners.first).distance, lessThan(_floatTolerance));
        expect((last - corners.last).distance, lessThan(_floatTolerance));
      }
    }
  });

  test('test_move_toward_property_repeated_corners_stay_finite', () {
    final Random random = seededRandom(119004);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final List<Offset> corners in _randomCornerLists(random)) {
        final List<Offset> repeated = _repeatSomeCorners(random, corners);
        final Path path = _buildPath(repeated);

        expect(path.getBounds().isFinite, isTrue);
        _expectPathFollowsModel(path, repeated);
      }
    }
  });

  test('test_move_toward_property_turns_stay_near_their_corners', () {
    final Random random = seededRandom(119005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Offset> corners = _randomRightAngleCorners(random);

      for (final PathMetric metric in _buildPath(corners).computeMetrics()) {
        for (double at = 0; at <= metric.length; at += _sampleStep) {
          final Offset point = metric.getTangentForOffset(at)!.position;
          expect(
            measureReferenceDistanceToPoints(corners, point),
            lessThanOrEqualTo(_designCornerRadius / 2 + _floatTolerance),
          );
        }
      }
    }
  });

  test('test_move_toward_property_reversed_corners_trace_the_same_shape', () {
    final Random random = seededRandom(119006);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final List<Offset> corners in _randomCornerLists(random)) {
        final List<Offset> reversed = corners.reversed.toList();

        _expectPathFollowsModel(_buildPath(reversed), corners);
      }
    }
  });
}
