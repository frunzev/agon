import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/new_items/work_draft_review.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/random_inputs.dart';
import 'random_drafts.dart';
import 'work_draft_form_scene.dart';
import 'work_draft_support.dart';

const List<DraftKind> _libraryKinds = <DraftKind>[
  DraftKind.skill,
  DraftKind.rule,
];

void main() {
  test('test_open_jobs_property_a_job_draft_returns_below_its_page', () async {
    final Random random = seededRandom(10308);
    for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
      final ApprovalScene scene = setUpWorkApproval(DraftKind.job);

      await scene.review.approve(randomScheduledWork(random));

      expect(scene.navigation.routes, <AppRoute>[scene.routesBefore.first]);
      expect(scene.navigation.currentRoute.section, AppSection.jobs);
    }
  });

  test('test_open_jobs_property_a_scheduled_task_opens_the_jobs', () async {
    final Random random = seededRandom(10309);
    for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
      final ApprovalScene scene = setUpWorkApproval(DraftKind.task);

      await scene.review.approve(randomScheduledWork(random));

      expect(scene.navigation.routes, <AppRoute>[
        const SectionRoute(AppSection.jobs),
      ]);
    }
  });

  test('test_open_jobs_property_scheduled_work_never_opens_a_run', () async {
    final Random random = seededRandom(10310);
    for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
      final DraftKind kind = pickOne(random, workDraftKinds);
      final ApprovalScene scene = setUpWorkApproval(kind);

      await scene.review.approve(randomScheduledWork(random));

      final Task created = findOnlyNewWork(
        scene.dependencies,
        scene.idsBefore,
      );
      expect(created.schedule, isNotNull);
      expect(scene.navigation.routes.whereType<RunPageRoute>(), isEmpty);
    }
  });

  test(
    'test_require_work_property_approve_refuses_skills_and_rules',
    () async {
      final Random random = seededRandom(10311);
      for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
        final DraftKind kind = pickOne(random, workDraftKinds);
        final DraftKind otherKind = pickOne(random, _libraryKinds);
        final DraftedItem item = randomDraftedItem(random, otherKind, i);
        final ApprovalScene scene = setUpWorkApproval(kind);

        await expectLater(scene.review.approve(item), throwsArgumentError);
        expectNoWorkChanged(scene);
      }
    },
  );

  test('test_require_work_property_build_form_refuses_skills_and_rules', () {
    final Random random = seededRandom(10312);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, workDraftKinds);
      final DraftedItem item = randomDraftedItem(
        random,
        pickOne(random, _libraryKinds),
        i,
      );
      final List<RunnerTarget> chosenTargets = <RunnerTarget>[];
      final WorkDraftReview review = buildRecordingWorkReview(
        kind: kind,
        dependencies: buildGalleryDependencies(),
        navigation: openWorkNavigation(kind),
        chosenTargets: chosenTargets,
      );

      expect(
        () => review.buildForm(item, FormCallbackRecorder().buildCallbacks()),
        throwsArgumentError,
      );
      expect(chosenTargets, isEmpty);
    }
  });

  test('test_require_work_property_work_drafts_are_accepted', () async {
    final Random random = seededRandom(10313);
    for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
      final DraftKind kind = pickOne(random, workDraftKinds);
      final DraftedWork work = randomScheduledWork(random);
      final ApprovalScene scene = setUpWorkApproval(kind);

      await scene.review.approve(work);

      final Task created = findOnlyNewWork(
        scene.dependencies,
        scene.idsBefore,
      );
      expect(created.title, work.title);
    }
  });
}
