import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../../support/random_branching_workflows.dart';
import '../../../support/random_inputs.dart';
import '../../../support/widget_harness.dart';
import '../../support/random_page_windows.dart';

typedef BuildStepWidget = Widget Function(StepPanelHost host, Workflow shown);

final class StepPanelHost {
  StepPanelHost({required Workflow workflow, required WorkflowAgent agent})
    : _workflow = workflow,
      shownAgent = ValueNotifier<WorkflowAgent>(agent);

  final Workflow _workflow;
  final ValueNotifier<WorkflowAgent> shownAgent;
  final List<WorkflowAgent> changes = <WorkflowAgent>[];
  final TapCounter removals = TapCounter();
  final TapCounter dones = TapCounter();

  Workflow readShownWorkflow() {
    return replaceAgent(_workflow, shownAgent.value);
  }

  void changeAgent(WorkflowAgent agent) {
    changes.add(agent);
    shownAgent.value = agent;
  }

  Widget build({required Key key, required BuildStepWidget buildStep}) {
    return ValueListenableBuilder<WorkflowAgent>(
      valueListenable: shownAgent,
      builder: (BuildContext _, WorkflowAgent agent, Widget? _) =>
          KeyedSubtree(key: key, child: buildStep(this, readShownWorkflow())),
    );
  }
}

Widget buildShownPersonPanel(StepPanelHost host, Workflow shown) {
  return PersonStepPanel(
    workflow: shown,
    agent: host.shownAgent.value,
    onAgentChanged: host.changeAgent,
    onRemoved: host.removals.countTap,
    onDone: host.dones.countTap,
  );
}

Widget buildShownNameField(StepPanelHost host, Workflow shown) {
  return StepNameField(
    workflow: shown,
    agent: host.shownAgent.value,
    onAgentChanged: host.changeAgent,
  );
}

({Workflow workflow, WorkflowAgent step}) randomPersonStepScene(
  Random random,
) {
  final Workflow workflow = randomBranchingWorkflow(random);
  final WorkflowAgent blank = buildBlankPersonStep(workflow);
  final WorkflowAgent step = blank.copyWith(task: randomText(random));
  return (workflow: addAgent(workflow, step), step: step);
}

double randomStepPanelWidth(Random random) {
  return randomWidth(random, least: narrowestWidth, most: widestWidth);
}

Future<StepPanelHost> pumpStepHost(
  WidgetTester tester, {
  required Workflow workflow,
  required WorkflowAgent agent,
  required BuildStepWidget buildStep,
  required double width,
}) async {
  final StepPanelHost host = StepPanelHost(workflow: workflow, agent: agent);
  addTearDown(host.shownAgent.dispose);
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: host.build(key: UniqueKey(), buildStep: buildStep),
  );
  return host;
}
