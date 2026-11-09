import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'support/held_builder_page.dart';
import 'support/new_loop_panel_scene.dart';
import 'support/random_connection_scenes.dart';

int _randomRounds(Random random) {
  return fewestLoopRounds + random.nextInt(mostLoopRounds);
}

String? _describeExpectedProblem(ConnectionScene scene, String typed) {
  final String outcome = typed.trim();
  if (outcome.isEmpty) {
    return loopNeedsOutcomeProblem;
  }
  return describeOutcomeProblem(
    workflow: scene.workflow,
    connection: scene.connection,
    outcome: outcome,
  );
}

String? _readOutcomeProblem(WidgetTester tester) {
  return tester
      .widget<TextField>(find.byType(TextField))
      .decoration
      ?.errorText;
}

void main() {
  testWidgets('test_new_loop_panel_build_property_shows_the_design_'
      'wording', (WidgetTester tester) async {
    final Random random = seededRandom(1191701);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomDrawnLoopScene(random);

      await pumpLoopPanel(tester, random, scene);

      expect(tester.takeException(), isNull);
      expect(find.text(newLoopTitle), findsOneWidget);
      expect(find.text(goesBackText), findsOneWidget);
      expect(find.text(loopOutcomeHint), findsOneWidget);
      expect(find.text(chooseRoundsLabel), findsOneWidget);
      expect(
        find.text(describeConnectionEnds(scene.workflow, scene.connection)),
        findsOneWidget,
      );
    }
  });

  testWidgets('test_new_loop_panel_build_property_has_no_done_button', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191702);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpLoopPanel(tester, random, randomDrawnLoopScene(random));

      expect(find.text('Done'), findsNothing);
      expect(find.text(loopCancelLabel), findsOneWidget);
      expect(find.text(addLoopLabel), findsOneWidget);
    }
  });

  testWidgets('test_new_loop_panel_build_property_cancel_only_cancels', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191703);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final LoopPanelLog log = await pumpLoopPanel(
        tester,
        random,
        randomDrawnLoopScene(random),
      );
      await typeLoopOutcome(tester, pickOne(random, sampleOutcomes));

      await tapShownText(tester, loopCancelLabel);

      expect(log.cancels.count, 1);
      expect(log.addedLoops, isEmpty);
    }
  });

  testWidgets('test_add_loop_property_adds_exactly_the_typed_loop', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191704);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomDrawnLoopScene(random);
      final LoopPanelLog log = await pumpLoopPanel(tester, random, scene);
      final String typed = randomTypedOutcome(random, scene);
      final int rounds = _randomRounds(random);

      await typeLoopOutcome(tester, typed);
      chooseSelectValue(tester, RoundLimitChoice(rounds));
      await tester.pump();
      await tapAddLoop(tester);

      final String? problem = _describeExpectedProblem(scene, typed);
      if (problem != null) {
        expect(log.addedLoops, isEmpty, reason: typed);
        continue;
      }
      final AgentConnection added = log.addedLoops.single;
      expect(added.from, scene.connection.from);
      expect(added.to, scene.connection.to);
      expect(added.condition, typed.trim());
      expect(added.roundLimit, rounds);
    }
  });

  testWidgets('test_add_loop_property_without_rounds_asks_for_them', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191705);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomDrawnLoopScene(random);
      final LoopPanelLog log = await pumpLoopPanel(tester, random, scene);
      await typeLoopOutcome(tester, randomTypedOutcome(random, scene));

      await tapAddLoop(tester);

      expect(find.text(chooseRoundsProblem), findsOneWidget);
      expect(log.addedLoops, isEmpty);
      chooseSelectValue(tester, RoundLimitChoice(_randomRounds(random)));
      await tester.pump();
      expect(find.text(chooseRoundsProblem), findsNothing);
    }
  });

  testWidgets('test_add_loop_property_repeated_taps_add_the_same_loop', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191706);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomDrawnLoopScene(random);
      final LoopPanelLog log = await pumpLoopPanel(tester, random, scene);
      final String outcome = 'back-${random.nextInt(999)}';
      final int tapCount = 1 + random.nextInt(3);
      await typeLoopOutcome(tester, outcome);
      chooseSelectValue(tester, RoundLimitChoice(_randomRounds(random)));
      await tester.pump();

      for (int tap = 0; tap < tapCount; tap += 1) {
        await tapAddLoop(tester);
      }

      expect(log.addedLoops, hasLength(tapCount));
      expect(log.addedLoops.toSet(), hasLength(1));
    }
  });

  testWidgets('test_new_loop_panel_describe_outcome_problem_property_'
      'matches_the_rules', (WidgetTester tester) async {
    final Random random = seededRandom(1191707);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomDrawnLoopScene(random);
      await pumpLoopPanel(tester, random, scene);
      final String typed = randomTypedOutcome(random, scene);

      await typeLoopOutcome(tester, typed);
      await tapAddLoop(tester);

      expect(
        _readOutcomeProblem(tester),
        _describeExpectedProblem(scene, typed),
        reason: typed,
      );
    }
  });

  testWidgets('test_new_loop_panel_describe_outcome_problem_property_'
      'blank_needs_an_outcome', (WidgetTester tester) async {
    final Random random = seededRandom(1191708);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpLoopPanel(tester, random, randomDrawnLoopScene(random));
      final String blank = pickOne(random, <String>['', ' ', '\t', '   ']);

      await typeLoopOutcome(tester, blank);
      await tapAddLoop(tester);

      expect(_readOutcomeProblem(tester), loopNeedsOutcomeProblem);
    }
  });

  testWidgets('test_new_loop_panel_describe_outcome_problem_property_'
      'typing_clears_the_problem', (WidgetTester tester) async {
    final Random random = seededRandom(1191709);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpLoopPanel(tester, random, randomDrawnLoopScene(random));
      await tapAddLoop(tester);
      expect(_readOutcomeProblem(tester), loopNeedsOutcomeProblem);

      await typeLoopOutcome(tester, randomText(random));

      expect(_readOutcomeProblem(tester), isNull);
      expect(find.text(chooseRoundsProblem), findsOneWidget);
    }
  });
}
