import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/connection_panel_harness.dart';
import 'support/random_connection_scenes.dart';

const String _malformedOutcome = 'Not An Outcome';
const String _doneLabel = 'Done';

void _ignoreNotification() {}

Future<void> _pumpPanel(
  WidgetTester tester,
  Random random,
  ConnectionPanelLog log,
  ConnectionScene scene,
) async {
  await pumpFreshConnectionPanel(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    panel: log.buildPanel(scene),
  );
}

void main() {
  testWidgets('test_connection_settings_panel_dispose_property_frees_field', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118207);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomConnectionScene(random);
      await _pumpPanel(tester, random, ConnectionPanelLog(), scene);
      final TextEditingController controller = findShownOutcomeField(tester)
          .controller!;

      await tester.pumpWidget(const SizedBox.shrink());

      expect(
        () => controller.addListener(_ignoreNotification),
        throwsFlutterError,
      );
    }
  });

  testWidgets(
    'test_connection_settings_panel_dispose_property_next_starts_new',
    (WidgetTester tester) async {
      final Random random = seededRandom(118208);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final ConnectionScene first = randomConnectionScene(random);
        final ConnectionScene second = randomConnectionScene(random);
        final ConnectionPanelLog log = ConnectionPanelLog();
        final double width = randomWidth(
          random,
          least: narrowestWidth,
          most: widestWidth,
        );
        await pumpScrollableAtWidth(
          tester,
          width: width,
          child: log.buildPanel(first, key: const ValueKey<int>(1)),
        );
        await tester.enterText(find.byType(TextField), _malformedOutcome);
        await tester.pump();

        await pumpScrollableAtWidth(
          tester,
          width: width,
          child: log.buildPanel(second, key: const ValueKey<int>(2)),
        );

        final TextField field = findShownOutcomeField(tester);
        expect(field.controller?.text, second.connection.condition ?? '');
        expect(findShownOutcomeProblem(tester), isNull);
      }
    },
  );

  testWidgets('test_connection_settings_panel_dispose_property_quiet_after', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118209);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionPanelLog log = ConnectionPanelLog();
      await _pumpPanel(tester, random, log, randomConnectionScene(random));
      await tester.enterText(find.byType(TextField), randomText(random));
      await tester.pump();
      final int changesBefore = log.changes.length;

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(log.changes.length, changesBefore);
      expect(log.events, isEmpty);
    }
  });

  testWidgets('test_connection_settings_panel_build_property_loop_parts', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118210);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomConnectionScene(random);
      final bool isLoop = scene.connection.isLoop;
      final String fromName = scene.workflow
          .findAgent(scene.connection.from)
          .name;
      await _pumpPanel(tester, random, ConnectionPanelLog(), scene);

      expect(tester.takeException(), isNull);
      expect(find.text(connectionPanelTitle), findsOneWidget);
      expect(find.text(removeConnectionLabel), findsOneWidget);
      expect(find.text(outcomeLabel), findsOneWidget);
      expect(
        find.text(describeConnectionEnds(scene.workflow, scene.connection)),
        findsOneWidget,
      );
      expect(find.text(goesBackText), isLoop ? findsOneWidget : findsNothing);
      expect(find.text(roundsLabel), isLoop ? findsOneWidget : findsNothing);
      expect(
        find.text(loopOutcomeHint),
        isLoop ? findsOneWidget : findsNothing,
      );
      expect(
        find.text(describeForwardOutcomeHint(fromName)),
        isLoop ? findsNothing : findsOneWidget,
      );
    }
  });

  testWidgets('test_connection_settings_panel_build_property_saved_values', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(118211);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomConnectionScene(random);
      await _pumpPanel(tester, random, ConnectionPanelLog(), scene);

      expect(
        findShownOutcomeField(tester).controller?.text,
        scene.connection.condition ?? '',
      );
      expect(findShownOutcomeProblem(tester), isNull);
      final int? roundLimit = scene.connection.roundLimit;
      if (roundLimit != null) {
        expect(find.text(describeRoundLimitChoice(roundLimit)), findsWidgets);
      }
    }
  });

  testWidgets(
    'test_connection_settings_panel_build_property_buttons_act_once',
    (WidgetTester tester) async {
      final Random random = seededRandom(118212);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final ConnectionPanelLog log = ConnectionPanelLog();
        await _pumpPanel(tester, random, log, randomConnectionScene(random));
        final bool removesFirst = random.nextBool();
        final List<String> labels = removesFirst
            ? <String>[removeConnectionLabel, _doneLabel]
            : <String>[_doneLabel, removeConnectionLabel];

        for (final String label in labels) {
          await tester.ensureVisible(find.text(label));
          await tester.tap(find.text(label));
          await tester.pump();
        }

        expect(
          log.events,
          removesFirst
              ? <String>[removedEvent, doneEvent]
              : <String>[doneEvent, removedEvent],
        );
        expect(log.changes, isEmpty);
      }
    },
  );

  testWidgets(
    'test_connection_settings_panel_build_property_rounds_keep_outcome',
    (WidgetTester tester) async {
      final Random random = seededRandom(118213);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final ConnectionScene scene = randomLoopScene(random);
        final ConnectionPanelLog log = ConnectionPanelLog();
        final int picked = 1 + scene.connection.roundLimit! % mostLoopRounds;
        await _pumpPanel(tester, random, log, scene);

        await tester.ensureVisible(
          find.byType(DropdownButton<RoundLimitChoice>),
        );
        await tester.tap(find.byType(DropdownButton<RoundLimitChoice>));
        await pumpFrames(tester);
        await tester.tap(find.text(describeRoundLimitChoice(picked)).last);
        await pumpFrames(tester);

        expect(log.changes, <AgentConnection>[
          scene.connection.withRoundLimit(picked),
        ]);
        expect(log.changes.single.condition, scene.connection.condition);
      }
    },
  );
}
