import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/agent_login_repository.dart';
import 'package:agent_orchestration/screens/runners/agent_login_section.dart';
import 'package:agent_orchestration/screens/runners/login_terminal_panel.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import '../support/planned_refusal.dart';

final class RecordingAgentLoginRepository extends ChangeNotifier
    implements AgentLoginRepository {
  RecordingAgentLoginRepository({required this.stored}) {
    stored.addListener(notifyListeners);
  }

  final FakeAgentLoginRepository stored;
  final PlannedRefusal refusal = PlannedRefusal();
  int statusChecks = 0;
  int terminalCloses = 0;
  bool isStatusHidden = false;

  void revealStatus() {
    isStatusHidden = false;
    notifyListeners();
  }

  @override
  AgentLoginStatus? findStatus() {
    if (isStatusHidden) {
      return null;
    }
    return stored.findStatus();
  }

  @override
  LoginTerminal? findTerminal() => stored.findTerminal();

  @override
  Future<void> checkStatus() {
    statusChecks += 1;
    return stored.checkStatus();
  }

  @override
  Future<void> openTerminal(AgentPlace place) {
    return refusal.refuseOr(() => stored.openTerminal(place));
  }

  @override
  Future<void> typeIntoTerminal(String keys) {
    return refusal.refuseOr(() => stored.typeIntoTerminal(keys));
  }

  @override
  Future<void> closeTerminal() {
    terminalCloses += 1;
    return refusal.refuseOr(stored.closeTerminal);
  }

  @override
  Future<void> saveApiKey(String apiKey) {
    return refusal.refuseOr(() => stored.saveApiKey(apiKey));
  }

  @override
  Future<void> forgetCredential() {
    return refusal.refuseOr(stored.forgetCredential);
  }
}

AgentLoginStatus randomLoginStatus(Random random) {
  return AgentLoginStatus(
    claudeLogin: pickOne(random, ClaudeLogin.values),
    containerCredential: random.nextBool()
        ? null
        : pickOne(random, AgentCredentialKind.values),
  );
}

RecordingAgentLoginRepository buildLoginRepository(AgentLoginStatus status) {
  return RecordingAgentLoginRepository(
    stored: FakeAgentLoginRepository(status: status),
  );
}

Future<void> pumpLoginSections(
  WidgetTester tester,
  Random random, {
  required List<AgentPlace> places,
  required AgentLoginRepository repository,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: Column(
      children: <Widget>[
        for (final AgentPlace place in places)
          AgentLoginSection(
            key: ValueKey<AgentPlace>(place),
            place: place,
            repository: repository,
          ),
      ],
    ),
  );
}

Future<void> tapLoginButton(WidgetTester tester, String label) async {
  final Finder button = find.widgetWithText(AppButton, label).last;
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await pumpFrames(tester);
}

Finder findTerminalField() {
  return find.descendant(
    of: find.byType(LoginTerminalPanel),
    matching: find.byType(TextField),
  );
}

Future<void> enterTerminalText(WidgetTester tester, String text) async {
  await tester.ensureVisible(findTerminalField());
  await tester.enterText(findTerminalField(), text);
  await tester.pump(settleTime);
}
