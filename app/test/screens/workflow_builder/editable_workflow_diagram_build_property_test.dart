import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/editable_diagram_scene.dart';
import 'support/random_diagram_layouts.dart';

const double _tolerance = 1e-6;

List<String> _listNodeNames(WorkflowDiagram diagram) {
  return <String>[for (final DiagramNode node in diagram.nodes) node.name];
}

AgentConnection _randomLoopBetween(Random random, Workflow workflow) {
  final WorkflowAgent from = pickOne(random, workflow.agents);
  final WorkflowAgent to = pickOne(random, workflow.agents);
  return AgentConnection(
    from: from.id,
    to: to.id,
    condition: 'back',
    roundLimit: 1 + random.nextInt(10),
  );
}

Future<ReachableAgent?> _startMovingAStep(
  WidgetTester tester,
  Random random,
  Workflow workflow,
) async {
  await pumpEditableDiagram(tester, random: random, workflow: workflow);
  return pickReachableAgent(
    tester,
    random: random,
    workflow: workflow,
    findPoint: findNodeCentre,
  );
}

CanvasPosition _findShownPosition(WidgetTester tester, String name) {
  final WorkflowDiagram diagram = readShownDiagram(tester);
  return diagram.nodes
      .firstWhere((DiagramNode node) => node.name == name)
      .position;
}

void main() {
  testWidgets('test_editable_workflow_diagram_build_property_draws_every_'
      'step_at_random_sizes', (WidgetTester tester) async {
    final Random random = seededRandom(1191401);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);

      await pumpEditableDiagram(tester, random: random, workflow: workflow);

      expect(tester.takeException(), isNull);
      expect(_listNodeNames(readShownDiagram(tester)), <String>[
        for (final WorkflowAgent agent in workflow.agents) agent.name,
      ]);
    }
  });

  testWidgets('test_editable_workflow_diagram_build_property_selected_'
      'step_alone_looks_selected', (WidgetTester tester) async {
    final Random random = seededRandom(1191402);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent selected = pickOne(random, workflow.agents);

      await pumpEditableDiagram(
        tester,
        random: random,
        workflow: workflow,
        selection: SelectedStep(selected.id),
      );

      final List<DiagramNode> nodes = readShownDiagram(tester).nodes;
      for (int index = 0; index < nodes.length; index += 1) {
        final bool isSelected = workflow.agents[index].id == selected.id;
        expect(
          nodes[index].look,
          isSelected ? NodeLook.selected : NodeLook.normal,
        );
      }
    }
  });

  testWidgets('test_editable_workflow_diagram_build_property_one_edge_per_'
      'connection', (WidgetTester tester) async {
    final Random random = seededRandom(1191403);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);
      final AgentConnection? selected = workflow.connections.isEmpty
          ? null
          : pickOne(random, workflow.connections);

      await pumpEditableDiagram(
        tester,
        random: random,
        workflow: workflow,
        selection: selected == null ? null : SelectedConnection(selected),
      );

      final List<DiagramEdge> edges = readShownDiagram(tester).edges;
      expect(edges, hasLength(workflow.connections.length));
      for (final DiagramEdge edge in edges) {
        final bool isSelected = edge.connection == selected;
        expect(edge.look, isSelected ? EdgeLook.selected : EdgeLook.normal);
      }
    }
  });

  testWidgets('test_find_shown_drawn_loop_property_drawn_loop_adds_one_'
      'dashed_edge', (WidgetTester tester) async {
    final Random random = seededRandom(1191404);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomLaidOutWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final AgentConnection loop = _randomLoopBetween(random, workflow);

      await pumpEditableDiagram(
        tester,
        random: random,
        workflow: workflow,
        selection: DrawnLoop(loop),
      );

      final List<DiagramEdge> edges = readShownDiagram(tester).edges;
      expect(edges, hasLength(workflow.connections.length + 1));
      expect(edges.last.connection, loop);
      expect(edges.last.line, EdgeLine.dashed);
      expect(edges.last.look, EdgeLook.selected);
    }
  });

  testWidgets('test_find_shown_drawn_loop_property_loop_to_a_removed_step_'
      'is_not_drawn', (WidgetTester tester) async {
    final Random random = seededRandom(1191405);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomLaidOutWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final AgentConnection loop = _randomLoopBetween(random, workflow);
      final WorkflowAgentId removedId = random.nextBool()
          ? loop.from
          : loop.to;
      final Workflow without = removeAgent(workflow, removedId);

      await pumpEditableDiagram(
        tester,
        random: random,
        workflow: without,
        selection: DrawnLoop(loop),
      );

      expect(tester.takeException(), isNull);
      final List<DiagramEdge> edges = readShownDiagram(tester).edges;
      expect(edges, hasLength(without.connections.length));
    }
  });

  testWidgets('test_find_shown_drawn_loop_property_other_selections_draw_'
      'no_extra_edge', (WidgetTester tester) async {
    final Random random = seededRandom(1191406);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final BuilderSelection? selection = pickOne(random, <BuilderSelection?>[
        null,
        SelectedStep(pickOne(random, workflow.agents).id),
      ]);

      await pumpEditableDiagram(
        tester,
        random: random,
        workflow: workflow,
        selection: selection,
      );

      final List<DiagramEdge> edges = readShownDiagram(tester).edges;
      expect(edges, hasLength(workflow.connections.length));
    }
  });

  testWidgets('test_place_agents_property_dragged_step_is_drawn_where_'
      'dragged', (WidgetTester tester) async {
    final Random random = seededRandom(1191407);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomLaidOutWorkflow(random);
      final ReachableAgent? grabbed = await _startMovingAStep(
        tester,
        random,
        workflow,
      );
      if (grabbed == null) {
        continue;
      }
      final Offset shift = Offset(30 + random.nextDouble() * 80, 40);
      final double scale = readCanvasScale(tester);
      final TestGesture gesture = await tester.startGesture(grabbed.global);
      await gesture.moveBy(shift);
      await tester.pump();

      final CanvasPosition shown = _findShownPosition(
        tester,
        grabbed.agent.name,
      );
      final CanvasPosition expected = moveCanvasPosition(
        grabbed.agent.position,
        shift / scale,
      );
      expect(shown.horizontal, closeTo(expected.horizontal, _tolerance));
      expect(shown.vertical, closeTo(expected.vertical, _tolerance));
      await gesture.up();
      await tester.pump();
    }
  });

  testWidgets('test_place_agents_property_other_steps_stay_put', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191408);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomLaidOutWorkflow(random);
      final ReachableAgent? grabbed = await _startMovingAStep(
        tester,
        random,
        workflow,
      );
      if (grabbed == null) {
        continue;
      }
      final TestGesture gesture = await tester.startGesture(grabbed.global);
      await gesture.moveBy(const Offset(60, 50));
      await tester.pump();

      for (final WorkflowAgent agent in workflow.agents) {
        if (agent.id != grabbed.agent.id) {
          expect(_findShownPosition(tester, agent.name), agent.position);
        }
      }
      await gesture.up();
      await tester.pump();
    }
  });

  testWidgets('test_place_agents_property_after_the_drop_the_saved_places_'
      'show', (WidgetTester tester) async {
    final Random random = seededRandom(1191409);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomLaidOutWorkflow(random);
      final ReachableAgent? grabbed = await _startMovingAStep(
        tester,
        random,
        workflow,
      );
      if (grabbed == null) {
        continue;
      }
      final TestGesture gesture = await tester.startGesture(grabbed.global);
      await gesture.moveBy(const Offset(70, 45));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      for (final WorkflowAgent agent in workflow.agents) {
        expect(_findShownPosition(tester, agent.name), agent.position);
      }
    }
  });
}
