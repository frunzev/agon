import 'dart:math';
import 'dart:ui';

import '../../support/random_inputs.dart';

const int _hundredths = 100;
const int _boundsSamplesPerContour = 400;
const List<String> _numberSeparators = <String>[
  ' ',
  ',',
  ', ',
  ' ,',
  '\n',
  '\t',
  '  ',
  '\r\n',
];
final RegExp _exponentMark = RegExp('[eE]');

String spellPlainNumber(double number) {
  if (number == number.roundToDouble()) {
    return number.toInt().toString();
  }
  return number.toString();
}

List<String> listNumberSpellings(double number) {
  final String plain = spellPlainNumber(number);
  final bool isWhole = number == number.roundToDouble();
  final int hundredthsCount = (number * _hundredths).round();
  return <String>[
    plain,
    '${hundredthsCount}e-2',
    '${hundredthsCount}E-2',
    '${plain}e+0',
    '${plain}E0',
    if (number >= 0) '+$plain',
    if (number >= 0) '00$plain',
    if (isWhole) '$plain.',
    if (isWhole) '$plain.0',
    if (plain.startsWith('0.')) plain.substring(1),
    if (plain.startsWith('-0.')) '-${plain.substring(2)}',
  ];
}

String spellIconPathNumber(Random random, double number) {
  return pickOne(random, listNumberSpellings(number));
}

bool _canTouch(String previousNumber, String nextNumber) {
  final String nextStart = nextNumber[0];
  if (nextStart == '-' || nextStart == '+') {
    return true;
  }
  final bool previousEndsItsFraction =
      previousNumber.contains('.') || previousNumber.contains(_exponentMark);
  return nextStart == '.' && previousEndsItsFraction;
}

String separateNumbers(Random random, String previous, String next) {
  if (random.nextBool() && _canTouch(previous, next)) {
    return '';
  }
  return pickOne(random, _numberSeparators);
}

String joinIconPathNumbers(Random random, List<String> spelledNumbers) {
  final StringBuffer buffer = StringBuffer();
  String? previous;
  for (final String spelled in spelledNumbers) {
    if (previous != null) {
      buffer.write(separateNumbers(random, previous, spelled));
    }
    buffer.write(spelled);
    previous = spelled;
  }
  return buffer.toString();
}

String describePathGeometry(Path path) {
  final StringBuffer description = StringBuffer('${path.getBounds()}');
  for (final PathMetric contour in path.computeMetrics()) {
    description.write(' | ${contour.length} ${contour.isClosed}');
  }
  return description.toString();
}

Rect measureDrawnBounds(Path path) {
  Rect? bounds;
  for (final PathMetric contour in path.computeMetrics()) {
    for (int i = 0; i <= _boundsSamplesPerContour; i += 1) {
      final double distance = contour.length * i / _boundsSamplesPerContour;
      final Tangent? tangent = contour.getTangentForOffset(distance);
      if (tangent == null) {
        continue;
      }
      final Rect point = Rect.fromCenter(
        center: tangent.position,
        width: 0,
        height: 0,
      );
      bounds = bounds == null ? point : bounds.expandToInclude(point);
    }
  }
  return bounds ?? Rect.zero;
}
