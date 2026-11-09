import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/kept_branches.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/runner_target_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/shared/status_labels.dart';
import 'package:agent_orchestration/screens/tasks/task_row.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../task_run/support/random_shown_runs.dart';
import 'random_listed_tasks.dart';

final DeviceNames _deviceNames = DeviceNames(galleryDevices);
final RegExp _stepProgress = RegExp(r' · step (\d+) of (\d+)$');

typedef _RowInputs = ({Task task, Run? run});

_RowInputs _randomInputs(Random random) {
  final Task task = randomListedTask(random, random.nextInt(100));
  final Run? run = random.nextInt(3) == 0
      ? null
      : randomListedRun(random, task, 0);
  return (task: task, run: run);
}

List<KeptBranch> _randomKeptBranches(Random random) {
  final int count = random.nextInt(3);
  return <KeptBranch>[
    for (int index = 0; index < count; index += 1)
      KeptBranch(
        repositoryAddress: 'github.com/acme/repo-$index',
        branch: 'task/kept-$index',
        runner: pickOne(random, shownRunners),
      ),
  ];
}

List<(String, TextFace)> _describeSegments(List<TextSegment> segments) {
  return <(String, TextFace)>[
    for (final TextSegment segment in segments) (segment.text, segment.face),
  ];
}

String _joinSegments(List<TextSegment> segments) {
  return <String>[for (final TextSegment segment in segments) segment.text]
      .join();
}

void main() {
  test('test_describe_task_runs_on_property_current_runner_in_monospace', () {
    final Random random = seededRandom(116101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RowInputs inputs = _randomInputs(random);
      final Run? run = inputs.run;
      final DeviceId? runner = run == null
          ? null
          : findCurrentStep(run).runner;
      if (runner == null) {
        continue;
      }

      final List<TextSegment> segments = describeTaskRunsOn(
        task: inputs.task,
        latestRun: run,
        deviceNames: _deviceNames,
      );

      expect(_describeSegments(segments), <(String, TextFace)>[
        (_deviceNames.describeDevice(runner), TextFace.monospace),
      ]);
    }
  });

  test('test_describe_task_runs_on_property_no_runner_reads_the_target', () {
    final Random random = seededRandom(116102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RowInputs inputs = _randomInputs(random);
      final Run? run = inputs.run;
      final DeviceId? runner = run == null
          ? null
          : findCurrentStep(run).runner;
      if (runner != null) {
        continue;
      }

      final List<TextSegment> segments = describeTaskRunsOn(
        task: inputs.task,
        latestRun: run,
        deviceNames: _deviceNames,
      );

      expect(
        _describeSegments(segments),
        _describeSegments(
          describeRunnerTarget(inputs.task.runsOn, _deviceNames),
        ),
      );
    }
  });

  test('test_describe_task_subtitle_property_progress_within_bounds', () {
    final Random random = seededRandom(116103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RowInputs inputs = _randomInputs(random);
      final Run? run = inputs.run;

      final String subtitle = describeTaskSubtitle(
        projectName: randomHostileText(random),
        doerLabel: randomWordPhrase(random),
        latestRun: run,
      );

      final RegExpMatch? match = _stepProgress.firstMatch(subtitle);
      final bool showsProgress =
          run != null &&
          run.steps.length > 1 &&
          (isRunActive(run) || run.status == RunStatus.failed);
      expect(match != null, showsProgress, reason: subtitle);
      if (match != null) {
        final int position = int.parse(match.group(1)!);
        final int total = int.parse(match.group(2)!);
        expect(total, run!.steps.length);
        expect(position, inInclusiveRange(1, total));
      }
    }
  });

  test('test_describe_task_subtitle_property_joins_parts_in_order', () {
    final Random random = seededRandom(116104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RowInputs inputs = _randomInputs(random);
      final Run? run = inputs.run;
      final String project = randomHostileText(random);
      final String doer = randomHostileText(random);

      final String subtitle = describeTaskSubtitle(
        projectName: project,
        doerLabel: doer,
        latestRun: run,
      );

      final String? progress = run == null ? null : describeStepProgress(run);
      final String expectedEnd = progress == null ? '' : ' · $progress';
      expect(subtitle, '$project · $doer$expectedEnd');
    }
  });

  test('test_build_task_row_property_cells_follow_task_and_run', () {
    final Random random = seededRandom(116105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RowInputs inputs = _randomInputs(random);
      final List<KeptBranch> keptBranches = _randomKeptBranches(random);

      final ListRowData row = buildTaskRow(
        task: inputs.task,
        latestRun: inputs.run,
        projectName: 'project',
        doerLabel: 'doer',
        keptBranches: keptBranches,
        deviceNames: _deviceNames,
        now: galleryNow,
        onTap: () {},
      );

      final Run? run = inputs.run;
      final Text started = row.meta[1] as Text;
      expect(
        started.data,
        run == null ? 'Not yet' : describeTimeSince(run.startedAt, galleryNow),
      );
      final StatusLabel end = row.end! as StatusLabel;
      final String expectedStatus = keptBranches.isEmpty
          ? buildTaskStatusLabel(inputs.task.status).text
          : 'Not pushed';
      expect(end.text, expectedStatus);
      final MixedText runsOn = row.meta[0] as MixedText;
      expect(
        _joinSegments(runsOn.segments),
        _joinSegments(
          describeTaskRunsOn(
            task: inputs.task,
            latestRun: run,
            deviceNames: _deviceNames,
          ),
        ),
      );
    }
  });

  test('test_build_task_row_property_main_names_task_and_taps_once', () {
    final Random random = seededRandom(116106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RowInputs inputs = _randomInputs(random);
      int taps = 0;

      final ListRowData row = buildTaskRow(
        task: inputs.task,
        latestRun: inputs.run,
        projectName: 'project $i',
        doerLabel: 'doer',
        keptBranches: const <KeptBranch>[],
        deviceNames: _deviceNames,
        now: galleryNow,
        onTap: () => taps += 1,
      );
      row.onTap!();

      expect(taps, 1);
      final ListRowMain main = row.main as ListRowMain;
      expect(main.title, inputs.task.title);
      expect(
        _joinSegments(main.subtitle),
        describeTaskSubtitle(
          projectName: 'project $i',
          doerLabel: 'doer',
          latestRun: inputs.run,
        ),
      );
      expect(row.key, ValueKey<TaskId>(inputs.task.id));
    }
  });
}
