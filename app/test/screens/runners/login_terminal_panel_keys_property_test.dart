import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import '../support/login_terminal_panel_harness.dart';

const List<LoginTerminalState> _endedStates = <LoginTerminalState>[
  LoginTerminalState.finished,
  LoginTerminalState.failed,
];

Future<RecordedTerminalActions> _pumpRunningPanel(
  WidgetTester tester,
  Random random,
) async {
  final RecordedTerminalActions actions = RecordedTerminalActions();
  await pumpRecordedPanel(
    tester,
    random,
    randomLoginTerminal(random, state: LoginTerminalState.running),
    actions,
  );
  return actions;
}

Finder _findSend() => find.widgetWithText(AppButton, sendLabel);

String _readField(WidgetTester tester) {
  return tester.widget<TextField>(find.byType(TextField)).controller!.text;
}

Future<void> _tapSend(WidgetTester tester) async {
  await tester.ensureVisible(_findSend());
  await tester.tap(_findSend());
  await tester.pump();
}

Future<void> _pressEnter(WidgetTester tester) async {
  await tester.showKeyboard(find.byType(TextField));
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  testWidgets('test_build_keys_row_property_field_keeps_pasted_codes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpRunningPanel(tester, random);

      final TextField field = tester.widget(find.byType(TextField));
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.decoration!.hintText, terminalPlaceholder);
      expect(find.text(terminalPlaceholder), findsOneWidget);
    }
  });

  testWidgets('test_build_keys_row_property_send_sits_right_of_the_field', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordedTerminalActions actions = RecordedTerminalActions();
      final double width = await pumpRecordedPanel(
        tester,
        random,
        randomLoginTerminal(random, state: LoginTerminalState.running),
        actions,
      );

      final Rect field = tester.getRect(find.byType(TextField));
      final Rect send = tester.getRect(_findSend());
      final double controlHeight = AppSizes.controlHeightFor(
        densityMeantByWidth(width),
      );
      expect(send.height, controlHeight, reason: 'width $width');
      expect(send.left, greaterThanOrEqualTo(field.right));
      expect(send.top, field.top);
    }
  });

  testWidgets('test_build_keys_row_property_ended_logins_take_no_keys', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordedTerminalActions actions = RecordedTerminalActions();
      await pumpRecordedPanel(
        tester,
        random,
        randomLoginTerminal(random, state: pickOne(random, _endedStates)),
        actions,
      );

      expect(find.byType(TextField), findsNothing);
      expect(_findSend(), findsNothing);
      expect(actions.typedKeys, isEmpty);
    }
  });

  testWidgets('test_send_keys_property_send_types_text_and_enter_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108704);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordedTerminalActions actions = await _pumpRunningPanel(
        tester,
        random,
      );
      final String typed = randomText(random);
      await tester.enterText(find.byType(TextField), typed);

      await _tapSend(tester);

      expect(actions.typedKeys, <String>['$typed$enterKey']);
      expect(_readField(tester), isEmpty);
    }
  });

  testWidgets('test_send_keys_property_enter_acts_like_send', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108705);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String typed = randomText(random);
      final RecordedTerminalActions bySend = await _pumpRunningPanel(
        tester,
        random,
      );
      await tester.enterText(find.byType(TextField), typed);
      await _tapSend(tester);

      final RecordedTerminalActions byEnter = await _pumpRunningPanel(
        tester,
        random,
      );
      await tester.enterText(find.byType(TextField), typed);
      await _pressEnter(tester);

      expect(byEnter.typedKeys, bySend.typedKeys);
      expect(_readField(tester), isEmpty);
    }
  });

  testWidgets('test_send_keys_property_entries_arrive_in_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108706);
    final RecordedTerminalActions actions = await _pumpRunningPanel(
      tester,
      random,
    );
    final List<String> expected = <String>[];

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String typed = random.nextInt(3) == 0 ? '' : randomText(random);
      if (typed.isNotEmpty) {
        await tester.enterText(find.byType(TextField), typed);
      }

      await _tapSend(tester);
      expected.add('$typed$enterKey');
    }

    expect(actions.typedKeys, expected);
    expect(actions.closeCount, 0);
  });
}
