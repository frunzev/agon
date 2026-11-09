import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/work_draft_review.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import '../tasks/start_refusing_task_repository.dart';
import 'work_draft_support.dart';

typedef _OpenRunScene = ({
  StartRefusingTaskRepository tasks,
  AppNavigation navigation,
  WorkDraftReview review,
});

_OpenRunScene _setUp() {
  final StartRefusingTaskRepository tasks = StartRefusingTaskRepository(
    buildGalleryDependencies().taskRepository,
  );
  final AppDependencies dependencies = replaceRepositories(
    buildGalleryDependencies(),
    taskRepository: tasks,
  );
  final AppNavigation navigation = openWorkNavigation(DraftKind.task);
  return (
    tasks: tasks,
    navigation: navigation,
    review: buildRecordingWorkReview(
      kind: DraftKind.task,
      dependencies: dependencies,
      navigation: navigation,
      chosenTargets: <RunnerTarget>[],
    ),
  );
}

Future<Object?> _catchProblem(Future<void> Function() action) async {
  try {
    await action();
  } on Object catch (problem) {
    return problem;
  }
  return null;
}

void main() {
  test('test_start_and_open_run_property_opens_the_run_in_place', () async {
    final Random random = seededRandom(54401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _OpenRunScene scene = _setUp();
      final int depthBefore = scene.navigation.routes.length;

      await scene.review.approve(randomUnscheduledWork(random));

      final TaskId createdId = scene.tasks.createdTasks.single.id;
      expect(scene.navigation.routes.length, depthBefore);
      final AppRoute shown = scene.navigation.currentRoute;
      expect(shown, isA<TaskRunRoute>());
      final Run run = scene.tasks.findRun((shown as TaskRunRoute).runId);
      expect(run.taskId, createdId);
    }
  });

  test(
    'test_start_and_open_run_property_finish_retries_the_same_task',
    () async {
      final Random random = seededRandom(54402);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _OpenRunScene scene = _setUp();
        scene.tasks.startProblem = randomExplainedRefusal(random).problem;
        final List<AppRoute> routesBefore = scene.navigation.routes;

        final Object? first = await _catchProblem(
          () => scene.review.approve(randomUnscheduledWork(random)),
        );
        final Object? second = await _catchProblem(
          (first! as UnfinishedApproval).finishApproval,
        );

        final TaskId createdId = scene.tasks.createdTasks.single.id;
        expect(second, isA<UnfinishedApproval>());
        expect(scene.tasks.startAttempts, <TaskId>[createdId, createdId]);
        expect(scene.navigation.routes, routesBefore);
      }
    },
  );

  test(
    'test_start_and_open_run_property_unexplained_is_not_wrapped',
    () async {
      final Random random = seededRandom(54403);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _OpenRunScene scene = _setUp();
        scene.tasks.startProblem = randomExplainedRefusal(random).problem;
        final Object? first = await _catchProblem(
          () => scene.review.approve(randomUnscheduledWork(random)),
        );
        final FormatException unexplained = randomUnexplainedProblem(random);
        scene.tasks.startProblem = unexplained;

        final Object? second = await _catchProblem(
          (first! as UnfinishedApproval).finishApproval,
        );

        expect(second, same(unexplained));
        expect(scene.tasks.createdTasks, hasLength(1));
      }
    },
  );
}
