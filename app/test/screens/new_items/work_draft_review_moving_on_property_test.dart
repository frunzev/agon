import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/new_items/work_draft_review.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/held_save_repositories.dart';
import 'draft_review_moving_on.dart';
import 'work_draft_support.dart';

typedef _WorkReviewScene = ({
  WorkDraftReview review,
  SaveHold saveHold,
  AppNavigation navigation,
});

_WorkReviewScene _openWorkReview(DraftKind kind) {
  final AppDependencies gallery = buildGalleryDependencies();
  final SaveHold saveHold = SaveHold();
  final AppDependencies dependencies = replaceRepositories(
    gallery,
    taskRepository: HeldTaskRepository(
      stored: gallery.taskRepository,
      saveHold: saveHold,
    ),
    jobRepository: HeldJobRepository(
      stored: gallery.jobRepository,
      saveHold: saveHold,
    ),
  );
  final AppNavigation navigation = openWorkNavigation(kind);
  return (
    review: buildRecordingWorkReview(
      kind: kind,
      dependencies: dependencies,
      navigation: navigation,
      chosenTargets: <RunnerTarget>[],
    ),
    saveHold: saveHold,
    navigation: navigation,
  );
}

DraftedWork _randomWorkFor(Random random, DraftKind kind) {
  if (kind == DraftKind.job || random.nextBool()) {
    return randomScheduledWork(random);
  }
  return randomUnscheduledWork(random);
}

Future<List<AppRoute>> _approveWhileMovingOn(
  Random random,
  _WorkReviewScene scene,
  DraftedWork work,
) async {
  final Completer<void> hold = Completer<void>();
  scene.saveHold.hold = hold;
  final Future<void> approving = scene.review.approve(work);
  moveOnFromDraftReview(random, scene.navigation);
  final List<AppRoute> wentTo = scene.navigation.routes;
  hold.complete();
  await approving;
  return wentTo;
}

void main() {
  test('test_work_draft_review_approve_property_a_person_who_moved_on_stays_'
      'where_they_went', () async {
    final Random random = seededRandom(5312701);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final DraftKind kind = pickOne(random, workDraftKinds);
      final _WorkReviewScene scene = _openWorkReview(kind);

      final List<AppRoute> wentTo = await _approveWhileMovingOn(
        random,
        scene,
        _randomWorkFor(random, kind),
      );

      expect(scene.navigation.routes, wentTo);
      expect(scene.saveHold.saveCount, 1);
    }
  });

  test(
    'test_start_and_open_run_property_a_shown_review_opens_the_run',
    () async {
      final Random random = seededRandom(5312702);

      for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
        final _WorkReviewScene scene = _openWorkReview(DraftKind.task);

        await scene.review.approve(randomUnscheduledWork(random));

        expect(scene.navigation.routes, hasLength(2));
        expect(
          scene.navigation.routes.first,
          const SectionRoute(AppSection.tasks),
        );
        expect(scene.navigation.currentRoute, isA<TaskRunRoute>());
      }
    },
  );

  test('test_start_and_open_run_property_a_person_who_moved_on_keeps_their_'
      'page', () async {
    final Random random = seededRandom(5312703);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final _WorkReviewScene scene = _openWorkReview(DraftKind.task);

      final List<AppRoute> wentTo = await _approveWhileMovingOn(
        random,
        scene,
        randomUnscheduledWork(random),
      );

      expect(scene.navigation.routes, wentTo);
      expect(scene.navigation.currentRoute, isNot(isA<TaskRunRoute>()));
    }
  });

  test('test_open_jobs_property_a_shown_review_lands_on_jobs', () async {
    final Random random = seededRandom(5312704);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final DraftKind kind = pickOne(random, workDraftKinds);
      final _WorkReviewScene scene = _openWorkReview(kind);

      await scene.review.approve(randomScheduledWork(random));

      expect(scene.navigation.routes, const <AppRoute>[
        SectionRoute(AppSection.jobs),
      ]);
    }
  });

  test('test_open_jobs_property_a_person_who_moved_on_stays', () async {
    final Random random = seededRandom(5312705);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final DraftKind kind = pickOne(random, workDraftKinds);
      final _WorkReviewScene scene = _openWorkReview(kind);

      final List<AppRoute> wentTo = await _approveWhileMovingOn(
        random,
        scene,
        randomScheduledWork(random),
      );

      expect(scene.navigation.routes, wentTo);
    }
  });

  test('test_open_jobs_property_a_late_approval_never_empties_the_'
      'window', () async {
    final Random random = seededRandom(5312706);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final DraftKind kind = pickOne(random, workDraftKinds);
      final _WorkReviewScene scene = _openWorkReview(kind);
      final Completer<void> hold = Completer<void>();
      scene.saveHold.hold = hold;

      final Future<void> approving = scene.review.approve(
        randomScheduledWork(random),
      );
      scene.navigation.closeRoute();
      hold.complete();

      await expectLater(approving, completes);
      expect(scene.navigation.routes, hasLength(1));
    }
  });
}
