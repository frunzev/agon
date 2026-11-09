import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/shared/approval_policy_field.dart';
import 'package:agent_orchestration/screens/task_form/agent_place_field.dart';
import 'package:agent_orchestration/screens/task_form/schedule_fields.dart';
import 'package:agent_orchestration/screens/task_form/task_skills_field.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import '../../support/form_finders.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/new_items/work_draft_review.dart';
import 'package:agent_orchestration/screens/task_form/task_form.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';

import '../../support/random_inputs.dart';
import 'random_drafts.dart';
import 'work_draft_form_scene.dart';
import 'work_draft_support.dart';

const String _deletedProjectLabel = 'Deleted project';

TaskForm _buildUnpumpedForm(DraftKind kind, DraftedWork work) {
  final AppDependencies dependencies = buildGalleryDependencies();
  final WorkDraftReview review = buildRecordingWorkReview(
    kind: kind,
    dependencies: dependencies,
    navigation: openWorkNavigation(kind),
    chosenTargets: <RunnerTarget>[],
  );
  final Widget form = review.buildForm(
    work,
    FormCallbackRecorder().buildCallbacks(),
  );
  if (form is! TaskForm) {
    throw StateError('A work review shows the task form, not $form');
  }
  return form;
}

RepeatChoice _describeRepeat(Schedule? schedule) {
  return switch (schedule) {
    null => RepeatChoice.none,
    HourlySchedule() => RepeatChoice.hourly,
    DailySchedule() => RepeatChoice.daily,
    WeeklySchedule() => RepeatChoice.weekly,
  };
}

T _readSelected<T>(WidgetTester tester) {
  final SelectField<T> field = tester.widget(
    find.byWidgetPredicate((Widget widget) => widget is SelectField<T>),
  );
  return field.value;
}

String _formatClock(ScheduleTime time) {
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

void _expectShownSchedule(WidgetTester tester, Schedule? schedule) {
  final ScheduleFields fields = tester.widget(find.byType(ScheduleFields));
  expect(fields.repeat, _describeRepeat(schedule));
  switch (schedule) {
    case null || HourlySchedule():
      expect(findFieldInput(workTimeLabel), findsNothing);
    case DailySchedule(:final ScheduleTime at):
      expect(readWorkFieldText(tester, workTimeLabel), _formatClock(at));
    case WeeklySchedule(:final Weekday on, :final ScheduleTime at):
      expect(fields.weekday, on);
      expect(readWorkFieldText(tester, workTimeLabel), _formatClock(at));
  }
}

String _describeShownProjectName(WorkFormScene scene) {
  final ProjectId shownProjectId = scene.shownWork.projectId!;
  for (final Project project in galleryProjects) {
    if (project.id == shownProjectId) {
      return project.name;
    }
  }
  return _deletedProjectLabel;
}

void _expectShownWorkFields(WidgetTester tester, WorkFormScene scene) {
  final DraftedWork work = scene.work;
  final DraftedWork shown = scene.shownWork;
  final TaskSkillsField skills = tester.widget(find.byType(TaskSkillsField));
  final AgentPlaceField place = tester.widget(find.byType(AgentPlaceField));
  final ApprovalPolicyField approval = tester.widget(
    find.byType(ApprovalPolicyField),
  );
  final String projectName = _describeShownProjectName(scene);

  expect(readWorkFieldText(tester, workTitleLabel), work.title);
  expect(readWorkFieldText(tester, workDetailsLabel), work.details);
  expect(_readSelected<ProjectId>(tester), shown.projectId);
  expect(_readSelected<TaskDoer>(tester), shown.doer);
  expect(_readSelected<RunnerTarget>(tester), work.runsOn);
  expect(place.place, work.agentPlace);
  expect(skills.skillIds, work.skills);
  expect(skills.usesAutomaticSkills, work.usesAutomaticSkills);
  expect(approval.selected, work.approvalPolicy);
  _expectShownSchedule(tester, shown.schedule);

  expect(find.text(projectName), findsWidgets);
  for (final String skillName in listSkillNames(scene.dependencies, work)) {
    expect(find.text(skillName), findsWidgets);
  }
}

void main() {
  test('test_is_job_property_job_forms_offer_only_repeating_choices', () {
    final Random random = seededRandom(10401);
    for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
      final DraftKind kind = pickOne(random, workDraftKinds);

      final TaskForm form = _buildUnpumpedForm(
        kind,
        randomListedWork(random, kind),
      );

      final bool isJob = kind == DraftKind.job;
      expect(form.repeatChoices.contains(RepeatChoice.none), !isJob);
      expect(form.repeatHint, isJob ? isNull : taskRepeatHint);
      expect(form.repeatChoices.toSet(), <RepeatChoice>{
        RepeatChoice.hourly,
        RepeatChoice.daily,
        RepeatChoice.weekly,
        if (!isJob) RepeatChoice.none,
      });
    }
  });

  test('test_is_job_property_unscheduled_jobs_start_on_the_design_week', () {
    final Random random = seededRandom(10402);
    for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
      final DraftKind kind = pickOne(random, workDraftKinds);

      final TaskForm form = _buildUnpumpedForm(
        kind,
        randomUnscheduledWork(random),
      );

      final TaskFormValues values = form.initialValues;
      final bool isJob = kind == DraftKind.job;
      expect(values.repeat, isJob ? RepeatChoice.weekly : RepeatChoice.none);
      expect(form.repeatChoices, contains(values.repeat));
      expect(values.weekday, Weekday.monday);
      expect(values.timeText, defaultScheduleTimeText);
    }
  });

  test('test_is_job_property_scheduled_drafts_keep_their_repeat', () {
    final Random random = seededRandom(10403);
    for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
      final DraftKind kind = pickOne(random, workDraftKinds);
      final DraftedWork work = randomScheduledWork(random);

      final TaskForm form = _buildUnpumpedForm(kind, work);

      expect(form.initialValues.repeat, _describeRepeat(work.schedule));
      expect(form.repeatChoices, contains(form.initialValues.repeat));
    }
  });

  test('test_work_draft_review_build_form_property_ends_cancel_approve', () {
    final Random random = seededRandom(10404);
    for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
      final DraftKind kind = pickOne(random, workDraftKinds);

      final TaskForm form = _buildUnpumpedForm(
        kind,
        randomListedWork(random, kind),
      );

      final List<FormAction<TaskFormValues>> actions = form.actions;
      expect(actions, hasLength(2));
      expect(actions.first, isA<LeaveFormAction<TaskFormValues>>());
      expect(actions.last, isA<SubmitFormAction<TaskFormValues>>());
    }
  });

  testWidgets('test_work_draft_review_build_form_property_shows_every_field', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10405);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, workDraftKinds);
      final WorkFormScene scene = await pumpWorkForm(
        tester,
        random: random,
        kind: kind,
        work: randomHostileWork(random, kind),
      );

      _expectShownWorkFields(tester, scene);
      expect(tester.takeException(), isNull, reason: 'round $i');
    }
  });

  testWidgets(
    'test_work_draft_review_build_form_property_approve_hands_back_shown',
    (WidgetTester tester) async {
      final Random random = seededRandom(10406);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final DraftKind kind = pickOne(random, workDraftKinds);
        final WorkFormScene scene = await pumpWorkForm(
          tester,
          random: random,
          kind: kind,
          work: randomHostileWork(random, kind),
        );

        await tapReviewAction(tester, approveLabel);

        expect(scene.recorder.cancelCount, 0);
        if (scene.hasDeletedChoice) {
          expect(scene.recorder.approvedItems, isEmpty);
          continue;
        }
        expect(scene.recorder.approvedItems, hasLength(1));
        expectSameWork(scene.recorder.approvedItems.single, scene.shownWork);
      }
    },
  );

  testWidgets(
    'test_work_draft_review_build_form_property_cancel_only_leaves',
    (WidgetTester tester) async {
      final Random random = seededRandom(10407);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final DraftKind kind = pickOne(random, workDraftKinds);
        final WorkFormScene scene = await pumpWorkForm(
          tester,
          random: random,
          kind: kind,
          work: randomHostileWork(random, kind),
        );

        await tapReviewAction(tester, cancelReviewLabel);

        expect(scene.recorder.cancelCount, 1);
        expect(scene.recorder.approvedItems, isEmpty);
        expect(scene.recorder.changedItems, isEmpty);
      }
    },
  );

  testWidgets(
    'test_work_draft_review_build_form_property_refusals_are_shown',
    (WidgetTester tester) async {
      final Random random = seededRandom(10408);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final DraftKind kind = pickOne(random, workDraftKinds);
        final String explanation = 'Refused ${randomWordPhrase(random)}'
            .trim();
        final WorkFormScene scene = await pumpWorkForm(
          tester,
          random: random,
          kind: kind,
          work: randomHostileWork(random, kind),
        );
        scene.recorder.approvalProblem = PeopleFacingRefusal(explanation);

        await tapReviewAction(tester, approveLabel);

        final Matcher shownRefusal = scene.hasDeletedChoice
            ? findsNothing
            : findsOneWidget;
        expect(find.text('$approveLabel did not work'), shownRefusal);
        expect(find.text(explanation), shownRefusal);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
