import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../presentation/support/plain_shown_text.dart';
import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import '../support/random_page_windows.dart';

const String _designPage = 'workflow-builder';

final class _StepCounters {
  final TapCounter agents = TapCounter();
  final TapCounter people = TapCounter();
}

Future<_StepCounters> _pumpStepButtons(
  WidgetTester tester,
  Random random,
) async {
  final _StepCounters counters = _StepCounters();
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: AddStepButtons(
      onAgentAdded: counters.agents.countTap,
      onPersonStepAdded: counters.people.countTap,
    ),
  );
  return counters;
}

DiagramEdge? _randomEdge(Random random) {
  final Workflow workflow = randomBranchingWorkflow(random);
  final List<DiagramEdge> edges = describeDiagramEdges(
    agents: workflow.agents,
    connections: workflow.connections,
    selected: null,
    drawnLoop: null,
  );
  if (edges.isEmpty || random.nextBool()) {
    return null;
  }
  return pickOne(random, edges);
}

CanvasHit _randomAgentHit(Random random) {
  final WorkflowAgentId agentId = WorkflowAgentId(randomText(random));
  if (random.nextBool()) {
    return NodeHit(agentId);
  }
  return PortHit(agentId, pickOne(random, PortSide.values));
}

void main() {
  testWidgets('test_add_step_buttons_build_property_design_labels_fit', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162601);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpStepButtons(tester, random);

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(find.widgetWithText(AppButton, addAgentLabel), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, addPersonStepLabel),
        findsOneWidget,
      );
      expect(find.byType(AppButton), findsNWidgets(2));
    }
  });

  testWidgets('test_add_step_buttons_build_property_each_calls_its_own', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162602);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _StepCounters counters = await _pumpStepButtons(tester, random);
      final int agentTaps = random.nextInt(3);
      final int personTaps = random.nextInt(3);

      for (int tap = 0; tap < agentTaps; tap += 1) {
        await tester.tap(find.widgetWithText(AppButton, addAgentLabel));
      }
      for (int tap = 0; tap < personTaps; tap += 1) {
        await tester.tap(find.widgetWithText(AppButton, addPersonStepLabel));
      }
      await tester.pump();

      expect(counters.agents.count, agentTaps);
      expect(counters.people.count, personTaps);
    }
  });

  testWidgets('test_add_step_buttons_build_property_buttons_never_overlap', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162603);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      useViewSize(
        tester,
        Size(
          randomWidth(random, least: narrowestWidth, most: widestWidth),
          phoneHeight,
        ),
      );
      await tester.pumpWidget(
        wrapInApp(
          SingleChildScrollView(
            child: AddStepButtons(
              onAgentAdded: () {},
              onPersonStepAdded: () {},
            ),
          ),
          platform: phonePlatform,
        ),
      );
      expect(tester.takeException(), isNull, reason: 'round $i');

      final Rect agent = tester.getRect(
        find.widgetWithText(AppButton, addAgentLabel),
      );
      final Rect person = tester.getRect(
        find.widgetWithText(AppButton, addPersonStepLabel),
      );
      expect(agent.overlaps(person), isFalse);
    }
  });

  test('test_choose_canvas_cursor_property_agent_hit_outranks_edges', () {
    final Random random = seededRandom(1162604);
    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasHit hit = _randomAgentHit(random);
      final DiagramEdge? edge = _randomEdge(random);

      expect(
        chooseCanvasCursor(agentHit: hit, edgeHit: edge),
        chooseCanvasCursor(agentHit: hit, edgeHit: null),
      );
    }
  });

  test('test_choose_canvas_cursor_property_ids_and_sides_never_matter', () {
    final Random random = seededRandom(1162605);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DiagramEdge? edge = _randomEdge(random);
      final WorkflowAgentId first = WorkflowAgentId(randomText(random));
      final WorkflowAgentId second = WorkflowAgentId(randomText(random));

      expect(
        chooseCanvasCursor(agentHit: NodeHit(first), edgeHit: edge),
        chooseCanvasCursor(agentHit: NodeHit(second), edgeHit: edge),
      );
      expect(
        chooseCanvasCursor(
          agentHit: PortHit(first, PortSide.input),
          edgeHit: edge,
        ),
        chooseCanvasCursor(
          agentHit: PortHit(second, PortSide.output),
          edgeHit: edge,
        ),
      );
    }
  });

  test('test_builder_toolbar_property_labels_match_design', () {
    final String designText = readDesignPageText(_designPage);

    for (final String label in <String>[
      addAgentLabel,
      addPersonStepLabel,
      askAnAgentLabel,
      cancelBuildingLabel,
      signAndSaveLabel,
      fillInWithAgentLabel,
    ]) {
      expect(designText, contains(label));
    }
  });
}
