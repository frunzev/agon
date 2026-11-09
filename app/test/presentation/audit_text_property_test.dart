import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/audit_text.dart';
import 'package:agent_orchestration/presentation/count_text.dart';

import '../bridge/support/random_moments.dart';
import '../support/random_display_counts.dart';
import '../support/random_inputs.dart';

const int _minutesInTenDays = 10 * Duration.minutesPerDay;
final RegExp _bareClockPattern = RegExp(r'^\d\d:\d\d$');
final RegExp _entryCountPattern = RegExp(
  r'^(\d{1,3}(,\d{3})*) (entry|entries)$',
);

String _groupDigitsByReference(int count) {
  if (count < 1000) {
    return count.toString();
  }
  final String lowerGroup = (count % 1000).toString().padLeft(3, '0');
  return '${_groupDigitsByReference(count ~/ 1000)},$lowerGroup';
}

DateTime _startOfLocalDay(DateTime moment) {
  final DateTime localMoment = moment.toLocal();
  return DateTime(localMoment.year, localMoment.month, localMoment.day);
}

void main() {
  test('test_describe_audit_time_property_never_empty_and_deterministic', () {
    final Random random = seededRandom(97201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPreciseMoment(random);
      final int offsetMinutes =
          random.nextInt(2 * _minutesInTenDays) - _minutesInTenDays;
      final DateTime at = now.add(Duration(minutes: offsetMinutes));

      final String text = describeAuditTime(at, now);

      expect(text.trim(), isNotEmpty);
      expect(describeAuditTime(at, now), text);
    }
  });

  test('test_describe_audit_time_property_same_day_stays_put_as_day_goes', () {
    final Random random = seededRandom(97202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final DateTime dayStart = _startOfLocalDay(now);
      final int secondsSoFar = now.difference(dayStart).inSeconds;
      final DateTime at = dayStart.add(
        Duration(seconds: random.nextInt(secondsSoFar + 1)),
      );
      final DateTime laterSameDay = at.add(
        Duration(seconds: random.nextInt(secondsSoFar + 1)),
      );
      final bool isStillSameDay = _startOfLocalDay(laterSameDay) == dayStart;
      if (!isStillSameDay) {
        continue;
      }

      expect(describeAuditTime(at, now), describeAuditTime(at, laterSameDay));
      expect(_bareClockPattern.hasMatch(describeAuditTime(at, now)), isTrue);
    }
  });

  test('test_describe_audit_time_property_earlier_days_never_bare_clock', () {
    final Random random = seededRandom(97203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final DateTime dayStart = _startOfLocalDay(now);
      final DateTime at = dayStart.subtract(
        Duration(minutes: 1 + random.nextInt(_minutesInTenDays)),
      );

      final String text = describeAuditTime(at, now);

      expect(_bareClockPattern.hasMatch(text), isFalse, reason: text);
    }
  });

  test('test_group_digits_property_digits_round_trip_at_any_size', () {
    final Random random = seededRandom(97204);
    final List<int> boundaryCounts = <int>[
      0,
      999,
      1000,
      999999,
      1000000,
      largestDisplayedCount,
    ];

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = i < boundaryCounts.length
          ? boundaryCounts[i]
          : randomCountOfAnySize(random);

      final String text = describeEntryCount(count);
      final String digits = text.split(' ').first.replaceAll(',', '');

      expect(int.parse(digits), count, reason: text);
    }
  });

  test('test_group_digits_property_groups_of_three_without_leading_zero', () {
    final Random random = seededRandom(97205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = randomCountOfAnySize(random);

      final String text = describeEntryCount(count);
      final RegExpMatch? match = _entryCountPattern.firstMatch(text);

      expect(match, isNotNull, reason: text);
      final String grouped = match!.group(1)!;
      final bool hasLeadingZero = grouped.length > 1 && grouped[0] == '0';
      expect(hasLeadingZero, isFalse, reason: text);
    }
  });

  test('test_group_digits_property_matches_reference_grouping', () {
    final Random random = seededRandom(97206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = randomCountOfAnySize(random);

      final String grouped = describeEntryCount(count).split(' ').first;

      expect(grouped, _groupDigitsByReference(count));
    }
  });

  test('test_describe_entry_count_property_singular_only_for_exactly_one', () {
    final Random random = seededRandom(97207);
    final List<int> boundaryCounts = <int>[0, 1, 2, largestDisplayedCount];

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = i < boundaryCounts.length
          ? boundaryCounts[i]
          : randomCountOfAnySize(random);

      final String noun = describeEntryCount(count).split(' ').last;

      expect(noun, count == 1 ? 'entry' : 'entries');
    }
  });

  test('test_describe_entry_count_property_agrees_with_describe_count', () {
    final Random random = seededRandom(97208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = randomCountOfAnySize(random);

      final String generalText = describeCount(
        count,
        singular: 'entry',
        plural: 'entries',
      );

      expect(describeEntryCount(count), generalText);
    }
  });

  test('test_describe_entry_count_property_negatives_name_the_count', () {
    final Random random = seededRandom(97209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = -1 - randomCountOfAnySize(random);

      expect(
        () => describeEntryCount(count),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.invalidValue,
            'invalidValue',
            count,
          ),
        ),
      );
    }
  });
}
