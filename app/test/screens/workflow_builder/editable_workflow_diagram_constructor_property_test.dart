import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/editable_diagram_scene.dart';
import 'support/random_diagram_layouts.dart';

BuilderSelection? _randomSelection(Random random, Workflow workflow) {
  if (workflow.agents.isEmpty || random.nextBool()) {
    return null;
  }
  return SelectedStep(pickOne(random, workflow.agents).id);
}

void main() {
  test('test_editable_workflow_diagram_constructor_property_keeps_every_'
      'field', () {
    final Random random = seededRandom(1191601);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);
      final BuilderSelection? selection = _randomSelection(random, workflow);
      final EditableDiagramScene scene = EditableDiagramScene(
        workflow: workflow,
        selection: selection,
      );

      final EditableWorkflowDiagram diagram = scene.buildDiagram();

      expect(diagram.workflow, same(workflow));
      expect(diagram.selection, same(selection));
      expect(diagram.key, isNull);
    }
  });

  test('test_editable_workflow_diagram_constructor_property_callbacks_'
      'reach_their_owner', () {
    final Random random = seededRandom(1191602);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final EditableDiagramScene scene = EditableDiagramScene(
        workflow: workflow,
        selection: null,
      );
      final EditableWorkflowDiagram diagram = scene.buildDiagram();
      final WorkflowAgent agent = pickOne(random, workflow.agents);

      diagram.onAgentSelected(agent.id);
      diagram.onAgentMoved(agent.id, agent.position);
      diagram.onSelectionCleared();

      expect(scene.selectedAgents, <Object>[agent.id]);
      expect(scene.moves.single.position, agent.position);
      expect(scene.clearCount, 1);
    }
  });

  test('test_editable_workflow_diagram_constructor_property_keeps_the_'
      'key', () {
    final Random random = seededRandom(1191609);
    for (int i = 0; i < propertyIterations; i += 1) {
      final EditableWorkflowDiagram plain = EditableDiagramScene(
        workflow: randomDiagramWorkflow(random),
        selection: null,
      ).buildDiagram();
      final Key key = ValueKey<int>(random.nextInt(1 << 30));

      final EditableWorkflowDiagram keyed = EditableWorkflowDiagram(
        key: key,
        workflow: plain.workflow,
        selection: plain.selection,
        deviceNames: plain.deviceNames,
        onAgentSelected: plain.onAgentSelected,
        onConnectionSelected: plain.onConnectionSelected,
        onSelectionCleared: plain.onSelectionCleared,
        onAgentMoved: plain.onAgentMoved,
        onAgentsConnected: plain.onAgentsConnected,
      );

      expect(keyed.key, same(key));
      expect(keyed.workflow, same(plain.workflow));
    }
  });
}
