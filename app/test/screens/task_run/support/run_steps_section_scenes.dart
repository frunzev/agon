import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_run/earlier_rounds_block.dart';
import 'package:agent_orchestration/screens/task_run/run_steps_section.dart';
import 'package:agent_orchestration/widgets/clickable.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../../support/random_inputs.dart';
import '../../../support/widget_harness.dart';
import 'random_shown_runs.dart';

const RunId sectionRunId = RunId('section-run');

final DeviceNames galleryDeviceNames = DeviceNames(galleryDevices);

typedef SectionInputs = ({Run run, Task task, Workflow? workflow});

SectionInputs randomSectionInputs(Random random) {
  final Workflow workflow = randomWorkflowWithAgents(random);
  final Task task = pickOne(random, galleryTasks);
  final List<RunStep> steps = randomStepsOfWorkflow(
    random,
    workflow: workflow,
    now: galleryNow,
  );
  final Run run = buildShownRun(
    random,
    runId: sectionRunId,
    taskId: task.id,
    steps: steps,
    now: galleryNow,
  );
  return (run: run, task: task, workflow: workflow);
}

RunStepsSection buildSection(SectionInputs inputs, {required Key key}) {
  return RunStepsSection(
    key: key,
    run: inputs.run,
    task: inputs.task,
    workflow: inputs.workflow,
    deviceNames: galleryDeviceNames,
    now: galleryNow,
  );
}

Future<void> pumpSection(
  WidgetTester tester, {
  required Random random,
  required Widget section,
}) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(tester, width: width, child: section);
}

List<ListRowData> readStepRows(WidgetTester tester) {
  final Finder lists = find.descendant(
    of: find.byType(RunStepsSection),
    matching: find.byType(ResponsiveList),
  );
  return tester.widget<ResponsiveList>(lists.first).rows;
}

ListRowMain readRowMain(ListRowData row) {
  final Widget main = row.main;
  if (main is ListRowMain) {
    return main;
  }
  final Column column = main as Column;
  return column.children.first as ListRowMain;
}

String joinSegments(List<TextSegment> segments) {
  final StringBuffer buffer = StringBuffer();
  for (final TextSegment segment in segments) {
    buffer.write(segment.text);
  }
  return buffer.toString();
}

List<String> readShownSubtitles(WidgetTester tester) {
  final List<String> subtitles = <String>[];
  for (final ListRowData row in readStepRows(tester)) {
    subtitles.add(joinSegments(readRowMain(row).subtitle));
  }
  return subtitles;
}

Finder findEarlierRoundsBlock(String stepName) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is EarlierRoundsBlock && widget.step.name == stepName,
  );
}

bool isShowingEarlierRounds(WidgetTester tester, String stepName) {
  final EarlierRoundsBlock block = tester.widget<EarlierRoundsBlock>(
    findEarlierRoundsBlock(stepName),
  );
  return block.isShown;
}

Map<String, bool> readShownRoundStates(WidgetTester tester) {
  final Map<String, bool> states = <String, bool>{};
  final Iterable<EarlierRoundsBlock> blocks = tester
      .widgetList<EarlierRoundsBlock>(find.byType(EarlierRoundsBlock));
  for (final EarlierRoundsBlock block in blocks) {
    states[block.step.name] = block.isShown;
  }
  return states;
}

Future<void> tapEarlierRoundsToggle(
  WidgetTester tester,
  String stepName,
) async {
  final Finder toggle = find
      .descendant(
        of: findEarlierRoundsBlock(stepName),
        matching: find.byType(Clickable),
      )
      .first;
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pump();
}

List<RunStep> listStepsWithRounds(Run run) {
  return <RunStep>[
    for (final RunStep step in run.steps)
      if (step.earlierRounds.isNotEmpty) step,
  ];
}

SectionInputs randomSectionInputsWithRounds(Random random) {
  while (true) {
    final SectionInputs inputs = randomSectionInputs(random);
    if (listStepsWithRounds(inputs.run).isNotEmpty) {
      return inputs;
    }
  }
}
