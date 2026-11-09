import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/runner_choices.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_workflows.dart';
import '../support/random_page_windows.dart';
import '../task_form/task_form_scene.dart';

const String agentSettingsTitle = 'Agent settings';
const String skillsFieldLabel = 'Skills to use';
const String taskFieldLabel = 'Task';
const String automaticSkillsLabel = 'Also let the agent pick automatic skills';
const String removeAgentLabel = 'Remove agent';
const String doneLabel = 'Done';

final class AgentSettingsScene {
  AgentSettingsScene({required WorkflowAgent agent, required this.canFillIn})
    : shownAgent = ValueNotifier<WorkflowAgent>(agent);

  final ValueNotifier<WorkflowAgent> shownAgent;
  final bool canFillIn;
  final List<WorkflowAgent> changes = <WorkflowAgent>[];
  final TapCounter removals = TapCounter();
  final TapCounter dones = TapCounter();
  final TapCounter fillIns = TapCounter();

  void changeAgent(WorkflowAgent agent) {
    changes.add(agent);
    shownAgent.value = agent;
  }

  Widget buildPanel(Random random) {
    final List<Runner> runners = randomRunnersOnDistinctDevices(random);
    return ValueListenableBuilder<WorkflowAgent>(
      valueListenable: shownAgent,
      builder: (BuildContext _, WorkflowAgent agent, Widget? _) =>
          AgentSettingsPanel(
            workflow: _buildWorkflowAround(agent),
            agent: agent,
            runnerOptions: buildRunnerOptions(
              runners: runners,
              deviceNames: DeviceNames(galleryDevices),
              chosenTarget: agent.runsOn,
            ),
            skills: gallerySkills,
            onAgentChanged: changeAgent,
            onFillInRequested: canFillIn ? fillIns.countTap : null,
            onRemoved: removals.countTap,
            onDone: dones.countTap,
          ),
    );
  }
}

Workflow _buildWorkflowAround(WorkflowAgent agent) {
  final Workflow empty = Workflow(
    id: const WorkflowId('settings-workflow'),
    name: 'settings-workflow',
    availability: const AllWorkspaces(),
    agents: const <WorkflowAgent>[],
    connections: const <AgentConnection>[],
    signature: null,
  );
  return addAgent(empty, agent);
}

Future<AgentSettingsScene> pumpAgentSettings(
  WidgetTester tester, {
  required Random random,
  required WorkflowAgent agent,
  required bool canFillIn,
}) async {
  final AgentSettingsScene scene = AgentSettingsScene(
    agent: agent,
    canFillIn: canFillIn,
  );
  addTearDown(scene.shownAgent.dispose);
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SingleChildScrollView(child: scene.buildPanel(random)),
  );
  return scene;
}

WorkflowAgent randomSettingsAgent(Random random) {
  return randomAgent(random, random.nextInt(9));
}
