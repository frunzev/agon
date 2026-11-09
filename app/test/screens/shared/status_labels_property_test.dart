import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/kept_branches.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/shared/status_labels.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/random_inputs.dart';

const Map<TaskStatus, String> _taskWords = <TaskStatus, String>{
  TaskStatus.toDo: 'To do',
  TaskStatus.running: 'Running',
  TaskStatus.waitingForApproval: 'Waiting for approval',
  TaskStatus.failed: 'Failed',
  TaskStatus.done: 'Done',
};

const Map<StepStatus, String> _stepWords = <StepStatus, String>{
  StepStatus.waiting: 'Next',
  StepStatus.running: 'Running',
  StepStatus.waitingForApproval: 'Waiting for approval',
  StepStatus.waitingForPerson: 'Waiting for you',
  StepStatus.done: 'Done',
  StepStatus.failed: 'Failed',
  StepStatus.skipped: 'Skipped',
};

const Set<StatusTone> _quietTones = <StatusTone>{
  StatusTone.muted,
  StatusTone.normal,
};

typedef _LabelReading = ({String text, StatusTone tone, AppIconKind? icon});

_LabelReading _read(StatusLabel label) {
  return (text: label.text, tone: label.tone, icon: label.icon);
}

List<KeptBranch> _randomKeptBranches(Random random) {
  final int count = random.nextInt(3);
  return <KeptBranch>[
    for (int index = 0; index < count; index += 1)
      KeptBranch(
        repositoryAddress: 'github.com/acme/repo-$index',
        branch: 'task/kept-${random.nextInt(1000)}',
        runner: DeviceId('runner-$index'),
      ),
  ];
}

void _expectDistinctTexts(List<StatusLabel> labels) {
  final Set<String> texts = <String>{
    for (final StatusLabel label in labels) label.text,
  };
  expect(texts, hasLength(labels.length));
}

void main() {
  test('test_build_task_status_label_property_every_status_has_its_words', () {
    for (final TaskStatus status in TaskStatus.values) {
      expect(buildTaskStatusLabel(status).text, _taskWords[status]);
    }
    _expectDistinctTexts(<StatusLabel>[
      for (final TaskStatus status in TaskStatus.values)
        buildTaskStatusLabel(status),
    ]);
  });

  test('test_build_task_status_label_property_tone_follows_need', () {
    for (final TaskStatus status in TaskStatus.values) {
      final StatusTone tone = buildTaskStatusLabel(status).tone;
      switch (status) {
        case TaskStatus.failed:
          expect(tone, StatusTone.danger);
        case TaskStatus.waitingForApproval:
          expect(tone, StatusTone.attention);
        case TaskStatus.toDo:
        case TaskStatus.running:
        case TaskStatus.done:
          expect(_quietTones, contains(tone));
      }
    }
  });

  test('test_build_task_status_label_property_same_status_same_label', () {
    final Random random = seededRandom(112003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskStatus status = pickOne(random, TaskStatus.values);

      expect(
        _read(buildTaskStatusLabel(status)),
        _read(buildTaskStatusLabel(status)),
      );
      expect(buildTaskStatusLabel(status).icon, isNotNull);
    }
  });

  test('test_build_task_outcome_label_property_no_kept_work_is_status', () {
    final Random random = seededRandom(112004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskStatus status = pickOne(random, TaskStatus.values);

      final StatusLabel label = buildTaskOutcomeLabel(
        status: status,
        keptBranches: const <KeptBranch>[],
      );

      expect(_read(label), _read(buildTaskStatusLabel(status)));
    }
  });

  test('test_build_task_outcome_label_property_kept_work_ignores_status', () {
    final Random random = seededRandom(112005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<KeptBranch> keptBranches = _randomKeptBranches(random);
      if (keptBranches.isEmpty) {
        continue;
      }
      final TaskStatus first = pickOne(random, TaskStatus.values);
      final TaskStatus second = pickOne(random, TaskStatus.values);

      final StatusLabel firstLabel = buildTaskOutcomeLabel(
        status: first,
        keptBranches: keptBranches,
      );
      final StatusLabel secondLabel = buildTaskOutcomeLabel(
        status: second,
        keptBranches: keptBranches,
      );

      expect(_read(firstLabel), _read(secondLabel));
      expect(firstLabel.text, 'Not pushed');
    }
  });

  test('test_build_task_outcome_label_property_not_pushed_is_no_status', () {
    final List<String> statusTexts = <String>[
      for (final TaskStatus status in TaskStatus.values)
        buildTaskStatusLabel(status).text,
    ];
    final Random random = seededRandom(112006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<KeptBranch> keptBranches = _randomKeptBranches(random);

      final StatusLabel label = buildTaskOutcomeLabel(
        status: pickOne(random, TaskStatus.values),
        keptBranches: keptBranches,
      );

      expect(statusTexts.contains(label.text), keptBranches.isEmpty);
      if (keptBranches.isNotEmpty) {
        expect(label.tone, isNot(StatusTone.danger));
      }
    }
  });

  test('test_build_job_last_run_label_property_live_states_match_tasks', () {
    for (final TaskStatus status in <TaskStatus>[
      TaskStatus.running,
      TaskStatus.waitingForApproval,
      TaskStatus.failed,
    ]) {
      expect(
        _read(buildJobLastRunLabel(status)),
        _read(buildTaskStatusLabel(status)),
      );
    }
  });

  test('test_build_job_last_run_label_property_total_and_distinct', () {
    final List<StatusLabel> labels = <StatusLabel>[
      for (final TaskStatus status in TaskStatus.values)
        buildJobLastRunLabel(status),
    ];

    _expectDistinctTexts(labels);
    expect(buildJobLastRunLabel(TaskStatus.toDo).text, 'Not run yet');
    expect(buildJobLastRunLabel(TaskStatus.done).text, 'Passed');
  });

  test('test_build_job_last_run_label_property_only_failure_is_danger', () {
    for (final TaskStatus status in TaskStatus.values) {
      final bool isDanger =
          buildJobLastRunLabel(status).tone == StatusTone.danger;

      expect(isDanger, status == TaskStatus.failed);
    }
  });

  test('test_build_step_status_label_property_every_status_has_words', () {
    for (final StepStatus status in StepStatus.values) {
      expect(buildStepStatusLabel(status).text, _stepWords[status]);
    }
    _expectDistinctTexts(<StatusLabel>[
      for (final StepStatus status in StepStatus.values)
        buildStepStatusLabel(status),
    ]);
  });

  test('test_build_step_status_label_property_waiting_asks_attention', () {
    for (final StepStatus status in StepStatus.values) {
      final StatusTone tone = buildStepStatusLabel(status).tone;
      final bool isWaitingOnSomeone =
          status == StepStatus.waitingForApproval ||
          status == StepStatus.waitingForPerson;

      expect(tone == StatusTone.attention, isWaitingOnSomeone);
      expect(tone == StatusTone.danger, status == StepStatus.failed);
    }
  });

  test('test_build_step_status_label_property_agrees_with_task_words', () {
    final Map<StepStatus, TaskStatus> twins = <StepStatus, TaskStatus>{
      StepStatus.running: TaskStatus.running,
      StepStatus.waitingForApproval: TaskStatus.waitingForApproval,
      StepStatus.done: TaskStatus.done,
      StepStatus.failed: TaskStatus.failed,
    };

    for (final MapEntry<StepStatus, TaskStatus> twin in twins.entries) {
      expect(
        _read(buildStepStatusLabel(twin.key)),
        _read(buildTaskStatusLabel(twin.value)),
      );
    }
  });
}
