import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/screens/shared/agent_login_pointer.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

final class _ConnectCounter {
  int connections = 0;

  void connect() {
    connections += 1;
  }
}

AgentLoginPointer _randomPointer(Random random, _ConnectCounter counter) {
  return AgentLoginPointer(
    hint: 'Hint ${randomText(random)}',
    onConnect: counter.connect,
  );
}

Future<void> _pumpPointerParts(
  WidgetTester tester,
  Random random,
  AgentLoginPointer? pointer,
) async {
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ...describeAgentLoginPointer(pointer),
        Wrap(children: offerAgentLoginConnection(pointer)),
      ],
    ),
  );
}

void main() {
  testWidgets('test_describe_agent_login_pointer_property_hint_shows_at_'
      'any_width', (WidgetTester tester) async {
    final Random random = seededRandom(111201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentLoginPointer pointer = _randomPointer(
        random,
        _ConnectCounter(),
      );

      await _pumpPointerParts(tester, random, pointer);

      expect(tester.takeException(), isNull);
      expect(find.text(pointer.hint), findsOneWidget);
    }
  });

  testWidgets('test_describe_agent_login_pointer_property_nothing_shows_'
      'without_a_pointer', (WidgetTester tester) async {
    final Random random = seededRandom(111202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpPointerParts(tester, random, null);

      expect(tester.takeException(), isNull);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(AppButton), findsNothing);
    }
  });

  testWidgets('test_offer_agent_login_connection_property_tap_connects_'
      'once', (WidgetTester tester) async {
    final Random random = seededRandom(111203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ConnectCounter counter = _ConnectCounter();
      await _pumpPointerParts(tester, random, _randomPointer(random, counter));

      await tapVisible(tester, find.text(connectClaudeCodeLabel));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(counter.connections, 1);
    }
  });

  testWidgets('test_offer_agent_login_connection_property_names_the_'
      'connect_action', (WidgetTester tester) async {
    final Random random = seededRandom(111204);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ConnectCounter counter = _ConnectCounter();
      final AgentLoginPointer pointer = _randomPointer(random, counter);
      await _pumpPointerParts(tester, random, pointer);

      final AppButton button = tester.widget<AppButton>(
        find.byType(AppButton),
      );

      expect(button.label, connectClaudeCodeLabel);
      expect(button.onPressed, pointer.onConnect);
      expect(counter.connections, 0);
    }
  });
}
