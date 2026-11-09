import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/screens/runners/api_key_form.dart';
import 'package:agent_orchestration/screens/runners/login_terminal_panel.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'agent_login_probe.dart';

const int _stepsPerFlow = 8;

enum _FlowStep { action, endWell, endBadly, type, close, cancel, saveKey }

final class _LoginModel {
  _LoginModel({required this.place, required this.status});

  final AgentPlace place;
  AgentLoginStatus status;
  LoginTerminalState? terminal;
  bool isAskingForKey = false;

  List<AgentLoginAction> get shownActions {
    if (terminal != null || isAskingForKey) {
      return const <AgentLoginAction>[];
    }
    return chooseAgentLoginActions(place: place, status: status);
  }

  void keepCredential(AgentCredentialKind? credential) {
    status = AgentLoginStatus(
      claudeLogin: status.claudeLogin,
      containerCredential: credential,
    );
  }

  void endWell() {
    terminal = null;
    if (place == AgentPlace.container) {
      keepCredential(AgentCredentialKind.longLivedToken);
      return;
    }
    status = AgentLoginStatus(
      claudeLogin: ClaudeLogin.loggedIn,
      containerCredential: status.containerCredential,
    );
  }
}

List<_FlowStep> _listPossibleSteps(_LoginModel model) {
  final LoginTerminalState? terminal = model.terminal;
  return <_FlowStep>[
    if (model.shownActions.isNotEmpty) _FlowStep.action,
    if (terminal == LoginTerminalState.running) _FlowStep.endWell,
    if (terminal == LoginTerminalState.running) _FlowStep.endBadly,
    if (terminal == LoginTerminalState.running) _FlowStep.type,
    if (terminal != null) _FlowStep.close,
    if (terminal == null && model.isAskingForKey) _FlowStep.cancel,
    if (terminal == null && model.isAskingForKey) _FlowStep.saveKey,
  ];
}

Future<void> _takeAction(
  WidgetTester tester,
  Random random,
  _LoginModel model,
) async {
  final AgentLoginAction action = pickOne(random, model.shownActions);
  await tapLoginButton(tester, describeAgentLoginAction(action));
  switch (action) {
    case AgentLoginAction.logIn:
    case AgentLoginAction.connect:
      model.terminal = LoginTerminalState.running;
    case AgentLoginAction.useApiKey:
      model.isAskingForKey = true;
    case AgentLoginAction.disconnect:
      model.keepCredential(null);
  }
}

Future<void> _saveKey(
  WidgetTester tester,
  Random random,
  _LoginModel model,
) async {
  final bool isValid = random.nextBool();
  final String key = isValid ? 'sk-ant-${random.nextInt(1000)}' : 'sk ant';
  await enterFieldText(tester, label: apiKeyFieldLabel, text: key);
  await tapLoginButton(tester, saveKeyLabel);
  if (isValid) {
    model.keepCredential(AgentCredentialKind.apiKey);
    model.isAskingForKey = false;
    return;
  }
  await tapLoginButton(tester, closeLabel);
}

Future<void> _takeStep(
  WidgetTester tester,
  Random random,
  _LoginModel model,
  RecordingAgentLoginRepository repository,
) async {
  final _FlowStep step = pickOne(random, _listPossibleSteps(model));
  switch (step) {
    case _FlowStep.action:
      await _takeAction(tester, random, model);
    case _FlowStep.endWell:
      repository.stored.endTerminal(problem: null);
      model.endWell();
      await pumpFrames(tester);
    case _FlowStep.endBadly:
      repository.stored.endTerminal(problem: 'failed ${random.nextInt(99)}');
      model.terminal = LoginTerminalState.failed;
      await pumpFrames(tester);
    case _FlowStep.type:
      await enterTerminalText(tester, 'keys ${random.nextInt(99)}');
      await tapLoginButton(tester, sendLabel);
    case _FlowStep.close:
      await tapLoginButton(tester, closeLabel);
      model.terminal = null;
    case _FlowStep.cancel:
      await tapLoginButton(tester, cancelLabel);
      model.isAskingForKey = false;
    case _FlowStep.saveKey:
      await _saveKey(tester, random, model);
  }
}

void _expectShownModel(WidgetTester tester, _LoginModel model) {
  final AgentLoginDescription description = describeAgentLogin(
    place: model.place,
    status: model.status,
  );
  final bool isRunning = model.terminal == LoginTerminalState.running;
  final bool showsForm = model.terminal == null && model.isAskingForKey;
  expect(find.text(description.statusText), findsOneWidget);
  expect(
    find.byType(LoginTerminalPanel),
    model.terminal == null ? findsNothing : findsOneWidget,
  );
  expect(find.text(sendLabel), isRunning ? findsOneWidget : findsNothing);
  expect(find.byType(ApiKeyForm), showsForm ? findsOneWidget : findsNothing);
  for (final AgentLoginAction action in AgentLoginAction.values) {
    final Finder button = find.widgetWithText(
      AppButton,
      describeAgentLoginAction(action),
    );
    final bool isShown = model.shownActions.contains(action);
    expect(button, isShown ? findsOneWidget : findsNothing);
  }
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('test_agent_login_section_build_section_property_a_random_'
      'login_flow_matches_the_model', (WidgetTester tester) async {
    final Random random = seededRandom(108901);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentLoginStatus status = randomLoginStatus(random);
      final _LoginModel model = _LoginModel(
        place: pickOne(random, AgentPlace.values),
        status: status,
      );
      final RecordingAgentLoginRepository repository = buildLoginRepository(
        status,
      );
      await pumpLoginSections(
        tester,
        random,
        places: <AgentPlace>[model.place],
        repository: repository,
      );
      _expectShownModel(tester, model);

      for (int step = 0; step < _stepsPerFlow; step += 1) {
        if (_listPossibleSteps(model).isEmpty) {
          break;
        }
        await _takeStep(tester, random, model, repository);
        _expectShownModel(tester, model);
      }
    }
  });
}
