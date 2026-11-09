import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/tasks/created_task_start.dart';

import '../../support/random_inputs.dart';
import '../../support/task_repositories.dart';
import '../support/planned_refusal.dart';
import '../new_items/work_draft_support.dart';
import 'start_refusing_task_repository.dart';

StartRefusingTaskRepository _buildRepository() {
  return StartRefusingTaskRepository(buildGalleryTaskRepository());
}

void main() {
  test('test_start_created_task_property_starts_exactly_that_task', () async {
    final Random random = seededRandom(53401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final StartRefusingTaskRepository repository = _buildRepository();
      final Task task = await repository.createTask(
        randomUnscheduledWork(random).toTaskDraft(),
      );

      final Run run = await startCreatedTask(
        taskRepository: repository,
        taskId: task.id,
      );

      expect(run.taskId, task.id);
      expect(repository.startAttempts, <TaskId>[task.id]);
      expect(repository.findRun(run.id).id, run.id);
    }
  });

  test(
    'test_start_created_task_property_explained_problem_says_created',
    () async {
      final Random random = seededRandom(53402);

      for (int i = 0; i < propertyIterations; i += 1) {
        final StartRefusingTaskRepository repository = _buildRepository();
        final ExplainedRefusal refusal = randomExplainedRefusal(random);
        repository.startProblem = refusal.problem;
        final Task task = pickOne(random, galleryTasks);

        final Future<Run> start = startCreatedTask(
          taskRepository: repository,
          taskId: task.id,
        );

        await expectLater(
          start,
          throwsA(
            isA<PeopleFacingRefusal>().having(
              describeProblemForPeople,
              'explanation',
              '$createdTaskNotStartedPrefix${refusal.explanation}',
            ),
          ),
        );
      }
    },
  );

  test(
    'test_start_created_task_property_unexplained_problem_passes',
    () async {
      final Random random = seededRandom(53403);

      for (int i = 0; i < propertyIterations; i += 1) {
        final StartRefusingTaskRepository repository = _buildRepository();
        final FormatException problem = randomUnexplainedProblem(random);
        repository.startProblem = problem;

        final Future<Run> start = startCreatedTask(
          taskRepository: repository,
          taskId: pickOne(random, galleryTasks).id,
        );

        await expectLater(start, throwsA(same(problem)));
      }
    },
  );
}
