import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/blinking_cursor.dart';

import '../../support/random_inputs.dart';
import '../support/login_terminal_panel_harness.dart';

const List<String> _hostileLines = <String>['', ' ', '\t', 'é', '​'];

LoginTerminal _randomTerminal(Random random) {
  return randomLoginTerminal(
    random,
    state: pickOne(random, LoginTerminalState.values),
  );
}

Future<LoginTerminal> _pumpRandomTerminal(
  WidgetTester tester,
  Random random,
) async {
  final LoginTerminal terminal = _randomTerminal(random);
  await pumpRecordedPanel(tester, random, terminal, RecordedTerminalActions());
  return terminal;
}

List<int> _findCursorLines(WidgetTester tester) {
  final List<int> cursorLines = <int>[];
  final int lineCount = findTerminalLines().evaluate().length;
  for (int index = 0; index < lineCount; index += 1) {
    final Finder cursor = find.descendant(
      of: findTerminalLines().at(index),
      matching: find.byType(BlinkingCursor),
    );
    if (cursor.evaluate().isNotEmpty) {
      cursorLines.add(index);
    }
  }
  return cursorLines;
}

int _countShownLines() => findTerminalLines().evaluate().length;

Finder _findScreen() {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is Semantics && widget.properties.label == terminalLabel,
  );
}

TextSpan _readLineSpan(WidgetTester tester, int index) {
  final Text line = tester.widget<Text>(findTerminalLines().at(index));
  return line.textSpan! as TextSpan;
}

void main() {
  testWidgets('test_build_screen_property_cursor_sits_on_the_newest_line', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final LoginTerminal terminal = await _pumpRandomTerminal(tester, random);

      final List<int> expected = <int>[
        if (terminal.state == LoginTerminalState.running)
          terminal.lines.length,
      ];
      expect(_findCursorLines(tester), expected);
    }
  });

  testWidgets('test_build_screen_property_problem_is_last_and_in_danger', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final LoginTerminal terminal = await _pumpRandomTerminal(tester, random);
      final List<String> shown = readTerminalLines(tester);
      final int lastIndex = shown.length - 1;

      for (int index = 0; index < shown.length; index += 1) {
        final bool isProblem = terminal.problem != null && index == lastIndex;
        final Color color = isProblem ? AppColors.danger : AppColors.ink;
        expect(_readLineSpan(tester, index).style!.color, color);
      }
      if (terminal.problem != null) {
        expect(shown.last, terminal.problem);
      }
    }
  });

  testWidgets('test_build_screen_property_newest_line_stays_in_view', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final LoginTerminal terminal = await _pumpRandomTerminal(tester, random);

      final Finder screen = _findScreen();
      final Rect screenRect = tester.getRect(screen);
      final Rect newestLine = tester.getRect(findTerminalLines().last);
      expect(screenRect.height, lessThanOrEqualTo(AppSizes.logMaximumHeight));
      expect(newestLine.bottom, lessThanOrEqualTo(screenRect.bottom + 0.5));
      expect(newestLine.top, greaterThanOrEqualTo(screenRect.top - 0.5));
      expect(terminal.lines.length + 1, lessThanOrEqualTo(_countShownLines()));
    }
  });

  testWidgets('test_terminal_line_constructor_property_one_line_per_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final LoginTerminal terminal = await _pumpRandomTerminal(tester, random);

      final int problemLines = terminal.problem == null ? 0 : 1;
      expect(_countShownLines(), 1 + terminal.lines.length + problemLines);
    }
  });

  testWidgets('test_terminal_line_constructor_property_keeps_hostile_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108605);
    final LoginTerminal terminal = LoginTerminal(
      place: randomLoginTerminal(
        random,
        state: LoginTerminalState.failed,
      ).place,
      command: ' claude  auth ',
      lines: _hostileLines,
      state: LoginTerminalState.failed,
      problem: ' ',
    );

    await pumpRecordedPanel(
      tester,
      random,
      terminal,
      RecordedTerminalActions(),
    );

    expect(readTerminalLines(tester), describeExpectedLines(terminal));
  });

  testWidgets('test_terminal_line_constructor_property_prompt_only_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpRandomTerminal(tester, random);

      int promptCount = 0;
      for (int index = 0; index < _countShownLines(); index += 1) {
        final TextSpan span = _readLineSpan(tester, index);
        final InlineSpan first = span.children!.first;
        if (first is TextSpan && first.text == commandPrompt) {
          promptCount += 1;
          expect(index, 0);
        }
      }
      expect(promptCount, 1);
    }
  });

  testWidgets('test_terminal_line_build_property_prompt_is_muted', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108607);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final LoginTerminal terminal = await _pumpRandomTerminal(tester, random);

      final List<InlineSpan> parts = _readLineSpan(tester, 0).children!;
      final TextSpan prompt = parts.first as TextSpan;
      final TextSpan command = parts[2] as TextSpan;
      expect(prompt.style!.color, AppColors.inkMuted);
      expect(command.text, terminal.command);
      expect(command.style, isNull);
    }
  });

  testWidgets('test_terminal_line_build_property_lines_share_a_margin', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108608);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpRandomTerminal(tester, random);

      final double firstLeft = tester.getRect(findTerminalLines().first).left;
      for (int index = 0; index < _countShownLines(); index += 1) {
        final Rect line = tester.getRect(findTerminalLines().at(index));
        expect(line.left, firstLeft);
      }
      final Rect panel = tester.getRect(_findScreen());
      expect(firstLeft - panel.left, greaterThanOrEqualTo(AppSpacing.space4));
    }
  });

  testWidgets('test_terminal_line_build_property_cursor_follows_the_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108609);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final LoginTerminal terminal = randomLoginTerminal(
        random,
        state: LoginTerminalState.running,
      );
      await pumpRecordedPanel(
        tester,
        random,
        terminal,
        RecordedTerminalActions(),
      );

      final int cursorLine = _findCursorLines(tester).single;
      final List<InlineSpan> parts = _readLineSpan(
        tester,
        cursorLine,
      ).children!;
      expect(parts.last, isA<WidgetSpan>());
      expect(find.byType(BlinkingCursor), findsOneWidget);
    }
  });
}
