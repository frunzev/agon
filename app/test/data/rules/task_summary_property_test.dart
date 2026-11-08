import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/task_summary.dart';

import '../../support/random_inputs.dart';
import 'support/task_rule_tables.dart';

const String _partSeparator = ' · ';
const List<String> _phrasesInOrder = <String>[
  'running',
  'waiting for approval',
  'failed',
  'to do',
];
const int _largestTaskCount = 14;
const int _largestAddedDoneCount = 6;

List<Task> _buildTasks(Random random, List<TaskStatus> statuses) {
  return <Task>[
    for (final TaskStatus status in statuses)
      pickOne(random, galleryTasks).withStatus(status),
  ];
}

List<TaskStatus> _randomStatuses(Random random) {
  final int count = random.nextInt(_largestTaskCount);
  return <TaskStatus>[
    for (int i = 0; i < count; i += 1) pickOne(random, TaskStatus.values),
  ];
}

int _findPhrasePosition(String part) {
  for (int position = 0; position < _phrasesInOrder.length; position += 1) {
    if (part.endsWith(' ${_phrasesInOrder[position]}')) {
      return position;
    }
  }
  throw StateError('the summary part "$part" names no status');
}

void main() {
  final List<SharedSummaryCase> sharedCases = readSharedSummaryCases();

  test('test_describe_task_summary_property_agrees_with_the_shared_table', () {
    final Random random = seededRandom(48911);

    for (final SharedSummaryCase sharedCase in sharedCases) {
      final List<Task> tasks = _buildTasks(random, sharedCase.statuses);

      expect(
        describeTaskSummary(tasks),
        sharedCase.text,
        reason: '${sharedCase.statuses}',
      );
    }
  });

  test('test_describe_task_summary_property_ignores_the_task_order', () {
    final Random random = seededRandom(48912);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Task> tasks = _buildTasks(random, _randomStatuses(random));
      final List<Task> shuffled = List<Task>.of(tasks);
      shuffled.shuffle(random);

      expect(describeTaskSummary(shuffled), describeTaskSummary(tasks));
    }
  });

  test('test_describe_task_summary_property_done_tasks_keep_the_text', () {
    final Random random = seededRandom(48913);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<TaskStatus> statuses = _randomStatuses(random);
      final int addedDoneCount = 1 + random.nextInt(_largestAddedDoneCount);
      final List<TaskStatus> grown = <TaskStatus>[
        ...statuses,
        for (int j = 0; j < addedDoneCount; j += 1) TaskStatus.done,
      ];
      final String before = describeTaskSummary(_buildTasks(random, statuses));

      final String after = describeTaskSummary(_buildTasks(random, grown));

      final String expected = statuses.isEmpty ? 'All done' : before;
      expect(after, expected, reason: '$statuses');
    }
  });

  test('test_describe_task_summary_property_parts_follow_a_fixed_order', () {
    final Random random = seededRandom(48914);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<TaskStatus> statuses = _randomStatuses(random);
      final bool hasUnfinished = statuses.any(
        (TaskStatus status) => status != TaskStatus.done,
      );
      if (!hasUnfinished) {
        continue;
      }

      final String summary = describeTaskSummary(
        _buildTasks(random, statuses),
      );

      final List<int> positions = <int>[
        for (final String part in summary.split(_partSeparator))
          _findPhrasePosition(part),
      ];
      final List<int> sortedPositions = List<int>.of(positions);
      sortedPositions.sort();
      expect(positions, sortedPositions, reason: summary);
      expect(positions.toSet(), hasLength(positions.length), reason: summary);
    }
  });
}
