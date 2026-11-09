import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'support/held_builder_page.dart';

const WorkflowId _builtWorkflowId = GalleryWorkflowIds.release;
const String _seededOutcome = 'changes';
const int _seededRounds = 2;

Future<AgentConnection> _seedLoop(AppDependencies gallery) async {
  final Workflow release = gallery.workflowRepository.findWorkflow(
    _builtWorkflowId,
  );
  final AgentConnection forward = release.connections.first;
  final AgentConnection loop = AgentConnection(
    from: forward.to,
    to: forward.from,
    condition: _seededOutcome,
    roundLimit: _seededRounds,
  );
  await gallery.workflowRepository.saveWorkflow(
    release.withGraph(
      agents: release.agents,
      connections: <AgentConnection>[...release.connections, loop],
    ),
  );
  return loop;
}

Future<void> _tapLoopLabel(
  WidgetTester tester,
  Workflow workflow,
  AgentConnection loop,
) async {
  final List<DiagramEdge> edges = describeDiagramEdges(
    agents: workflow.agents,
    connections: workflow.connections,
    selected: null,
    drawnLoop: null,
  );
  final DiagramEdge edge = edges.firstWhere(
    (DiagramEdge candidate) => candidate.connection.joinsSameSteps(loop),
  );
  final RenderBox diagram = tester.renderObject<RenderBox>(
    find.byType(WorkflowDiagram),
  );
  await tester.tapAt(diagram.localToGlobal(findLabelCentre(edge.route)));
  await pumpFrames(tester);
}

Future<(HeldBuilderPage, AgentConnection)> _openOnLoop(
  WidgetTester tester,
  Random random,
) async {
  final AppDependencies gallery = buildGalleryDependencies();
  final AgentConnection loop = await _seedLoop(gallery);
  final HeldBuilderPage page = HeldBuilderPage(
    workflowId: _builtWorkflowId,
    gallery: gallery,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await page.open(tester, size: randomActionWindowSize(random));
  await tapButtonLabelled(tester, fitLabel);
  await _tapLoopLabel(tester, page.readSaved(), loop);
  expect(find.byType(ConnectionSettingsPanel), findsOneWidget);
  return (page, loop);
}

String _randomOutcome(Random random) {
  return 'redo-${random.nextInt(999)}';
}

void main() {
  testWidgets('test_save_edit_property_loop_outcome_and_rounds_both_'
      'land', (WidgetTester tester) async {
    final Random random = seededRandom(1191001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final (HeldBuilderPage page, AgentConnection loop) = await _openOnLoop(
        tester,
        random,
      );
      final String outcome = _randomOutcome(random);
      final int rounds = fewestLoopRounds + random.nextInt(mostLoopRounds);

      await typeIntoField(tester, label: outcomeLabel, text: outcome);
      chooseSelectValue(tester, RoundLimitChoice(rounds));
      await tester.pump();
      await page.releaseEveryReply(tester);

      final AgentConnection saved = findConnection(page.readSaved(), loop);
      expect(saved.condition, outcome);
      expect(saved.roundLimit, rounds);
      expect(readFieldInputText(tester, outcomeLabel), outcome);
    }
  });

  testWidgets('test_save_edit_property_refused_outcome_shows_the_saved_'
      'one', (WidgetTester tester) async {
    final Random random = seededRandom(1191002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final (HeldBuilderPage page, AgentConnection loop) = await _openOnLoop(
        tester,
        random,
      );
      final String refusal = 'Refused ${randomWordPhrase(random)}'.trim();

      await typeIntoField(
        tester,
        label: outcomeLabel,
        text: _randomOutcome(random),
      );
      page.held.refuseNextReply(PeopleFacingRefusal(refusal));
      await tester.pump();
      await tester.pump();
      await tapButtonLabelled(tester, refusalCloseLabel);

      expect(readFieldInputText(tester, outcomeLabel), _seededOutcome);
      expect(findConnection(page.readSaved(), loop).condition, _seededOutcome);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_save_edit_property_outcome_field_never_jumps_back', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final (HeldBuilderPage page, AgentConnection loop) = await _openOnLoop(
        tester,
        random,
      );
      final String outcome = _randomOutcome(random);

      for (int length = 1; length <= outcome.length; length += 1) {
        final String typed = outcome.substring(0, length);
        await typeIntoField(tester, label: outcomeLabel, text: typed);
        if (page.held.heldReplyCount > 1 && random.nextBool()) {
          await page.releaseOneReply(tester);
        }

        expect(readFieldInputText(tester, outcomeLabel), typed);
      }
      await page.releaseEveryReply(tester);

      expect(findConnection(page.readSaved(), loop).condition, outcome);
    }
  });
}
