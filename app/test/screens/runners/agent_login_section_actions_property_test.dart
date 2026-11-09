import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/screens/runners/login_terminal_panel.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import 'agent_login_probe.dart';

const AgentLoginStatus _notLoggedIn = AgentLoginStatus(
  claudeLogin: ClaudeLogin.notLoggedIn,
  containerCredential: null,
);

typedef _ActionCase = ({AgentPlace place, AgentLoginStatus status});

_ActionCase _randomCaseWithActions(Random random) {
  while (true) {
    final AgentPlace place = pickOne(random, AgentPlace.values);
    final AgentLoginStatus status = randomLoginStatus(random);
    final List<AgentLoginAction> actions = chooseAgentLoginActions(
      place: place,
      status: status,
    );
    if (actions.isNotEmpty) {
      return (place: place, status: status);
    }
  }
}

Future<RecordingAgentLoginRepository> _pumpCase(
  WidgetTester tester,
  Random random,
  _ActionCase actionCase,
) async {
  final RecordingAgentLoginRepository repository = buildLoginRepository(
    actionCase.status,
  );
  await pumpLoginSections(
    tester,
    random,
    places: <AgentPlace>[actionCase.place],
    repository: repository,
  );
  return repository;
}

List<Object?> _describeLoginState(RecordingAgentLoginRepository repository) {
  final AgentLoginStatus? status = repository.findStatus();
  final LoginTerminal? terminal = repository.findTerminal();
  return <Object?>[
    status?.claudeLogin,
    status?.containerCredential,
    terminal?.place,
    terminal?.state,
    terminal?.lines.length,
  ];
}

void main() {
  testWidgets('test_agent_login_section_build_action_button_property_'
      'terminals_open_where_the_button_says', (WidgetTester tester) async {
    final Random random = seededRandom(108701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ActionCase actionCase = _randomCaseWithActions(random);
      final RecordingAgentLoginRepository repository = await _pumpCase(
        tester,
        random,
        actionCase,
      );
      final List<AgentLoginAction> actions = chooseAgentLoginActions(
        place: actionCase.place,
        status: actionCase.status,
      );
      final AgentLoginAction action = pickOne(random, actions);
      final bool opensTerminal =
          action == AgentLoginAction.logIn ||
          action == AgentLoginAction.connect;

      await tapLoginButton(tester, describeAgentLoginAction(action));

      final LoginTerminal? terminal = repository.findTerminal();
      expect(terminal?.place, opensTerminal ? actionCase.place : null);
      final Matcher panelShown = opensTerminal ? findsOneWidget : findsNothing;
      expect(find.byType(LoginTerminalPanel), panelShown);
    }
  });

  testWidgets('test_agent_login_section_build_action_button_property_'
      'starting_actions_are_primary', (WidgetTester tester) async {
    final Random random = seededRandom(108702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ActionCase actionCase = _randomCaseWithActions(random);
      await _pumpCase(tester, random, actionCase);

      for (final AgentLoginAction action in chooseAgentLoginActions(
        place: actionCase.place,
        status: actionCase.status,
      )) {
        final AppButton button = tester.widget<AppButton>(
          find.widgetWithText(AppButton, describeAgentLoginAction(action)),
        );
        final bool starts =
            action == AgentLoginAction.logIn ||
            action == AgentLoginAction.connect;
        expect(
          button.tone,
          starts ? ButtonTone.primary : ButtonTone.secondary,
        );
        expect(button.onPressed, isNotNull);
      }
    }
  });

  testWidgets('test_agent_login_section_build_action_button_property_'
      'disconnect_forgets_only_the_credential', (WidgetTester tester) async {
    final Random random = seededRandom(108703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentLoginStatus status = AgentLoginStatus(
        claudeLogin: pickOne(random, ClaudeLogin.values),
        containerCredential: pickOne(random, AgentCredentialKind.values),
      );
      final RecordingAgentLoginRepository repository = await _pumpCase(
        tester,
        random,
        (place: AgentPlace.container, status: status),
      );

      await tapLoginButton(tester, disconnectLabel);

      expect(repository.findStatus()?.containerCredential, isNull);
      expect(repository.findStatus()?.claudeLogin, status.claudeLogin);
      expect(repository.findTerminal(), isNull);
    }
  });

  testWidgets('test_agent_login_section_run_login_action_property_a_'
      'refusal_names_the_section', (WidgetTester tester) async {
    final Random random = seededRandom(108704);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ActionCase actionCase = _randomCaseWithActions(random);
      final RecordingAgentLoginRepository repository = await _pumpCase(
        tester,
        random,
        actionCase,
      );
      final AgentLoginAction action = pickOne(
        random,
        chooseAgentLoginActions(
          place: actionCase.place,
          status: actionCase.status,
        ),
      );
      if (action == AgentLoginAction.useApiKey) {
        continue;
      }
      final ExplainedRefusal planned = randomExplainedRefusal(random);
      repository.refusal.problem = planned.problem;
      final String label = describeAgentLoginAction(action);

      await tapLoginButton(tester, label);

      final String title = describeAgentLoginTitle(actionCase.place);
      expect(find.text(title), findsWidgets);
      expect(find.text('$label did not work'), findsOneWidget);
      expect(find.text(planned.explanation), findsOneWidget);
    }
  });

  testWidgets('test_agent_login_section_run_login_action_property_a_'
      'refusal_changes_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(108705);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ActionCase actionCase = _randomCaseWithActions(random);
      final RecordingAgentLoginRepository repository = await _pumpCase(
        tester,
        random,
        actionCase,
      );
      final AgentLoginAction action = pickOne(
        random,
        chooseAgentLoginActions(
          place: actionCase.place,
          status: actionCase.status,
        ),
      );
      final List<Object?> stateBefore = _describeLoginState(repository);
      repository.refusal.problem = randomExplainedRefusal(random).problem;

      await tapLoginButton(tester, describeAgentLoginAction(action));
      repository.refusal.problem = null;

      expect(_describeLoginState(repository), stateBefore);
    }
  });

  testWidgets('test_agent_login_section_run_login_action_property_typing_'
      'into_an_ended_login_is_refused', (WidgetTester tester) async {
    final Random random = seededRandom(108706);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordingAgentLoginRepository repository = await _pumpCase(
        tester,
        random,
        (place: AgentPlace.localProcess, status: _notLoggedIn),
      );
      await tapLoginButton(tester, logInLabel);
      final String code = 'code-${random.nextInt(100000)}';
      await enterTerminalText(tester, code);
      final Finder send = find.widgetWithText(AppButton, sendLabel);
      await tester.ensureVisible(send);
      await tester.pump();
      final String? problem = random.nextBool() ? 'stopped $i' : null;

      repository.stored.endTerminal(problem: problem);
      await tester.tap(send, warnIfMissed: false);
      await pumpFrames(tester);

      final LoginTerminal? terminal = repository.findTerminal();
      expect(find.text('$sendLabel did not work'), findsOneWidget);
      expect(terminal?.lines ?? const <String>[], isNot(contains(code)));
    }
  });
}
