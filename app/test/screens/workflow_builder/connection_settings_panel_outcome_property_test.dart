import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/connection_panel_harness.dart';
import 'support/random_connection_scenes.dart';

const int _largestTypingCount = 6;
const List<String> _paddings = <String>[' ', '  ', '\t', ' '];

AgentConnection? _findSavedByRules(ConnectionScene scene, String typed) {
  final String outcome = typed.trim();
  final AgentConnection edited = scene.connection.withCondition(
    outcome.isEmpty ? null : outcome,
  );
  final String? problem = describeConnectionsProblem(
    scene.replaceConnection(edited),
  );
  return problem == null ? edited : null;
}

Future<String> _typeOutcome(WidgetTester tester, String typed) async {
  await tester.enterText(find.byType(TextField), typed);
  await tester.pump();
  return findShownOutcomeField(tester).controller!.text;
}

Future<ConnectionPanelLog> _pumpRandomPanel(
  WidgetTester tester,
  Random random,
  ConnectionScene scene,
) async {
  final ConnectionPanelLog log = ConnectionPanelLog();
  await pumpFreshConnectionPanel(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    panel: log.buildPanel(scene),
  );
  return log;
}

void main() {
  testWidgets('test_change_outcome_property_saves_exactly_what_rules_allow', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomConnectionScene(random);
      final ConnectionPanelLog log = await _pumpRandomPanel(
        tester,
        random,
        scene,
      );
      String shownText = scene.connection.condition ?? '';
      final int typingCount = 1 + random.nextInt(_largestTypingCount);

      for (int typing = 0; typing < typingCount; typing += 1) {
        final int savedBefore = log.changes.length;
        final String typed = randomTypedOutcome(random, scene);
        final String fieldText = await _typeOutcome(tester, typed);
        if (fieldText == shownText) {
          expect(log.changes.length, savedBefore);
          continue;
        }
        shownText = fieldText;

        final AgentConnection? allowed = _findSavedByRules(scene, fieldText);
        if (allowed == null) {
          expect(log.changes.length, savedBefore, reason: fieldText);
        } else {
          expect(log.changes.length, savedBefore + 1, reason: fieldText);
          expect(log.changes.last, allowed, reason: fieldText);
        }
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_change_outcome_property_problem_shown_iff_not_saved', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomConnectionScene(random);
      final String fromName = scene.workflow
          .findAgent(scene.connection.from)
          .name;
      await _pumpRandomPanel(tester, random, scene);
      final String typed = randomTypedOutcome(random, scene);

      final String fieldText = await _typeOutcome(tester, typed);

      final String outcome = fieldText.trim();
      final String? problem = findShownOutcomeProblem(tester);
      final bool isAllowed = _findSavedByRules(scene, fieldText) != null;
      final bool isUnchanged = fieldText == (scene.connection.condition ?? '');
      if (isUnchanged) {
        expect(problem, isNull);
      } else if (isAllowed) {
        expect(problem, isNull, reason: fieldText);
      } else if (outcome.isEmpty) {
        expect(problem, loopNeedsOutcomeProblem);
      } else if (!isWellFormedOutcome(outcome)) {
        expect(problem, outcomeFormatProblem, reason: fieldText);
      } else {
        expect(problem, contains(fromName));
        expect(problem, contains(outcome));
      }
    }
  });

  testWidgets('test_change_outcome_property_padding_changes_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomConnectionScene(random);
      final ConnectionPanelLog log = await _pumpRandomPanel(
        tester,
        random,
        scene,
      );
      final String bare = randomOutcomeOfLength(
        random,
        1 + random.nextInt(maximumOutcomeLength),
      );
      final String padding = pickOne(random, _paddings);

      await _typeOutcome(tester, bare);
      final String? bareProblem = findShownOutcomeProblem(tester);
      final List<AgentConnection> bareChanges = List<AgentConnection>.of(
        log.changes,
      );
      await _typeOutcome(tester, '$padding$bare$padding');

      expect(findShownOutcomeProblem(tester), bareProblem);
      final List<AgentConnection> paddedChanges = log.changes.sublist(
        bareChanges.length,
      );
      expect(paddedChanges, bareChanges);
    }
  });
}
