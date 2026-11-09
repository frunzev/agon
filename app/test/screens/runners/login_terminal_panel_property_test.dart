import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/screens/runners/login_terminal_panel.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import '../support/login_terminal_panel_harness.dart';

LoginTerminal _randomTerminal(Random random) {
  return randomLoginTerminal(
    random,
    state: pickOne(random, LoginTerminalState.values),
  );
}

LoginTerminal _randomRunningTerminal(Random random) {
  return randomLoginTerminal(random, state: LoginTerminalState.running);
}

String _readField(WidgetTester tester, Finder field) {
  return tester.widget<TextField>(field).controller!.text;
}

Future<void> _pumpPanels(WidgetTester tester, List<Widget> panels) async {
  await pumpScrollableAtWidth(
    tester,
    width: desktopWidth,
    child: Column(children: panels),
  );
}

void main() {
  test('test_login_terminal_panel_constructor_property_keeps_fields', () {
    final Random random = seededRandom(108501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LoginTerminal terminal = _randomTerminal(random);
      final RecordedTerminalActions actions = RecordedTerminalActions();
      final Key key = ValueKey<int>(i);

      final LoginTerminalPanel panel = LoginTerminalPanel(
        terminal: terminal,
        onType: actions.type,
        onClose: actions.close,
        key: key,
      );

      expect(panel.terminal, same(terminal));
      expect(panel.key, key);
      expect(actions.typedKeys, isEmpty);
      expect(actions.closeCount, 0);
    }
  });

  test('test_login_terminal_panel_constructor_property_calls_nothing', () {
    final Random random = seededRandom(108502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordedTerminalActions actions = RecordedTerminalActions();
      final LoginTerminalPanel panel = buildRecordedPanel(
        _randomTerminal(random),
        actions,
      );

      expect(panel.key, isNull);
      expect(actions.typedKeys, isEmpty);
      expect(actions.closeCount, 0);
    }
  });

  test('test_login_terminal_panel_constructor_property_any_state', () {
    final Random random = seededRandom(108503);

    for (final LoginTerminalState state in LoginTerminalState.values) {
      final LoginTerminal terminal = randomLoginTerminal(random, state: state);
      final LoginTerminalPanel panel = buildRecordedPanel(
        terminal,
        RecordedTerminalActions(),
      );

      expect(panel.terminal.state, state);
      expect(panel.terminal.lines, terminal.lines);
    }
  });

  testWidgets('test_login_terminal_panel_create_state_property_own_state', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String typed = 'code-$i';
      await _pumpPanels(tester, <Widget>[
        buildRecordedPanel(
          _randomRunningTerminal(random),
          RecordedTerminalActions(),
        ),
        buildRecordedPanel(
          _randomRunningTerminal(random),
          RecordedTerminalActions(),
        ),
      ]);

      await tester.enterText(find.byType(TextField).first, typed);
      await tester.pump();

      expect(_readField(tester, find.byType(TextField).first), typed);
      expect(_readField(tester, find.byType(TextField).last), isEmpty);
    }
  });

  testWidgets('test_login_terminal_panel_create_state_property_polls_keep', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108505);
    final RecordedTerminalActions actions = RecordedTerminalActions();
    await _pumpPanels(tester, <Widget>[
      buildRecordedPanel(_randomRunningTerminal(random), actions),
    ]);
    await tester.enterText(find.byType(TextField), 'half typed');

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final LoginTerminal polled = _randomRunningTerminal(random);
      await _pumpPanels(tester, <Widget>[buildRecordedPanel(polled, actions)]);

      expect(_readField(tester, find.byType(TextField)), 'half typed');
      expect(readTerminalLines(tester), describeExpectedLines(polled));
    }
    expect(actions.typedKeys, isEmpty);
  });

  testWidgets('test_login_terminal_panel_create_state_property_new_key', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108506);
    final LoginTerminal terminal = _randomRunningTerminal(random);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpPanels(tester, <Widget>[
        KeyedSubtree(
          key: ValueKey<int>(i),
          child: buildRecordedPanel(terminal, RecordedTerminalActions()),
        ),
      ]);

      expect(_readField(tester, find.byType(TextField)), isEmpty);
      await tester.enterText(find.byType(TextField), 'typed $i');
    }
  });

  testWidgets('test_login_terminal_panel_dispose_property_never_sends_keys', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108507);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordedTerminalActions actions = RecordedTerminalActions();
      await pumpRecordedPanel(
        tester,
        random,
        _randomRunningTerminal(random),
        actions,
      );
      await tester.enterText(find.byType(TextField), randomText(random));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
      expect(actions.typedKeys, isEmpty);
      expect(actions.closeCount, 0);
    }
  });

  testWidgets('test_login_terminal_panel_dispose_property_reopened_is_empty', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108508);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final LoginTerminal terminal = _randomRunningTerminal(random);
      await pumpRecordedPanel(
        tester,
        random,
        terminal,
        RecordedTerminalActions(),
      );
      await tester.enterText(find.byType(TextField), 'left behind $i');
      await tester.pumpWidget(const SizedBox.shrink());

      await pumpRecordedPanel(
        tester,
        random,
        terminal,
        RecordedTerminalActions(),
      );

      expect(_readField(tester, find.byType(TextField)), isEmpty);
    }
  });

  testWidgets(
    'test_login_terminal_panel_dispose_property_any_state_is_clean',
    (WidgetTester tester) async {
      final Random random = seededRandom(108509);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        await pumpRecordedPanel(
          tester,
          random,
          _randomTerminal(random),
          RecordedTerminalActions(),
        );

        await tester.pumpWidget(const SizedBox.shrink());

        expect(tester.takeException(), isNull);
        expect(find.byType(LoginTerminalPanel), findsNothing);
      }
    },
  );

  testWidgets('test_login_terminal_panel_build_property_field_only_if_live', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108510);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final LoginTerminal terminal = _randomTerminal(random);
      await pumpRecordedPanel(
        tester,
        random,
        terminal,
        RecordedTerminalActions(),
      );

      final bool isRunning = terminal.state == LoginTerminalState.running;
      final Matcher shownIfRunning = isRunning ? findsOneWidget : findsNothing;
      expect(find.byType(TextField), shownIfRunning);
      expect(find.text(terminalHint), shownIfRunning);
      expect(find.widgetWithText(AppButton, sendLabel), shownIfRunning);
      expect(find.widgetWithText(AppButton, closeLabel), findsOneWidget);
    }
  });

  testWidgets('test_login_terminal_panel_build_property_close_closes_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108511);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordedTerminalActions actions = RecordedTerminalActions();
      await pumpRecordedPanel(
        tester,
        random,
        _randomTerminal(random),
        actions,
      );

      final Finder close = find.widgetWithText(AppButton, closeLabel);
      await tester.ensureVisible(close);
      await tester.tap(close);
      await tester.pump();

      expect(actions.closeCount, 1);
      expect(actions.typedKeys, isEmpty);
    }
  });

  testWidgets('test_login_terminal_panel_build_property_shows_only_its_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108512);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final LoginTerminal terminal = _randomTerminal(random);
      await pumpRecordedPanel(
        tester,
        random,
        terminal,
        RecordedTerminalActions(),
      );

      expect(readTerminalLines(tester), describeExpectedLines(terminal));
      expect(find.textContaining('sk-ant-oat'), findsNothing);
    }
  });
}
