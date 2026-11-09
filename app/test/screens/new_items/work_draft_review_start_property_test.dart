import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/work_draft_review.dart';
import 'package:agent_orchestration/screens/tasks/created_task_start.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import '../tasks/start_refusing_task_repository.dart';
import 'work_draft_support.dart';

typedef _StartScene = ({
  StartRefusingTaskRepository tasks,
  AppNavigation navigation,
  WorkDraftReview review,
  List<AppRoute> routesBefore,
});

_StartScene _setUpStart() {
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
    routesBefore: navigation.routes,
  );
}

Future<UnfinishedApproval> _catchUnfinished(
  Future<void> Function() approval,
) async {
  try {
    await approval();
  } on Object catch (problem) {
    if (problem is UnfinishedApproval) {
      return problem;
    }
    rethrow;
  }
  throw StateError('The approval finished');
}

Future<UnfinishedApproval> _approveExpectingUnfinished(
  _StartScene scene,
  DraftedWork work,
) {
  return _catchUnfinished(() => scene.review.approve(work));
}

void main() {
  test(
    'test_work_draft_review_approve_property_start_refusal_unfinished',
    () async {
      final Random random = seededRandom(53601);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _StartScene scene = _setUpStart();
        final ExplainedRefusal refusal = randomExplainedRefusal(random);
        scene.tasks.startProblem = refusal.problem;

        final UnfinishedApproval unfinished =
            await _approveExpectingUnfinished(
              scene,
              randomUnscheduledWork(random),
            );

        expect(
          unfinished.message,
          '$createdTaskNotStartedPrefix${refusal.explanation}',
        );
        expect(scene.tasks.createdTasks, hasLength(1));
        expect(scene.tasks.startAttempts, <TaskId>[
          scene.tasks.createdTasks.single.id,
        ]);
        expect(scene.navigation.routes, scene.routesBefore);
      }
    },
  );

  test(
    'test_work_draft_review_approve_property_finish_never_creates',
    () async {
      final Random random = seededRandom(53602);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _StartScene scene = _setUpStart();
        scene.tasks.startProblem = randomExplainedRefusal(random).problem;
        UnfinishedApproval unfinished = await _approveExpectingUnfinished(
          scene,
          randomUnscheduledWork(random),
        );
        final int refusedFinishCount = random.nextInt(3);
        for (int refused = 0; refused < refusedFinishCount; refused += 1) {
          unfinished = await _catchUnfinished(unfinished.finishApproval);
        }
        scene.tasks.startProblem = null;

        await unfinished.finishApproval();

        final List<TaskId> createdIds = <TaskId>[
          for (final Task task in scene.tasks.createdTasks) task.id,
        ];
        expect(createdIds, hasLength(1));
        expect(scene.tasks.startAttempts, <TaskId>[
          for (int attempt = 0; attempt < refusedFinishCount + 2; attempt += 1)
            createdIds.single,
        ]);
        final AppRoute shown = scene.navigation.currentRoute;
        expect(shown, isA<TaskRunRoute>());
        final Run run = scene.tasks.findRun((shown as TaskRunRoute).runId);
        expect(run.taskId, createdIds.single);
      }
    },
  );

  test('test_work_draft_review_approve_property_unexplained_passes', () async {
    final Random random = seededRandom(53603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _StartScene scene = _setUpStart();
      final FormatException problem = randomUnexplainedProblem(random);
      scene.tasks.startProblem = problem;

      final Future<void> approving = scene.review.approve(
        randomUnscheduledWork(random),
      );

      await expectLater(approving, throwsA(same(problem)));
      expect(scene.tasks.createdTasks, hasLength(1));
      expect(scene.navigation.routes, scene.routesBefore);
    }
  });
}
