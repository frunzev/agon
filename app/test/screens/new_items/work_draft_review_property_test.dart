import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/work_draft_review.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/people_facing_refusal_matchers.dart';
import '../../support/random_inputs.dart';
import 'draft_record_fields.dart';
import 'random_drafts.dart';
import 'work_draft_form_scene.dart';
import 'work_draft_support.dart';

const List<String> _blankTitles = <String>['', ' ', '\t', '\n', '\u3000'];

Future<Object> _catchApprovalProblem(
  WorkDraftReview review,
  DraftedItem item,
) async {
  try {
    await review.approve(item);
  } on Object catch (problem) {
    return problem;
  }
  throw StateError('The approval of $item was not refused');
}

void main() {
  test('test_work_draft_review_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(10301);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, DraftKind.values);
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = openWorkNavigation(kind);

      final WorkDraftReview review = buildRecordingWorkReview(
        kind: kind,
        dependencies: dependencies,
        navigation: navigation,
        chosenTargets: <RunnerTarget>[],
      );

      expect(review.kind, kind);
      expect(
        identical(review.taskRepository, dependencies.taskRepository),
        isTrue,
      );
      expect(
        identical(review.jobRepository, dependencies.jobRepository),
        isTrue,
      );
      expect(identical(review.navigation, navigation), isTrue);
      expect(review, isA<DraftReview>());
    }
  });

  test(
    'test_work_draft_review_constructor_property_options_come_from_builder',
    () {
      final Random random = seededRandom(10302);
      for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
        final DraftKind kind = pickOne(random, workDraftKinds);
        final List<RunnerTarget> chosenTargets = <RunnerTarget>[];
        final DraftedWork work = randomListedWork(random, kind);
        final WorkDraftReview review = buildRecordingWorkReview(
          kind: kind,
          dependencies: buildGalleryDependencies(),
          navigation: openWorkNavigation(kind),
          chosenTargets: chosenTargets,
        );

        review.buildForm(work, FormCallbackRecorder().buildCallbacks());

        expect(chosenTargets, <RunnerTarget>[work.runsOn]);
      }
    },
  );

  test(
    'test_work_draft_review_constructor_property_kind_decides_jobs',
    () async {
      final Random random = seededRandom(10303);
      for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
        final DraftedWork work = randomUnscheduledWork(random);
        final ApprovalScene taskScene = setUpWorkApproval(DraftKind.task);
        final ApprovalScene jobScene = setUpWorkApproval(DraftKind.job);

        await taskScene.review.approve(work);

        await expectLater(
          jobScene.review.approve(work),
          throwsPeopleFacingRefusal,
        );
        expect(taskScene.navigation.currentRoute, isA<TaskRunRoute>());
        expectNoWorkChanged(jobScene);
      }
    },
  );

  test(
    'test_work_draft_review_approve_property_scheduled_work_is_one_job',
    () async {
      final Random random = seededRandom(10304);
      for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
        final DraftKind kind = pickOne(random, workDraftKinds);
        final DraftedWork work = randomScheduledWork(random);
        final ApprovalScene scene = setUpWorkApproval(kind);

        await scene.review.approve(work);

        final Task created = findOnlyNewWork(
          scene.dependencies,
          scene.idsBefore,
        );
        expect(
          describeSavedWorkFields(created),
          describeDraftedWorkFields(work),
        );
        expect(
          scene.dependencies.taskRepository.listRuns(created.id),
          isEmpty,
        );
        expect(scene.dependencies.jobRepository.listJobs(), contains(created));
      }
    },
  );

  test(
    'test_work_draft_review_approve_property_unscheduled_task_starts',
    () async {
      final Random random = seededRandom(10305);
      for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
        final DraftedWork work = randomUnscheduledWork(random);
        final ApprovalScene scene = setUpWorkApproval(DraftKind.task);

        await scene.review.approve(work);

        final Task created = findOnlyNewWork(
          scene.dependencies,
          scene.idsBefore,
        );
        final List<Run> runs = scene.dependencies.taskRepository.listRuns(
          created.id,
        );
        expect(
          describeSavedWorkFields(created),
          describeDraftedWorkFields(work),
        );
        expect(runs, hasLength(1));
        expect(scene.navigation.routes, <AppRoute>[
          scene.routesBefore.first,
          TaskRunRoute(runs.single.id),
        ]);
      }
    },
  );

  test(
    'test_work_draft_review_approve_property_refusals_create_nothing',
    () async {
      final Random random = seededRandom(10306);
      for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
        final DraftKind kind = pickOne(random, workDraftKinds);
        final DraftedWork drafted = random.nextBool()
            ? randomScheduledWork(random)
            : randomUnscheduledWork(random);
        final bool dropsProject = random.nextBool();
        final DraftedWork work = rebuildWork(
          drafted,
          title: dropsProject ? drafted.title : pickOne(random, _blankTitles),
          projectId: dropsProject ? null : drafted.projectId,
          schedule: drafted.schedule,
        );
        final ApprovalScene scene = setUpWorkApproval(kind);

        final Object problem = await _catchApprovalProblem(scene.review, work);

        expect(describeProblemForPeople(problem), isNotNull);
        expectNoWorkChanged(scene);
      }
    },
  );

  test(
    'test_work_draft_review_approve_property_job_needs_a_schedule',
    () async {
      final Random random = seededRandom(10307);
      for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
        final DraftedWork work = randomUnscheduledWork(random);
        final ApprovalScene scene = setUpWorkApproval(DraftKind.job);

        final Object problem = await _catchApprovalProblem(scene.review, work);

        expect(describeProblemForPeople(problem), contains(work.title));
        expectNoWorkChanged(scene);
      }
    },
  );
}
