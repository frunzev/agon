import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/run_text.dart';

import '../support/random_inputs.dart';

const List<StepStatus> _currentStatuses = <StepStatus>[
  StepStatus.running,
  StepStatus.waitingForApproval,
  StepStatus.waitingForPerson,
  StepStatus.failed,
];
const List<RunStatus> _shownProgressStatuses = <RunStatus>[
  RunStatus.queued,
  RunStatus.running,
  RunStatus.waitingForApproval,
  RunStatus.failed,
];
const int _largestStepCount = 8;
final RegExp _progressPattern = RegExp(r'^step (\d+) of (\d+)$');

Run _runWithSteps(
  Random random, {
  required RunStatus status,
  required List<StepStatus> stepStatuses,
}) {
  final Run base = pickOne(random, galleryRuns);
  final RunStep template = base.steps.first;
  return base.withProgress(
    nextStatus: status,
    nextSteps: <RunStep>[
      for (final StepStatus stepStatus in stepStatuses)
        template.withStatus(stepStatus),
    ],
    nextFinishedAt: base.finishedAt,
  );
}

List<StepStatus> _randomStepStatuses(Random random, int count) {
  return <StepStatus>[
    for (int i = 0; i < count; i += 1) pickOne(random, StepStatus.values),
  ];
}

Run _withNumber(Run base, int number) {
  return Run(
    id: base.id,
    taskId: base.taskId,
    number: number,
    status: base.status,
    steps: base.steps,
    log: base.log,
    chat: base.chat,
    failure: base.failure,
    link: base.link,
    linkLostAt: base.linkLostAt,
    agentSession: base.agentSession,
    worktreeBranch: base.worktreeBranch,
    startedBy: base.startedBy,
    startedAt: base.startedAt,
    finishedAt: base.finishedAt,
    loopRounds: base.loopRounds,
    notes: base.notes,
  );
}

void main() {
  test('test_find_current_step_property_runs_without_steps_are_refused', () {
    final Random random = seededRandom(930501);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _runWithSteps(
        random,
        status: pickOne(random, RunStatus.values),
        stepStatuses: const <StepStatus>[],
      );

      expect(() => findCurrentStep(run), throwsStateError);
    }
  });

  test('test_find_current_step_property_first_open_step_is_current', () {
    final Random random = seededRandom(930502);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int doneCount = random.nextInt(_largestStepCount);
      final List<StepStatus> statuses = <StepStatus>[
        for (int index = 0; index < doneCount; index += 1) StepStatus.done,
        pickOne(random, _currentStatuses),
        ..._randomStepStatuses(random, random.nextInt(_largestStepCount)),
      ];
      final Run run = _runWithSteps(
        random,
        status: pickOne(random, RunStatus.values),
        stepStatuses: statuses,
      );

      expect(findCurrentStep(run), same(run.steps[doneCount]));
    }
  });

  test('test_describe_step_progress_property_counts_to_the_open_step', () {
    final Random random = seededRandom(930503);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int doneCount = random.nextInt(_largestStepCount);
      final int waitingCount = 1 + random.nextInt(_largestStepCount);
      final Run run = _runWithSteps(
        random,
        status: pickOne(random, _shownProgressStatuses),
        stepStatuses: <StepStatus>[
          for (int index = 0; index < doneCount; index += 1) StepStatus.done,
          pickOne(random, _currentStatuses),
          for (int index = 0; index < waitingCount; index += 1)
            StepStatus.waiting,
        ],
      );

      expect(
        describeStepProgress(run),
        'step ${doneCount + 1} of ${run.steps.length}',
      );
    }
  });

  test(
    'test_describe_step_progress_property_hidden_when_nothing_to_count',
    () {
      final Random random = seededRandom(930504);
      for (int i = 0; i < propertyIterations; i += 1) {
        final bool isSingleStep = random.nextBool();
        final Run run = _runWithSteps(
          random,
          status: isSingleStep
              ? pickOne(random, RunStatus.values)
              : pickOne(random, <RunStatus>[
                  RunStatus.done,
                  RunStatus.cancelled,
                ]),
          stepStatuses: _randomStepStatuses(
            random,
            isSingleStep ? 1 : 1 + random.nextInt(_largestStepCount),
          ),
        );

        expect(describeStepProgress(run), isNull);
      }
    },
  );

  test('test_describe_step_progress_property_total_is_the_step_count', () {
    final Random random = seededRandom(930505);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int stepCount = 2 + random.nextInt(_largestStepCount);
      final Run run = _runWithSteps(
        random,
        status: pickOne(random, _shownProgressStatuses),
        stepStatuses: _randomStepStatuses(random, stepCount),
      );

      final RegExpMatch match = _progressPattern.firstMatch(
        describeStepProgress(run)!,
      )!;

      final int position = int.parse(match.group(1)!);
      expect(int.parse(match.group(2)!), stepCount);
      expect(position, inInclusiveRange(1, stepCount));
    }
  });

  test('test_describe_run_label_property_workflow_name_or_task_title', () {
    final Random random = seededRandom(930506);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = pickOne(random, galleryTasks);
      final Run run = pickOne(random, galleryRuns);
      final Workflow workflow = pickOne(random, galleryWorkflows);

      expect(
        describeRunLabel(task: task, workflow: workflow, run: run),
        '${workflow.name} #${run.number}',
      );
      expect(
        describeRunLabel(task: task, workflow: null, run: run),
        '${task.title} #${run.number}',
      );
    }
  });

  test('test_describe_run_label_property_number_is_plain_decimal', () {
    final Random random = seededRandom(930507);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int number = 1 + random.nextInt(1 << 31);
      final Run run = _withNumber(pickOne(random, galleryRuns), number);

      final String label = describeRunLabel(
        task: pickOne(random, galleryTasks),
        workflow: null,
        run: run,
      );

      expect(label, endsWith(' #$number'));
      expect(label.split('#').last, number.toString());
    }
  });

  test('test_describe_run_label_property_ignores_run_progress', () {
    final Random random = seededRandom(930508);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = pickOne(random, galleryTasks);
      final Workflow? workflow = random.nextBool()
          ? pickOne(random, galleryWorkflows)
          : null;
      final Run run = pickOne(random, galleryRuns);
      final Run progressed = _runWithSteps(
        random,
        status: pickOne(random, RunStatus.values),
        stepStatuses: _randomStepStatuses(random, 1 + random.nextInt(4)),
      );
      final Run sameNumber = _withNumber(progressed, run.number);

      expect(
        describeRunLabel(task: task, workflow: workflow, run: sameNumber),
        describeRunLabel(task: task, workflow: workflow, run: run),
      );
    }
  });
}
