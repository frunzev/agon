import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/rules/task_branch.dart';

import '../../support/random_inputs.dart';

final RegExp _slugPattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
const TaskId _shipReleaseTaskId = TaskId(
  '9e07c0de-0000-4000-8000-000000000001',
);

TaskId _randomTaskId(Random random) {
  final String ending = random.nextInt(1 << 32).toRadixString(16);
  return TaskId('00000000-0000-4000-8000-${ending.padLeft(12, '0')}');
}

void main() {
  test('test_slugify_task_title_property_yields_idempotent_safe_slug', () {
    final Random random = seededRandom(31);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = random.nextBool()
          ? randomText(random)
          : randomWordPhrase(random);
      final String slug = slugifyTaskTitle(title);

      expect(_slugPattern.hasMatch(slug), isTrue, reason: title);
      expect(slugifyTaskTitle(slug), slug);
    }
  });

  test('test_describe_task_branch_property_prefixes_slug', () {
    final Random random = seededRandom(32);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = randomWordPhrase(random);
      final TaskId taskId = _randomTaskId(random);
      final String simpleTaskId = taskId.value.replaceAll('-', '');

      expect(
        describeTaskBranch(title: title, taskId: taskId),
        'task/${slugifyTaskTitle(title)}-$simpleTaskId',
      );
    }
  });

  test('test_describe_job_run_branch_property_ends_with_run_number', () {
    final Random random = seededRandom(33);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = randomWordPhrase(random);
      final TaskId taskId = _randomTaskId(random);
      final int runNumber = 1 + random.nextInt(5000);
      final String branch = describeJobRunBranch(
        title: title,
        taskId: taskId,
        runNumber: runNumber,
      );

      expect(
        branch,
        startsWith(describeTaskBranch(title: title, taskId: taskId)),
      );
      expect(branch, endsWith('-run-$runNumber'));
    }
  });

  test('describe_task_branch matches the gallery run', () {
    expect(
      describeTaskBranch(
        title: 'Ship release 2.4',
        taskId: _shipReleaseTaskId,
      ),
      'task/ship-release-2-4-9e07c0de000040008000000000000001',
    );
  });
}
