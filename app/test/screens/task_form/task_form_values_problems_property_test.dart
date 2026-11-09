import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';

import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../../support/sample_records.dart';
import 'task_form_scene.dart';

const List<String> _lookAlikeCharacters = <String>['﻿', '​', '᠎', '⁠'];

TaskFormValues _randomValues(Random random) {
  return randomTaskFormValues(random, buildRandomTaskFormOptions(random));
}

String _randomTimeText(Random random) {
  return pickOne(random, <String>[
    formatScheduleTime(randomScheduleTime(random)),
    randomText(random),
    '${random.nextInt(30)}:${random.nextInt(70)}',
    '',
  ]);
}

void main() {
  final RuleTitleWhiteSpaceTable whiteSpaceTable =
      readRuleTitleWhiteSpaceTable();

  test('test_describe_title_problem_property_unicode_blank_titles_only', () {
    final Random random = seededRandom(1140501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = whiteSpaceTable.randomExoticTitle(random);
      final TaskFormValues values = _randomValues(random)
          .copyWith(title: title);

      final bool isBlank = whiteSpaceTable.trimByModel(title).isEmpty;

      expect(values.describeTitleProblem() != null, isBlank, reason: title);
    }
  });

  test('test_describe_title_problem_property_look_alikes_are_not_'
      'white_space', () {
    final Random random = seededRandom(1140502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title =
          '${whiteSpaceTable.randomWhiteSpaceRun(random)}'
          '${pickOne(random, _lookAlikeCharacters)}'
          '${whiteSpaceTable.randomWhiteSpaceRun(random)}';
      final TaskFormValues values = _randomValues(random)
          .copyWith(title: title);

      expect(values.describeTitleProblem(), isNull);
      expect(values.toDraftedWork().title, isNotEmpty);
    }
  });

  test('test_describe_title_problem_property_white_space_runs_are_'
      'blank', () {
    final Random random = seededRandom(1140503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = whiteSpaceTable.randomWhiteSpaceRun(random);
      final TaskFormValues values = _randomValues(random)
          .copyWith(title: title);

      expect(values.describeTitleProblem(), 'Write what should be done.');
      expect(values.isValid, isFalse);
    }
  });

  test('test_describe_time_problem_property_only_unreadable_clock_'
      'times', () {
    final Random random = seededRandom(1140504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String timeText = _randomTimeText(random);
      final TaskFormValues values = _randomValues(random)
          .copyWith(timeText: timeText);

      final bool isUnreadable = parseScheduleTime(timeText) == null;

      expect(
        values.describeTimeProblem() != null,
        values.repeat.needsTime && isUnreadable,
        reason: '${values.repeat} "$timeText"',
      );
    }
  });

  test('test_describe_time_problem_property_every_clock_time_is_fine', () {
    for (int hour = 0; hour < Duration.hoursPerDay; hour += 1) {
      for (int minute = 0; minute < Duration.minutesPerHour; minute += 7) {
        final String timeText = formatScheduleTime(
          ScheduleTime(hour: hour, minute: minute),
        );
        final TaskFormValues values = TaskFormValues.blank(
          projectId: sampleProjectIds.first,
          doer: randomTaskDoer(seededRandom(hour)),
          repeat: RepeatChoice.weekly,
        ).copyWith(timeText: timeText);

        expect(values.describeTimeProblem(), isNull, reason: timeText);
      }
    }
  });

  test('test_describe_time_problem_property_problem_names_the_format', () {
    final Random random = seededRandom(1140505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = _randomValues(random).copyWith(
        repeat: pickOne(random, <RepeatChoice>[
          RepeatChoice.daily,
          RepeatChoice.weekly,
        ]),
        timeText: '${24 + random.nextInt(75)}:${random.nextInt(6)}0',
      );

      expect(
        values.describeTimeProblem(),
        'Write the time as HH:MM, for example 09:00.',
      );
    }
  });

  test('test_is_valid_property_means_no_problem_is_described', () {
    final Random random = seededRandom(1140506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = _randomValues(random).copyWith(
        title: whiteSpaceTable.randomExoticTitle(random),
        timeText: _randomTimeText(random),
      );

      final bool hasNoProblem =
          values.describeTitleProblem() == null &&
          values.describeTimeProblem() == null;

      expect(values.isValid, hasNoProblem);
    }
  });

  test('test_is_valid_property_valid_values_always_convert', () {
    final Random random = seededRandom(1140507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = _randomValues(random).copyWith(
        title: whiteSpaceTable.randomExoticTitle(random),
        timeText: _randomTimeText(random),
      );
      if (!values.isValid) {
        continue;
      }

      expect(values.toDraftedWork().title, isNotEmpty);
      expect(values.toTaskDraft().title, isNotEmpty);
      expect(values.toSchedule() == null, values.repeat == RepeatChoice.none);
    }
  });

  test('test_is_valid_property_other_choices_never_change_it', () {
    final Random random = seededRandom(1140508);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = _randomValues(random).copyWith(
        title: whiteSpaceTable.randomExoticTitle(random),
        timeText: _randomTimeText(random),
      );
      final TaskFormValues other = _randomValues(random);

      final TaskFormValues changed = values
          .copyWith(
            projectId: other.projectId,
            doer: other.doer,
            runsOn: other.runsOn,
            agentPlace: other.agentPlace,
            skillIds: other.skillIds,
            usesAutomaticSkills: other.usesAutomaticSkills,
            weekday: other.weekday,
            details: other.details,
          )
          .withApprovalPolicy(other.approvalPolicy);

      expect(changed.isValid, values.isValid);
    }
  });
}
