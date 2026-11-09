import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'task_form_scene.dart';

const List<String> _designedRepeatLabels = <String>[
  "Don't repeat",
  'Every hour',
  'Every day',
  'Every week',
];

void _expectSameValues(TaskFormValues actual, TaskFormValues expected) {
  expect(actual.title, expected.title);
  expect(actual.details, expected.details);
  expect(actual.timeText, expected.timeText);
  expect(actual.hourlyMinute, expected.hourlyMinute);
  expectSameChoices(actual, expected);
}

TaskFormValues _randomValues(Random random) {
  return randomTaskFormValues(random, buildRandomTaskFormOptions(random));
}

void main() {
  test('test_task_form_values_property_keeps_every_field', () {
    final Random random = seededRandom(1140101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues source = _randomValues(random);

      final TaskFormValues rebuilt = TaskFormValues(
        title: source.title,
        details: source.details,
        projectId: source.projectId,
        doer: source.doer,
        runsOn: source.runsOn,
        agentPlace: source.agentPlace,
        skillIds: source.skillIds,
        usesAutomaticSkills: source.usesAutomaticSkills,
        approvalPolicy: source.approvalPolicy,
        repeat: source.repeat,
        weekday: source.weekday,
        timeText: source.timeText,
        hourlyMinute: source.hourlyMinute,
      );

      _expectSameValues(rebuilt, source);
    }
  });

  test('test_task_form_values_property_skill_ids_are_a_frozen_copy', () {
    final Random random = seededRandom(1140102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SkillId> callerSkills = <SkillId>[
        for (final SkillId skillId in sampleSkillIds)
          if (random.nextBool()) skillId,
      ];
      final List<SkillId> expected = List<SkillId>.of(callerSkills);
      final TaskFormValues values = _randomValues(random)
          .copyWith(skillIds: callerSkills);

      callerSkills.add(pickOne(random, sampleSkillIds));

      expect(values.skillIds, expected);
      expect(
        () => values.skillIds.add(sampleSkillIds.first),
        throwsA(isA<UnsupportedError>()),
      );
    }
  });

  test('test_task_form_values_blank_property_keeps_given_choices', () {
    final Random random = seededRandom(1140103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ProjectId projectId = pickOne(random, sampleProjectIds);
      final TaskDoer doer = randomTaskDoer(random);
      final RepeatChoice repeat = pickOne(random, RepeatChoice.values);

      final TaskFormValues blank = TaskFormValues.blank(
        projectId: projectId,
        doer: doer,
        repeat: repeat,
      );

      expect(blank.projectId, projectId);
      expect(blank.doer, doer);
      expect(blank.repeat, repeat);
      expect(blank.title, isEmpty);
      expect(blank.details, isEmpty);
    }
  });

  test('test_task_form_values_blank_property_starts_from_the_defaults', () {
    for (final RepeatChoice repeat in RepeatChoice.values) {
      final TaskFormValues blank = TaskFormValues.blank(
        projectId: sampleProjectIds.first,
        doer: defaultTaskDoer,
        repeat: repeat,
      );

      expect(blank.runsOn, const AnyFreeRunner());
      expect(blank.agentPlace, defaultAgentPlace);
      expect(blank.skillIds, isEmpty);
      expect(blank.usesAutomaticSkills, isTrue);
      expect(blank.approvalPolicy, isNull);
      expect(blank.weekday, Weekday.monday);
      expect(blank.timeText, defaultScheduleTimeText);
      expect(blank.hourlyMinute, 0);
    }
  });

  test('test_task_form_values_blank_property_needs_only_a_title', () {
    for (final RepeatChoice repeat in RepeatChoice.values) {
      final TaskFormValues blank = TaskFormValues.blank(
        projectId: sampleProjectIds.first,
        doer: defaultTaskDoer,
        repeat: repeat,
      );

      expect(blank.describeTitleProblem(), isNotNull);
      expect(blank.describeTimeProblem(), isNull);
      expect(blank.isValid, isFalse);
      expect(blank.copyWith(title: 'Ship it').isValid, isTrue);
      expect(blank.toSchedule() == null, repeat == RepeatChoice.none);
    }
  });

  test('test_from_task_property_keeps_every_task_field_untrimmed', () {
    for (final Task task in <Task>[...galleryTasks, ...galleryJobs]) {
      final TaskFormValues values = TaskFormValues.fromTask(task);

      expect(values.title, task.title);
      expect(values.details, task.details);
      expect(values.projectId, task.projectId);
      expect(values.doer, task.doer);
      expect(values.runsOn, task.runsOn);
      expect(values.agentPlace, task.agentPlace);
      expect(values.skillIds, task.skills);
      expect(values.usesAutomaticSkills, task.usesAutomaticSkills);
      expect(values.approvalPolicy, task.approvalPolicy);
      expect(values.repeat == RepeatChoice.none, task.schedule == null);
    }
  });

  test('test_from_task_property_task_draft_round_trips', () {
    for (final Task task in <Task>[...galleryTasks, ...galleryJobs]) {
      final TaskDraft stored = task.toDraft();
      final TaskDraft edited = TaskFormValues.fromTask(task).toTaskDraft();

      expect(edited.title, stored.title);
      expect(edited.details, stored.details);
      expect(edited.projectId, stored.projectId);
      expect(edited.doer, stored.doer);
      expect(edited.runsOn, stored.runsOn);
      expect(edited.agentPlace, stored.agentPlace);
      expect(edited.skills, stored.skills);
      expect(edited.usesAutomaticSkills, stored.usesAutomaticSkills);
      expect(edited.approvalPolicy, stored.approvalPolicy);
    }
  });

  test('test_copy_with_property_without_changes_is_the_identity', () {
    final Random random = seededRandom(1140104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = _randomValues(random);

      _expectSameValues(values.copyWith(), values);
    }
  });

  test('test_copy_with_property_later_changes_win', () {
    final Random random = seededRandom(1140105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = _randomValues(random);
      final String firstTitle = randomText(random);
      final String lastTitle = randomText(random);
      final Weekday lastWeekday = pickOne(random, Weekday.values);

      final TaskFormValues twice = values
          .copyWith(title: firstTitle, weekday: Weekday.friday)
          .copyWith(title: lastTitle, weekday: lastWeekday);

      expect(twice.title, lastTitle);
      expect(twice.weekday, lastWeekday);
      expect(twice.approvalPolicy, values.approvalPolicy);
      expect(twice.hourlyMinute, values.hourlyMinute);
    }
  });

  test('test_with_approval_policy_property_is_idempotent', () {
    final Random random = seededRandom(1140106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = _randomValues(random);
      final ApprovalPolicy? policy = randomInheritableApprovalPolicy(random);

      final TaskFormValues once = values.withApprovalPolicy(policy);
      final TaskFormValues twice = once.withApprovalPolicy(policy);

      _expectSameValues(twice, once);
      expect(once.approvalPolicy, policy);
    }
  });

  test('test_with_approval_policy_property_the_last_policy_wins', () {
    final Random random = seededRandom(1140107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = _randomValues(random);
      final ApprovalPolicy? first = randomInheritableApprovalPolicy(random);
      final ApprovalPolicy? last = randomInheritableApprovalPolicy(random);

      final TaskFormValues changed = values
          .withApprovalPolicy(first)
          .withApprovalPolicy(last);

      expect(changed.approvalPolicy, last);
      expect(changed.toTaskDraft().approvalPolicy, last);
    }
  });

  for (final RepeatChoice repeat in RepeatChoice.values) {
    final String name = repeat.name;

    test('test_repeat_choice_${name}_label_property_matches_the_design', () {
      expect(repeat.label, _designedRepeatLabels[repeat.index]);
    });

    test('test_repeat_choice_${name}_label_property_is_unique', () {
      final Iterable<RepeatChoice> sameLabel = RepeatChoice.values.where(
        (RepeatChoice other) => other.label == repeat.label,
      );
      expect(sameLabel, <RepeatChoice>[repeat]);
    });

    test('test_repeat_choice_${name}_label_property_jobs_offer_only_'
        'repeats', () {
      final bool isOfferedForJobs = jobRepeatChoices.contains(repeat);
      expect(isOfferedForJobs, repeat != RepeatChoice.none);
    });

    test('test_repeat_choice_${name}_needs_time_property_only_clock_'
        'repeats', () {
      final bool isClockRepeat =
          repeat == RepeatChoice.daily || repeat == RepeatChoice.weekly;
      expect(repeat.needsTime, isClockRepeat);
    });

    test('test_repeat_choice_${name}_needs_time_property_matches_the_'
        'schedule', () {
      final TaskFormValues values = TaskFormValues.blank(
        projectId: sampleProjectIds.first,
        doer: defaultTaskDoer,
        repeat: repeat,
      );
      final Schedule? schedule = values.toSchedule();
      final bool hasClockTime =
          schedule is DailySchedule || schedule is WeeklySchedule;
      expect(repeat.needsTime, hasClockTime);
    });

    test('test_repeat_choice_${name}_needs_time_property_bad_time_'
        'blocks_only_timed_repeats', () {
      final TaskFormValues values = TaskFormValues.blank(
        projectId: sampleProjectIds.first,
        doer: defaultTaskDoer,
        repeat: repeat,
      ).copyWith(title: 'Ship', timeText: '25:99');
      expect(values.isValid, !repeat.needsTime);
    });
  }
}
