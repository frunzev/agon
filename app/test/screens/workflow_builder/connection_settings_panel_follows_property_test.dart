import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/connection_panel_harness.dart';
import 'support/random_connection_scenes.dart';

const List<String> _paddings = <String>[' ', '  ', '\t'];
const String _outsideOutcomePrefix = 'outside-';
const String _malformedOutcome = 'Not An Outcome!';

final class _FollowingHost {
  _FollowingHost(ConnectionScene scene)
    : shownScene = ValueNotifier<ConnectionScene>(scene);

  final ValueNotifier<ConnectionScene> shownScene;

  void showConnection(AgentConnection edited) {
    final ConnectionScene current = shownScene.value;
    shownScene.value = ConnectionScene(
      workflow: current.replaceConnection(edited),
      connection: edited,
    );
  }

  Widget build() {
    return ValueListenableBuilder<ConnectionScene>(
      valueListenable: shownScene,
      builder: (BuildContext _, ConnectionScene scene, Widget? _) =>
          ConnectionSettingsPanel(
            key: const ValueKey<String>('followed-connection'),
            workflow: scene.workflow,
            connection: scene.connection,
            onConnectionChanged: showConnection,
            onRemoved: () {},
            onDone: () {},
          ),
    );
  }
}

Future<_FollowingHost> _pumpFollowingPanel(
  WidgetTester tester,
  Random random,
  ConnectionScene scene,
) async {
  final _FollowingHost host = _FollowingHost(scene);
  addTearDown(host.shownScene.dispose);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: host.build(),
  );
  return host;
}

String _readShownOutcome(WidgetTester tester) {
  return findShownOutcomeField(tester).controller!.text;
}

String _randomOutsideOutcome(Random random) {
  return '$_outsideOutcomePrefix${random.nextInt(999)}';
}

void main() {
  testWidgets('test_connection_settings_panel_did_update_widget_property_'
      'outside_outcome_replaces_the_text', (WidgetTester tester) async {
    final Random random = seededRandom(1190901);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomConnectionScene(random);
      final _FollowingHost host = await _pumpFollowingPanel(
        tester,
        random,
        scene,
      );
      final String? outsideOutcome =
          scene.connection.isLoop || random.nextBool()
          ? _randomOutsideOutcome(random)
          : null;

      host.showConnection(scene.connection.withCondition(outsideOutcome));
      await tester.pump();

      expect(_readShownOutcome(tester), outsideOutcome ?? '');
      expect(findShownOutcomeProblem(tester), isNull);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_connection_settings_panel_did_update_widget_property_'
      'saved_padding_stays_as_typed', (WidgetTester tester) async {
    final Random random = seededRandom(1190902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomConnectionScene(random);
      await _pumpFollowingPanel(tester, random, scene);
      final String outcome = _randomOutsideOutcome(random);
      final String typed =
          '${pickOne(random, _paddings)}$outcome${pickOne(random, _paddings)}';

      await tester.enterText(find.byType(TextField), typed);
      await tester.pump();

      expect(_readShownOutcome(tester), typed);
      expect(findShownOutcomeProblem(tester), isNull);
    }
  });

  testWidgets('test_connection_settings_panel_did_update_widget_property_'
      'shown_problem_keeps_what_was_typed', (WidgetTester tester) async {
    final Random random = seededRandom(1190903);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ConnectionScene scene = randomLoopScene(random);
      final _FollowingHost host = await _pumpFollowingPanel(
        tester,
        random,
        scene,
      );

      await tester.enterText(find.byType(TextField), _malformedOutcome);
      await tester.pump();
      final String? problem = findShownOutcomeProblem(tester);
      final int rounds = fewestLoopRounds + random.nextInt(mostLoopRounds);
      host.showConnection(scene.connection.withRoundLimit(rounds));
      await tester.pump();

      expect(problem, isNotNull);
      expect(_readShownOutcome(tester), _malformedOutcome);
      expect(findShownOutcomeProblem(tester), problem);
    }
  });
}
