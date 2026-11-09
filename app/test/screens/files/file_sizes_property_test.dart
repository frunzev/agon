import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_sizes.dart';

import '../../support/random_inputs.dart';

const int _unit = 1024;
const List<String> _units = <String>['B', 'KB', 'MB', 'GB'];
const int _largestShownUnitIndex = 3;
final RegExp _sizePattern = RegExp(r'^(\d+)(\.\d)? (B|KB|MB|GB)$');
const List<int> _boundarySizes = <int>[
  0,
  1,
  1023,
  1024,
  1025,
  10137,
  10188,
  10239,
  10240,
  1047552,
  1048063,
  1048064,
  1048575,
  1048576,
  1073689395,
  1073741823,
  1073741824,
  1099511627775,
  1099511627776,
  9223372036854775807,
];

typedef _ShownSize = ({String number, int unitIndex});

_ShownSize _readShownSize(String shown) {
  final RegExpMatch? match = _sizePattern.firstMatch(shown);
  if (match == null) {
    throw FormatException('not a file size', shown);
  }
  final String number = '${match.group(1)}${match.group(2) ?? ''}';
  return (number: number, unitIndex: _units.indexOf(match.group(3)!));
}

double _approximateBytes(String shown) {
  final _ShownSize size = _readShownSize(shown);
  return double.parse(size.number) * pow(_unit, size.unitIndex);
}

int _randomSizeNearABoundary(Random random) {
  final int boundary = pow(_unit, 1 + random.nextInt(3)).toInt();
  final int offset = random.nextInt(2048) - 1024;
  return max(0, boundary + offset);
}

int _randomSizeOfAnyMagnitude(Random random) {
  final int base = random.nextInt(1 << 31);
  return base << random.nextInt(33);
}

List<int> _sampleSizes(Random random) {
  return <int>[
    ..._boundarySizes,
    for (int i = 0; i < propertyIterations; i += 1)
      _randomSizeNearABoundary(random),
    for (int i = 0; i < propertyIterations; i += 1)
      _randomSizeOfAnyMagnitude(random),
  ];
}

void main() {
  test('test_describe_file_size_property_never_shows_a_full_next_unit', () {
    final Random random = seededRandom(99101);

    for (final int bytes in _sampleSizes(random)) {
      final _ShownSize shown = _readShownSize(describeFileSize(bytes));

      if (shown.unitIndex < _largestShownUnitIndex) {
        expect(double.parse(shown.number), lessThan(_unit), reason: '$bytes');
      }
    }
  });

  test('test_describe_file_size_property_never_shrinks_as_a_file_grows', () {
    final Random random = seededRandom(99102);
    final List<int> sizes = _sampleSizes(random)..sort();

    for (int index = 1; index < sizes.length; index += 1) {
      final double smaller = _approximateBytes(
        describeFileSize(sizes[index - 1]),
      );
      final double larger = _approximateBytes(describeFileSize(sizes[index]));

      expect(larger, greaterThanOrEqualTo(smaller), reason: '${sizes[index]}');
    }
  });

  test('test_describe_file_size_property_stays_within_rounding_of_bytes', () {
    final Random random = seededRandom(99103);

    for (final int bytes in _sampleSizes(random)) {
      final String shown = describeFileSize(bytes);
      final double approximate = _approximateBytes(shown);
      final double allowedError = max(0.5, bytes * 0.05);

      expect(
        (approximate - bytes).abs(),
        lessThanOrEqualTo(allowedError),
        reason: '$bytes shown as $shown',
      );
    }
  });

  test('test_describe_kilobytes_property_one_decimal_only_below_ten', () {
    final Random random = seededRandom(99104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int bytes = _unit + random.nextInt(_unit * 1023);
      final _ShownSize shown = _readShownSize(describeFileSize(bytes));
      if (shown.unitIndex != 1) {
        continue;
      }
      final bool hasDecimal = shown.number.contains('.');

      expect(hasDecimal, double.parse(shown.number) < 10, reason: '$bytes');
    }
  });

  test('test_describe_kilobytes_property_rounds_to_the_nearest_shown', () {
    final Random random = seededRandom(99105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int bytes = _unit + random.nextInt(_unit * 1023);
      final String shown = describeFileSize(bytes);
      final _ShownSize size = _readShownSize(shown);
      if (size.unitIndex != 1) {
        continue;
      }
      final double kilobytes = bytes / _unit;
      final double step = size.number.contains('.') ? 0.1 : 1;

      expect(
        (double.parse(size.number) - kilobytes).abs(),
        lessThanOrEqualTo(step / 2 + 1e-9),
        reason: '$bytes shown as $shown',
      );
    }
  });

  test('test_describe_kilobytes_property_unit_boundaries_read_naturally', () {
    expect(describeFileSize(1023), '1023 B');
    expect(describeFileSize(1024), '1.0 KB');
    expect(describeFileSize(10137), '9.9 KB');
    expect(describeFileSize(10239), '10 KB');
    expect(describeFileSize(1048064), '1.0 MB');
    expect(describeFileSize(1048575), '1.0 MB');
    expect(describeFileSize(1048576), '1.0 MB');
    expect(describeFileSize(1073741823), '1.0 GB');
  });

  test('test_round_to_tenths_property_large_units_show_one_decimal', () {
    final Random random = seededRandom(99106);

    for (final int bytes in _sampleSizes(random)) {
      final _ShownSize shown = _readShownSize(describeFileSize(bytes));
      if (shown.unitIndex < 2) {
        continue;
      }

      expect(shown.number, matches(RegExp(r'^\d+\.\d$')), reason: '$bytes');
    }
  });

  test('test_round_to_tenths_property_whole_megabytes_stay_exact', () {
    final Random random = seededRandom(99107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int megabytes = 1 + random.nextInt(1023);
      final int bytes = megabytes * _unit * _unit;

      expect(describeFileSize(bytes), '$megabytes.0 MB');
    }
  });

  test('test_round_to_tenths_property_within_half_a_tenth_of_the_value', () {
    final Random random = seededRandom(99108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int bytes = _unit * _unit + random.nextInt(1 << 30);
      final String shown = describeFileSize(bytes);
      final _ShownSize size = _readShownSize(shown);
      final double exact = bytes / pow(_unit, size.unitIndex);

      expect(
        (double.parse(size.number) - exact).abs(),
        lessThanOrEqualTo(0.05 + 1e-9),
        reason: '$bytes shown as $shown',
      );
    }
  });
}
