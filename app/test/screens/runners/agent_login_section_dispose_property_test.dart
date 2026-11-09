import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/runners/login_terminal_panel.dart';

import '../../support/random_inputs.dart';
import 'agent_login_probe.dart';

Future<RecordingAgentLoginRepository> _pumpOne(
  WidgetTester tester,
  Random random, {
  required AgentPlace place,
}) async {
  final RecordingAgentLoginRepository repository = buildLoginRepository(
    randomLoginStatus(random),
  );
  await pumpLoginSections(
    tester,
    random,
    places: <AgentPlace>[place],
    repository: repository,
  );
  return repository;
}

void main() {
  testWidgets('test_agent_login_section_dispose_property_closes_its_own_'
      'terminal', (WidgetTester tester) async {
    final Random random = seededRandom(108510);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final RecordingAgentLoginRepository repository = await _pumpOne(
        tester,
        random,
        place: place,
      );
      await repository.stored.openTerminal(place);
      await tester.pump();
      expect(find.byType(LoginTerminalPanel), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(repository.terminalCloses, 1);
      expect(repository.findTerminal(), isNull);
    }
  });

  testWidgets('test_agent_login_section_dispose_property_leaves_other_'
      'places_terminal', (WidgetTester tester) async {
    final Random random = seededRandom(108511);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentPlace other = place == AgentPlace.container
          ? AgentPlace.localProcess
          : AgentPlace.container;
      final RecordingAgentLoginRepository repository = await _pumpOne(
        tester,
        random,
        place: place,
      );
      await repository.stored.openTerminal(other);
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(repository.terminalCloses, 0);
      expect(repository.findTerminal()?.place, other);
    }
  });

  testWidgets('test_agent_login_section_dispose_property_without_a_'
      'terminal_closes_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(108512);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordingAgentLoginRepository repository = await _pumpOne(
        tester,
        random,
        place: pickOne(random, AgentPlace.values),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.terminalCloses, 0);
    }
  });
}
