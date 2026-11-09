import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import '../../support/sample_runners.dart';

typedef _FieldCheck = void Function(Random random, Key key);

void _ignoreTap() {}

void _ignoreAgent(WorkflowAgent _) {}

void _ignoreAgentId(WorkflowAgentId _) {}

void _ignoreConnection(AgentConnection _) {}

Future<void> _leaveAtOnce() async {}

AgentConnection _randomConnection(Random random) {
  return AgentConnection(
    from: WorkflowAgentId(randomText(random)),
    to: WorkflowAgentId(randomText(random)),
    condition: random.nextBool() ? pickOne(random, sampleOutcomes) : null,
    roundLimit: random.nextBool() ? 1 + random.nextInt(9) : null,
  );
}

void _checkSelectedStep(Random random, Key _) {
  final WorkflowAgentId agentId = WorkflowAgentId(randomHostileText(random));
  final SelectedStep selection = SelectedStep(agentId);
  expect(selection.agentId, agentId);
  expect(selection, isA<BuilderSelection>());
}

void _checkSelectedConnection(Random random, Key _) {
  final AgentConnection connection = _randomConnection(random);
  final SelectedConnection selection = SelectedConnection(connection);
  expect(selection.connection, same(connection));
  expect(selection, isA<BuilderSelection>());
}

void _checkDrawnLoop(Random random, Key _) {
  final AgentConnection connection = _randomConnection(random);
  final DrawnLoop selection = DrawnLoop(connection);
  expect(selection.connection, same(connection));
  expect(selection, isA<BuilderSelection>());
}

void _checkPanelActions(Random random, Key _) {
  final ValueChanged<WorkflowAgentId>? fillIn = random.nextBool()
      ? _ignoreAgentId
      : null;
  final BuilderPanelActions actions = BuilderPanelActions(
    onAgentChanged: _ignoreAgent,
    onFillInRequested: fillIn,
    onAgentRemoved: _ignoreAgentId,
    onConnectionChanged: _ignoreConnection,
    onConnectionRemoved: _ignoreConnection,
    onLoopAdded: _ignoreConnection,
    onDone: _ignoreTap,
  );
  expect(actions.onAgentChanged, _ignoreAgent);
  expect(actions.onFillInRequested, fillIn);
  expect(actions.onAgentRemoved, _ignoreAgentId);
  expect(actions.onConnectionChanged, _ignoreConnection);
  expect(actions.onConnectionRemoved, _ignoreConnection);
  expect(actions.onLoopAdded, _ignoreConnection);
  expect(actions.onDone, _ignoreTap);
}

void _checkPanelSources(Random random, Key _) {
  final List<Runner> runners = randomRunners(random);
  final DeviceNames deviceNames = DeviceNames(const <Device>[]);
  final BuilderPanelSources sources = BuilderPanelSources(
    runners: runners,
    skills: gallerySkills,
    deviceNames: deviceNames,
  );
  expect(sources.runners, same(runners));
  expect(sources.skills, same(gallerySkills));
  expect(sources.deviceNames, same(deviceNames));
}

void _checkAgentNodeBox(Random random, Key key) {
  final String kindText = randomHostileText(random);
  final String name = randomHostileText(random);
  final String? targetText = randomOptionalHostileText(random);
  final StepKind stepKind = pickOne(random, StepKind.values);
  final NodeLook look = pickOne(random, NodeLook.values);
  final AgentNodeBox box = AgentNodeBox(
    kindText: kindText,
    name: name,
    targetText: targetText,
    stepKind: stepKind,
    look: look,
    key: key,
  );
  expect(
    <Object?>[box.kindText, box.name, box.targetText, box.key],
    <Object?>[kindText, name, targetText, key],
  );
  expect(<Object>[box.stepKind, box.look], <Object>[stepKind, look]);
}

void _checkAgentSettingsPanel(Random random, Key key) {
  final Workflow workflow = randomBranchingWorkflow(random);
  final WorkflowAgent agent = randomAgent(random, random.nextInt(9));
  final List<SelectOption<RunnerTarget>> options =
      <SelectOption<RunnerTarget>>[];
  final AgentSettingsPanel panel = AgentSettingsPanel(
    workflow: workflow,
    agent: agent,
    runnerOptions: options,
    skills: gallerySkills,
    onAgentChanged: _ignoreAgent,
    onFillInRequested: random.nextBool() ? _ignoreTap : null,
    onRemoved: _ignoreTap,
    onDone: _ignoreTap,
    key: key,
  );
  expect(panel.workflow, same(workflow));
  expect(panel.agent, same(agent));
  expect(panel.runnerOptions, same(options));
  expect(panel.key, key);
}

void _checkBuilderHeader(Random random, Key key) {
  final String title = randomHostileText(random);
  final String summary = randomHostileText(random);
  final BuilderHeader header = BuilderHeader(
    title: title,
    summary: summary,
    onBack: _ignoreTap,
    onCancel: _leaveAtOnce,
    onSigned: _leaveAtOnce,
    key: key,
  );
  expect(
    <Object?>[header.title, header.summary, header.key],
    <Object?>[title, summary, key],
  );
  expect(header.onCancel, _leaveAtOnce);
  expect(header.onSigned, _leaveAtOnce);
}

void _checkToolbars(Random random, Key key) {
  final BuilderToolbar toolbar = BuilderToolbar(
    onAgentAdded: _ignoreTap,
    onPersonStepAdded: _leaveAtOnce,
    onChatOpened: _ignoreTap,
    key: key,
  );
  final AddStepButtons buttons = AddStepButtons(
    onAgentAdded: _leaveAtOnce,
    onPersonStepAdded: _ignoreTap,
    key: key,
  );
  expect(toolbar.onPersonStepAdded, _leaveAtOnce);
  expect(toolbar.onChatOpened, _ignoreTap);
  expect(buttons.onAgentAdded, _leaveAtOnce);
  expect(<Key?>[toolbar.key, buttons.key], <Key>[key, key]);
}

void _checkLayouts(Random random, Key key) {
  final List<Widget> top = <Widget>[
    for (int index = 0; index < random.nextInt(4); index += 1)
      SizedBox(height: index.toDouble()),
  ];
  const Widget canvas = SizedBox.shrink();
  final Widget? panel = random.nextBool() ? const SizedBox() : null;
  final BuilderPageLayout page = BuilderPageLayout(
    top: top,
    builder: canvas,
    key: key,
  );
  final BuilderFrame frame = BuilderFrame(
    canvas: canvas,
    panel: panel,
    key: key,
  );
  final CanvasFrame canvasFrame = CanvasFrame(key: key, child: canvas);
  expect(page.top, same(top));
  expect(page.builder, same(canvas));
  expect(frame.panel, same(panel));
  expect(canvasFrame.child, same(canvas));
  expect(<Key?>[page.key, frame.key, canvasFrame.key], <Key>[key, key, key]);
}

void _checkPainters(Random random, Key _) {
  final Color color = Color(random.nextInt(1 << 32));
  final DashedOutlinePainter dashed = DashedOutlinePainter(color: color);
  expect(dashed.color, color);
  expect(const DotGridPainter(), same(const DotGridPainter()));
}

const Map<String, _FieldCheck> _constructorChecks = <String, _FieldCheck>{
  'selected_step': _checkSelectedStep,
  'selected_connection': _checkSelectedConnection,
  'drawn_loop': _checkDrawnLoop,
  'builder_panel_actions': _checkPanelActions,
  'builder_panel_sources': _checkPanelSources,
  'agent_node_box': _checkAgentNodeBox,
  'agent_settings_panel': _checkAgentSettingsPanel,
  'builder_header': _checkBuilderHeader,
  'builder_toolbar': _checkToolbars,
  'builder_page_layout': _checkLayouts,
  'dashed_outline_painter': _checkPainters,
};

const List<String> _guarantees = <String>[
  'keeps_every_field',
  'keeps_hostile_fields',
  'keeps_fields_of_each_instance',
];

void main() {
  int seed = 1162801;
  for (final MapEntry<String, _FieldCheck> entry
      in _constructorChecks.entries) {
    for (final String guarantee in _guarantees) {
      final int testSeed = seed;
      seed += 1;
      test('test_${entry.key}_new_property_$guarantee', () {
        final Random random = seededRandom(testSeed);
        for (int i = 0; i < propertyIterations; i += 1) {
          entry.value(random, ValueKey<int>(random.nextInt(1 << 30)));
        }
      });
    }
  }
}
