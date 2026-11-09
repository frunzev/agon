import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';

import '../../support/random_inputs.dart';
import '../../support/random_schedules.dart';
import '../../support/rule_title_white_space_table.dart';
import 'task_form_scene.dart';
import 'task_form_values_inputs.dart';

const String _unknownPrefix = 'unknown-';

Schedule? _randomOptionalSchedule(Random random) {
  if (random.nextInt(4) == 0) {
    return null;
  }
  return randomSchedule(random);
}

DraftedWork _randomKnownDraft(Random random, TaskFormOptions options) {
  final TaskFormValues values = randomTaskFormValues(random, options);
  return draftFromValues(values, _randomOptionalSchedule(random));
}

void _expectSameDraft(DraftedWork actual, DraftedWork expected) {
  expect(actual.title, expected.title);
  expect(actual.details, expected.details);
  expect(actual.projectId, expected.projectId);
  expect(actual.doer, expected.doer);
  expect(actual.runsOn, expected.runsOn);
  expect(actual.agentPlace, expected.agentPlace);
  expect(actual.skills, expected.skills);
  expect(actual.usesAutomaticSkills, expected.usesAutomaticSkills);
  expect(actual.approvalPolicy, expected.approvalPolicy);
  expect(
    describeScheduleShape(actual.schedule),
    describeScheduleShape(expected.schedule),
  );
}

List<SkillId> _mixInUnknownSkills(Random random, List<SkillId> known) {
  final List<SkillId> mixed = List<SkillId>.of(known);
  final int unknownCount = 1 + random.nextInt(3);
  for (int i = 0; i < unknownCount; i += 1) {
    final SkillId unknown = SkillId('$_unknownPrefix${random.nextInt(999)}');
    mixed.insert(random.nextInt(mixed.length + 1), unknown);
  }
  return mixed;
}

void main() {
  final RuleTitleWhiteSpaceTable whiteSpaceTable =
      readRuleTitleWhiteSpaceTable();

  test('test_from_drafted_work_property_unknown_choices_stay_shown', () {
    final Random random = seededRandom(1140201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final DraftedWork known = _randomKnownDraft(random, options);
      final DraftedWork hostile = DraftedWork(
        title: known.title,
        details: known.details,
        projectId: random.nextBool()
            ? null
            : ProjectId('$_unknownPrefix${random.nextInt(999)}'),
        doer: WorkflowDoer(WorkflowId('$_unknownPrefix${random.nextInt(9)}')),
        runsOn: known.runsOn,
        agentPlace: known.agentPlace,
        skills: _mixInUnknownSkills(random, known.skills),
        usesAutomaticSkills: known.usesAutomaticSkills,
        approvalPolicy: known.approvalPolicy,
        schedule: known.schedule,
      );

      final TaskFormValues values = TaskFormValues.fromDraftedWork(
        work: hostile,
        options: options,
        unscheduledRepeat: RepeatChoice.none,
      );

      expect(values.projectId, hostile.projectId ?? options.firstProjectId);
      expect(values.doer, hostile.doer);
      expect(values.skillIds, known.skills);
    }
  });

  test('test_from_drafted_work_property_known_drafts_round_trip', () {
    final Random random = seededRandom(1140202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final DraftedWork known = _randomKnownDraft(random, options);
      final DraftedWork work = draftFromValues(
        randomTaskFormValues(random, options).copyWith(
          title: whiteSpaceTable.trimByModel(known.title),
          details: whiteSpaceTable.trimByModel(known.details),
        ),
        known.schedule,
      );

      final DraftedWork back = TaskFormValues.fromDraftedWork(
        work: work,
        options: options,
        unscheduledRepeat: RepeatChoice.none,
      ).toDraftedWork();

      _expectSameDraft(back, work);
    }
  });

  test('test_from_drafted_work_property_unscheduled_timed_repeat_is_'
      'valid', () {
    final Random random = seededRandom(1140203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final DraftedWork work = draftFromValues(
        randomTaskFormValues(random, options),
        null,
      );
      final RepeatChoice repeat = pickOne(random, jobRepeatChoices);

      final TaskFormValues values = TaskFormValues.fromDraftedWork(
        work: work,
        options: options,
        unscheduledRepeat: repeat,
      );

      expect(values.repeat, repeat);
      expect(values.describeTimeProblem(), isNull);
      expect(values.toSchedule(), isNotNull);
    }
  });

  test('test_to_drafted_work_property_trims_unicode_white_space', () {
    final Random random = seededRandom(1140204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = whiteSpaceTable.randomExoticTitle(random);
      final String details = whiteSpaceTable.randomExoticTitle(random);
      final TaskFormValues values = randomTaskFormValues(
        random,
        buildRandomTaskFormOptions(random),
      ).copyWith(title: title, details: details);

      final DraftedWork work = values.toDraftedWork();

      expect(work.title, whiteSpaceTable.trimByModel(title));
      expect(work.details, whiteSpaceTable.trimByModel(details));
    }
  });

  test('test_to_drafted_work_property_keeps_choices_and_schedule', () {
    final Random random = seededRandom(1140205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = randomTaskFormValues(
        random,
        buildRandomTaskFormOptions(random),
      );

      final DraftedWork work = values.toDraftedWork();

      expect(work.projectId, values.projectId);
      expect(work.doer, values.doer);
      expect(work.runsOn, values.runsOn);
      expect(work.agentPlace, values.agentPlace);
      expect(work.skills, values.skillIds);
      expect(work.usesAutomaticSkills, values.usesAutomaticSkills);
      expect(work.approvalPolicy, values.approvalPolicy);
      expect(
        describeScheduleShape(work.schedule),
        describeScheduleShape(values.toSchedule()),
      );
    }
  });

  test('test_to_drafted_work_property_form_round_trips', () {
    final Random random = seededRandom(1140206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskFormValues values = randomTaskFormValues(random, options);

      final TaskFormValues back = TaskFormValues.fromDraftedWork(
        work: values.toDraftedWork(),
        options: options,
        unscheduledRepeat: values.repeat,
      );

      expect(back.repeat, values.repeat);
      expect(
        describeScheduleShape(back.toSchedule()),
        describeScheduleShape(values.toSchedule()),
      );
      _expectSameDraft(back.toDraftedWork(), values.toDraftedWork());
      expect(back.title, whiteSpaceTable.trimByModel(values.title));
    }
  });

  test('test_to_task_draft_property_matches_the_drafted_work', () {
    final Random random = seededRandom(1140207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormValues values = randomTaskFormValues(
        random,
        buildRandomTaskFormOptions(random),
      ).copyWith(title: whiteSpaceTable.randomExoticTitle(random));

      final TaskDraft draft = values.toTaskDraft();
      final DraftedWork work = values.toDraftedWork();

      expect(draft.title, work.title);
      expect(draft.details, work.details);
      expect(draft.projectId, work.projectId);
      expect(draft.doer, work.doer);
      expect(draft.skills, work.skills);
      expect(draft.approvalPolicy, work.approvalPolicy);
    }
  });

  test('test_from_drafted_work_property_known_skills_keep_their_order', () {
    final Random random = seededRandom(1140210);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final List<SkillId> known = <SkillId>[
        for (final Skill skill in options.skills.reversed)
          if (random.nextBool()) skill.id,
      ];
      final DraftedWork work = draftFromValues(
        randomTaskFormValues(
          random,
          options,
        ).copyWith(skillIds: _mixInUnknownSkills(random, known)),
        null,
      );

      final TaskFormValues values = TaskFormValues.fromDraftedWork(
        work: work,
        options: options,
        unscheduledRepeat: RepeatChoice.none,
      );

      expect(values.skillIds, known);
    }
  });
}
