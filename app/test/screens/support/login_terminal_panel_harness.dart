import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/screens/runners/login_terminal_panel.dart';
import 'package:agent_orchestration/widgets/code_block.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'runner_settings_screen_checks.dart';

const String maskedTokenLine = 'Your token: sk-ant-••••••••';
const String enterKey = '\r';
const int _mostLines = 60;
const List<String> _loginCommands = <String>[
  'claude auth login',
  'claude setup-token',
];

final class RecordedTerminalActions {
  final List<String> typedKeys = <String>[];
  int closeCount = 0;

  Future<void> type(String keys) async {
    typedKeys.add(keys);
  }

  void close() {
    closeCount += 1;
  }
}

LoginTerminal randomLoginTerminal(
  Random random, {
  required LoginTerminalState state,
}) {
  final int lineCount = random.nextInt(_mostLines);
  final List<String> lines = <String>[];
  for (int i = 0; i < lineCount; i += 1) {
    lines.add(
      random.nextInt(5) == 0 ? maskedTokenLine : randomHostileText(random),
    );
  }

  return LoginTerminal(
    place: pickOne(random, AgentPlace.values),
    command: pickOne(random, _loginCommands),
    lines: lines,
    state: state,
    problem: random.nextBool() ? '${randomHostileText(random)}!' : null,
  );
}

LoginTerminalPanel buildRecordedPanel(
  LoginTerminal terminal,
  RecordedTerminalActions actions,
) {
  return LoginTerminalPanel(
    terminal: terminal,
    onType: actions.type,
    onClose: actions.close,
  );
}

Future<double> pumpRecordedPanel(
  WidgetTester tester,
  Random random,
  LoginTerminal terminal,
  RecordedTerminalActions actions,
) {
  return pumpAtRandomWidth(
    tester,
    random,
    buildRecordedPanel(terminal, actions),
  );
}

Finder findTerminalLines() {
  return find.descendant(
    of: find.byType(CodePanel),
    matching: find.byType(Text),
  );
}

List<String> readTerminalLines(WidgetTester tester) {
  final List<String> shownLines = <String>[];
  for (final Text line in tester.widgetList<Text>(findTerminalLines())) {
    shownLines.add(line.textSpan!.toPlainText(includePlaceholders: false));
  }
  return shownLines;
}

List<String> describeExpectedLines(LoginTerminal terminal) {
  return <String>[
    '$commandPrompt${terminal.command}',
    ...terminal.lines,
    ?terminal.problem,
  ];
}
