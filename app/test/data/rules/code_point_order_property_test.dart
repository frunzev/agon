import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/code_point_order.dart';

import '../../support/random_inputs.dart';

const List<int> _codePointStarts = <int>[
  0x20,
  0x7f,
  0xe000,
  0xff00,
  0x10000,
  0x1f600,
];
const int _codePointSpan = 0x60;
const int _largestTextLength = 6;

String _randomText(Random random) {
  final StringBuffer text = StringBuffer();
  final int length = random.nextInt(_largestTextLength);
  for (int i = 0; i < length; i += 1) {
    final int start = pickOne(random, _codePointStarts);
    text.writeCharCode(start + random.nextInt(_codePointSpan));
  }
  return text.toString();
}

int _compareUtf8Bytes(String first, String second) {
  final List<int> firstBytes = utf8.encode(first);
  final List<int> secondBytes = utf8.encode(second);
  for (int i = 0; i < firstBytes.length && i < secondBytes.length; i += 1) {
    if (firstBytes[i] != secondBytes[i]) {
      return firstBytes[i].compareTo(secondBytes[i]);
    }
  }
  return firstBytes.length.compareTo(secondBytes.length);
}

void main() {
  test('test_compare_code_points_property_agrees_with_utf8_byte_order', () {
    final Random random = seededRandom(66421);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String first = _randomText(random);
      final String second = _randomText(random);

      expect(
        compareCodePoints(first, second).sign,
        _compareUtf8Bytes(first, second).sign,
        reason: '$first | $second',
      );
    }
  });

  test('test_compare_code_points_property_is_antisymmetric', () {
    final Random random = seededRandom(66422);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String first = _randomText(random);
      final String second = _randomText(random);

      expect(
        compareCodePoints(first, second).sign,
        -compareCodePoints(second, first).sign,
      );
      expect(compareCodePoints(first, first), 0);
    }
  });

  test('test_compare_code_points_property_sorting_is_transitive', () {
    final Random random = seededRandom(66423);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> texts = <String>[
        for (int j = 0; j < _largestTextLength; j += 1) _randomText(random),
      ];

      final List<String> sorted = List<String>.of(texts);
      sorted.sort(compareCodePoints);

      for (int index = 1; index < sorted.length; index += 1) {
        expect(
          _compareUtf8Bytes(sorted[index - 1], sorted[index]),
          lessThanOrEqualTo(0),
        );
      }
    }
  });
}
