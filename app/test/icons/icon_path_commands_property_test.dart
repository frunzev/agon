import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/icon_path_parser.dart';

import '../support/random_inputs.dart';
import 'support/random_icon_paths.dart';

const double _geometryTolerance = 1e-6;
const double _lengthTolerance = 1e-3;
const int _largestSpan = 20;
const int _mostTooManyNumbers = 5;

String _geometryOf(String pathData) {
  return describePathGeometry(parseIconPath(pathData));
}

String _point(Offset point) {
  final String horizontal = spellPlainNumber(point.dx);
  final String vertical = spellPlainNumber(point.dy);
  return '$horizontal $vertical';
}

Offset _randomPoint(Random random) {
  return Offset(randomGridNumber(random), randomGridNumber(random));
}

double _length(String pathData) {
  double total = 0;
  for (final PathMetric contour in parseIconPath(pathData).computeMetrics()) {
    total += contour.length;
  }
  return total;
}

String _numbers(Random random, int count) {
  final List<String> spelled = <String>[];
  for (int i = 0; i < count; i += 1) {
    spelled.add(spellPlainNumber(randomGridNumber(random)));
  }
  return spelled.join(' ');
}

void main() {
  test('test_apply_command_property_every_spelling_draws_the_model_path', () {
    final Random random = seededRandom(90601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<IconPathCommand> commands = randomIconPathCommands(random);
      final String pathData = spellIconPath(
        random,
        commands,
        relativity: IconPathRelativity.mixed,
        letters: IconPathLetters.implicitRepeats,
      );

      expect(
        _geometryOf(pathData),
        describePathGeometry(buildModelIconPath(commands)),
        reason: pathData,
      );
    }
  });

  test('test_apply_command_property_absolute_and_relative_spellings_'
      'agree', () {
    final Random random = seededRandom(90602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<IconPathCommand> commands = randomIconPathCommands(random);
      final String absoluteData = spellIconPath(
        random,
        commands,
        relativity: IconPathRelativity.absolute,
        letters: IconPathLetters.everyCommand,
      );
      final String relativeData = spellIconPath(
        random,
        commands,
        relativity: IconPathRelativity.relative,
        letters: IconPathLetters.implicitRepeats,
      );

      expect(
        _geometryOf(relativeData),
        _geometryOf(absoluteData),
        reason: '$absoluteData versus $relativeData',
      );
    }
  });

  test('test_apply_command_property_close_returns_to_the_subpath_start', () {
    final Random random = seededRandom(90603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset start = _randomPoint(random);
      final Offset corner = _randomPoint(random);
      final Offset step = _randomPoint(random);
      final String closeLetter = pickOne(random, <String>['Z', 'z']);
      final String prefix = 'M${_point(start)}L${_point(corner)}$closeLetter';

      expect(
        _geometryOf('${prefix}l${_point(step)}'),
        _geometryOf('${prefix}L${_point(start + step)}'),
        reason: prefix,
      );
      expect(
        _geometryOf('${prefix}m${_point(step)}h1'),
        _geometryOf('${prefix}M${_point(start + step)}h1'),
        reason: prefix,
      );
    }
  });

  test('test_apply_curve_property_relative_points_share_the_start_'
      'origin', () {
    final Random random = seededRandom(90604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset start = _randomPoint(random);
      final List<Offset> offsets = <Offset>[
        _randomPoint(random),
        _randomPoint(random),
        _randomPoint(random),
      ];
      final List<String> relative = <String>[];
      final List<String> absolute = <String>[];
      for (final Offset offset in offsets) {
        relative.add(_point(offset));
        absolute.add(_point(start + offset));
      }

      expect(
        _geometryOf('M${_point(start)}c${relative.join(' ')}'),
        _geometryOf('M${_point(start)}C${absolute.join(' ')}'),
      );
    }
  });

  test('test_apply_curve_property_the_curve_end_becomes_the_current_'
      'point', () {
    final Random random = seededRandom(90605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset end = _randomPoint(random);
      final Offset step = _randomPoint(random);
      final String curve =
          'M0 0C${_point(_randomPoint(random))} '
          '${_point(_randomPoint(random))} ${_point(end)}';

      expect(
        _geometryOf('${curve}l${_point(step)}'),
        _geometryOf('${curve}L${_point(end + step)}'),
        reason: curve,
      );
    }
  });

  test('test_apply_curve_property_a_partial_group_of_six_fails', () {
    final Random random = seededRandom(90606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count =
          random.nextInt(2) * IconPathStep.curve.numberCount +
          1 +
          random.nextInt(_mostTooManyNumbers);
      final String letter = pickOne(random, <String>['C', 'c']);
      final String pathData = 'M0 0$letter${_numbers(random, count)}';

      expect(
        () => parseIconPath(pathData),
        throwsFormatException,
        reason: pathData,
      );
    }
  });

  test('test_apply_arc_property_ends_at_its_end_point_and_zero_radius_is_'
      'a_chord', () {
    final Random random = seededRandom(90607);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset start = _randomPoint(random);
      final Offset end = _randomPoint(random);
      final Offset step = _randomPoint(random);
      final String flags = '${random.nextInt(2)} ${random.nextInt(2)}';
      final String arc = 'M${_point(start)}A3 5 30 $flags ${_point(end)}';
      final String flatArc = 'M${_point(start)}A0 0 0 $flags ${_point(end)}';

      expect(
        _geometryOf('${arc}l${_point(step)}'),
        _geometryOf('${arc}L${_point(end + step)}'),
        reason: arc,
      );
      expect(
        _length(flatArc),
        closeTo((end - start).distance, _lengthTolerance),
        reason: flatArc,
      );
    }
  });

  test('test_apply_arc_property_flags_pick_the_side_and_the_size', () {
    final Random random = seededRandom(90608);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset start = _randomPoint(random);
      final double span = 1.0 + random.nextInt(_largestSpan);
      final Offset end = start + Offset(span, 0);
      final double radius = span * (0.75 + random.nextDouble());
      final String prefix = 'M${_point(start)}A$radius $radius 0';
      final String suffix = _point(end);

      final Rect smallClockwise = parseIconPath(
        '$prefix 0 1 $suffix',
      ).getBounds();
      final Rect smallCounterClockwise = parseIconPath(
        '$prefix 0 0 $suffix',
      ).getBounds();

      expect(smallClockwise.top, lessThan(start.dy - _geometryTolerance));
      expect(smallClockwise.bottom, closeTo(start.dy, _geometryTolerance));
      expect(
        smallCounterClockwise.bottom,
        greaterThan(start.dy + _geometryTolerance),
      );
      expect(
        _length('$prefix 1 1 $suffix'),
        greaterThanOrEqualTo(_length('$prefix 0 1 $suffix')),
      );
    }
  });

  test('test_apply_arc_property_negative_radii_draw_like_positive_'
      'radii', () {
    final Random random = seededRandom(90610);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset start = _randomPoint(random);
      final Offset end = _randomPoint(random);
      final double horizontalRadius = 1.0 + random.nextInt(_largestSpan);
      final double verticalRadius = 1.0 + random.nextInt(_largestSpan);
      final String tail =
          '0 ${random.nextInt(2)} ${random.nextInt(2)} ${_point(end)}';
      final String positive =
          'M${_point(start)}A$horizontalRadius $verticalRadius $tail';
      final String negative =
          'M${_point(start)}A-$horizontalRadius -$verticalRadius $tail';

      expect(_geometryOf(negative), _geometryOf(positive), reason: negative);
    }
  });

  test('test_apply_arc_property_a_partial_group_of_seven_fails', () {
    final Random random = seededRandom(90609);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count =
          random.nextInt(2) * IconPathStep.arc.numberCount +
          1 +
          random.nextInt(IconPathStep.arc.numberCount - 1);
      final String letter = pickOne(random, <String>['A', 'a']);
      final String pathData = 'M0 0$letter${_numbers(random, count)}';

      expect(
        () => parseIconPath(pathData),
        throwsFormatException,
        reason: pathData,
      );
    }
  });
}
