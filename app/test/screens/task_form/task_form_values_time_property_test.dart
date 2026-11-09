import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'task_form_values_inputs.dart';

void main() {
  test('test_to_schedule_property_hourly_ignores_the_time_text', () {
    final Random random = seededRandom(1140413);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int minute = random.nextInt(Duration.minutesPerHour);
      final TaskFormValues values = TaskFormValues.fromTask(
        buildScheduledTask(random, HourlySchedule(minute: minute)),
      ).copyWith(timeText: randomText(random));

      expect(describeScheduleShape(values.toSchedule()), 'hourly $minute');
    }
  });

  test('test_to_schedule_property_daily_ignores_the_weekday', () {
    final Random random = seededRandom(1140414);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScheduleTime at = randomScheduleTime(random);
      final TaskFormValues values = randomValuesFromDraft(
        random,
        DailySchedule(at: at),
      ).copyWith(weekday: pickOne(random, Weekday.values));

      expect(
        describeScheduleShape(values.toSchedule()),
        describeScheduleShape(DailySchedule(at: at)),
      );
    }
  });

  test('test_require_schedule_time_property_bad_text_is_refused_with_it', () {
    final Random random = seededRandom(1140415);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String badTime = '${random.nextInt(99)}h${randomText(random)}';
      final RepeatChoice repeat = pickOne(random, RepeatChoice.values);
      final TaskFormValues values = randomValuesFromDraft(
        random,
        null,
      ).copyWith(repeat: repeat, timeText: badTime);

      if (!repeat.needsTime) {
        expect(values.toSchedule() == null, repeat == RepeatChoice.none);
        continue;
      }
      expect(
        values.toSchedule,
        throwsA(
          isA<FormatException>().having(
            (FormatException problem) => problem.source,
            'source',
            badTime,
          ),
        ),
      );
    }
  });

  test('test_require_schedule_time_property_out_of_range_is_refused', () {
    final Random random = seededRandom(1140416);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int hour = Duration.hoursPerDay + random.nextInt(76);
      final int minute = Duration.minutesPerHour + random.nextInt(40);
      final String badTime = pickOne(random, <String>[
        '$hour:00',
        '00:$minute',
        '${random.nextInt(10)}:${random.nextInt(10)}0',
      ]);
      final TaskFormValues values = randomValuesFromDraft(random, null)
          .copyWith(
            repeat: pickOne(random, <RepeatChoice>[
              RepeatChoice.daily,
              RepeatChoice.weekly,
            ]),
            timeText: badTime,
          );

      expect(values.toSchedule, throwsFormatException);
      expect(values.describeTimeProblem(), isNotNull);
    }
  });

  test('test_require_schedule_time_property_padded_clocks_are_read', () {
    final Random random = seededRandom(1140417);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScheduleTime at = randomScheduleTime(random);
      final String padding = pickOne(random, <String>['', ' ', '\t', '  ']);
      final TaskFormValues values = randomValuesFromDraft(random, null)
          .copyWith(
            repeat: RepeatChoice.daily,
            timeText: '$padding${formatScheduleTime(at)}$padding',
          );

      expect(
        describeScheduleShape(values.toSchedule()),
        describeScheduleShape(DailySchedule(at: at)),
      );
    }
  });
}
