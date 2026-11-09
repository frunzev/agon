import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import '../support/random_page_windows.dart';
import '../task_form/task_form_scene.dart';

const int _mostSteps = 8;

final class _RecordedActions {
  final List<WorkflowAgent> changedAgents = <WorkflowAgent>[];
  final List<WorkflowAgentId> removedAgents = <WorkflowAgentId>[];
  final List<WorkflowAgentId> fillInRequests = <WorkflowAgentId>[];
  int doneCount = 0;

  void countDone() {
    doneCount += 1;
  }

  BuilderPanelActions build({required bool canFillIn}) {
    return BuilderPanelActions(
      onAgentChanged: changedAgents.add,
      onFillInRequested: canFillIn ? fillInRequests.add : null,
      onAgentRemoved: removedAgents.add,
      onConnectionChanged: (AgentConnection _) {},
      onConnectionRemoved: (AgentConnection _) {},
      onLoopAdded: (AgentConnection _) {},
      onDone: countDone,
    );
  }
}

typedef _BuilderState = ({Workflow workflow, BuilderSelection? selection});

BuilderPanelSources _randomSources(Random random) {
  return BuilderPanelSources(
    runners: randomRunnersOnDistinctDevices(random),
    skills: gallerySkills,
    deviceNames: DeviceNames(galleryDevices),
  );
}

BuilderSelection? _randomSelectionIn(Random random, Workflow workflow) {
  final List<BuilderSelection?> choices = <BuilderSelection?>[null];
  if (workflow.agents.isNotEmpty) {
    choices.add(SelectedStep(pickOne(random, workflow.agents).id));
  }
  if (workflow.connections.isNotEmpty) {
    choices.add(SelectedConnection(pickOne(random, workflow.connections)));
  }
  if (workflow.agents.length > 1) {
    final List<WorkflowAgent> pair = List<WorkflowAgent>.of(workflow.agents)
      ..shuffle(random);
    choices.add(
      DrawnLoop(
        AgentConnection(
          from: pair[0].id,
          to: pair[1].id,
          condition: null,
          roundLimit: null,
        ),
      ),
    );
  }
  return pickOne(random, choices);
}

Workflow _changeElsewhere(Random random, Workflow workflow) {
  final int change = random.nextInt(4);
  if (change == 0 && workflow.agents.isNotEmpty) {
    return removeAgent(workflow, pickOne(random, workflow.agents).id);
  }
  if (change == 1 && workflow.connections.isNotEmpty) {
    return removeConnection(workflow, pickOne(random, workflow.connections));
  }
  if (change == 2 && workflow.agents.isNotEmpty) {
    final WorkflowAgent moved = pickOne(random, workflow.agents);
    return replaceAgent(
      workflow,
      moved.copyWith(position: randomCanvasPosition(random)),
    );
  }
  return addAgent(workflow, buildBlankAgent(workflow));
}

_BuilderState _randomStep(Random random, _BuilderState state) {
  if (random.nextBool()) {
    return (
      workflow: state.workflow,
      selection: _randomSelectionIn(random, state.workflow),
    );
  }
  return (
    workflow: _changeElsewhere(random, state.workflow),
    selection: state.selection,
  );
}

bool _isSelectionPresent(Workflow workflow, BuilderSelection selection) {
  switch (selection) {
    case SelectedStep(:final WorkflowAgentId agentId):
      return workflow.findAgentIfPresent(agentId) != null;
    case SelectedConnection(:final AgentConnection connection):
      return workflow.connections.any(connection.joinsSameSteps);
    case DrawnLoop(:final AgentConnection connection):
      return workflow.findAgentIfPresent(connection.from) != null &&
          workflow.findAgentIfPresent(connection.to) != null;
  }
}

Widget? _buildPanel(Random random, _BuilderState state) {
  return buildBuilderPanel(
    workflow: state.workflow,
    selection: state.selection,
    sources: _randomSources(random),
    actions: _RecordedActions().build(canFillIn: random.nextBool()),
  );
}

void main() {
  test('test_build_builder_panel_property_no_stale_selection_panel', () {
    final Random random = seededRandom(1161701);
    for (int i = 0; i < propertyIterations; i += 1) {
      _BuilderState state = (
        workflow: randomBranchingWorkflow(random),
        selection: null,
      );
      for (int step = 0; step < _mostSteps; step += 1) {
        state = _randomStep(random, state);
        final BuilderSelection? selection = state.selection;

        final Widget? panel = _buildPanel(random, state);

        final bool isShown =
            selection != null &&
            _isSelectionPresent(state.workflow, selection);
        expect(panel != null, isShown, reason: '$selection step $step');
      }
    }
  });

  test('test_build_builder_panel_property_panel_matches_selection', () {
    final Random random = seededRandom(1161702);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final BuilderSelection? selection = _randomSelectionIn(random, workflow);
      final _BuilderState state = (workflow: workflow, selection: selection);

      final Widget? panel = _buildPanel(random, state);

      switch (selection) {
        case null:
          expect(panel, isNull);
        case SelectedStep(:final WorkflowAgentId agentId):
          final bool isPerson =
              workflow.findAgent(agentId).stepKind == StepKind.person;
          expect(
            panel,
            isPerson ? isA<PersonStepPanel>() : isA<AgentSettingsPanel>(),
          );
          expect(panel!.key, ValueKey<WorkflowAgentId>(agentId));
        case SelectedConnection():
          expect(panel, isA<ConnectionSettingsPanel>());
        case DrawnLoop():
          expect(panel, isA<NewLoopPanel>());
      }
    }
  });

  testWidgets('test_build_builder_panel_property_stale_panels_never_throw', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161703);
    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final BuilderSelection? selection = _randomSelectionIn(random, workflow);
      final List<WorkflowAgentId> selectedEnds = <WorkflowAgentId>[
        ?findSelectedStepId(selection),
        ?findSelectedConnection(selection)?.from,
        ?findDrawnLoop(selection)?.to,
      ];
      final Workflow changed = selectedEnds.isEmpty
          ? workflow
          : removeAgent(workflow, pickOne(random, selectedEnds));
      final _BuilderState state = (workflow: changed, selection: selection);

      final Widget? panel = _buildPanel(random, state);
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: SingleChildScrollView(child: panel ?? const SizedBox.shrink()),
      );

      expect(tester.takeException(), isNull, reason: '${state.selection}');
    }
  });

  test('test_key_connection_property_same_ends_share_one_key', () {
    final Random random = seededRandom(1161704);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.connections.isEmpty) {
        continue;
      }
      final AgentConnection connection = pickOne(random, workflow.connections);
      final AgentConnection plain = AgentConnection(
        from: connection.from,
        to: connection.to,
        condition: null,
        roundLimit: null,
      );

      final Widget? selected = _buildPanel(random, (
        workflow: workflow,
        selection: SelectedConnection(connection),
      ));
      final Widget? plainSelected = _buildPanel(random, (
        workflow: workflow,
        selection: SelectedConnection(plain),
      ));

      expect(selected!.key, plainSelected!.key);
    }
  });

  test('test_key_connection_property_different_ends_differ', () {
    final Random random = seededRandom(1161705);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final Set<Key?> keys = <Key?>{};

      for (final AgentConnection connection in workflow.connections) {
        final Widget? panel = _buildPanel(random, (
          workflow: workflow,
          selection: SelectedConnection(connection),
        ));
        keys.add(panel!.key);
      }

      expect(keys.length, workflow.connections.length);
    }
  });

  test('test_key_connection_property_loop_and_connection_keys_agree', () {
    final Random random = seededRandom(1161706);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.connections.isEmpty) {
        continue;
      }
      final AgentConnection connection = pickOne(random, workflow.connections);

      final Widget? selected = _buildPanel(random, (
        workflow: workflow,
        selection: SelectedConnection(connection),
      ));
      final Widget? drawn = _buildPanel(random, (
        workflow: workflow,
        selection: DrawnLoop(connection),
      ));

      expect(selected!.key, isNotNull);
      expect(drawn!.key, selected.key);
    }
  });
}
