import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/screens/runners/agent_login_section.dart';
import 'package:agent_orchestration/screens/runners/api_key_form.dart';
import 'package:agent_orchestration/screens/runners/login_terminal_panel.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/random_inputs.dart';
import 'agent_login_probe.dart';

final Set<String> _actionLabels = <String>{
  for (final AgentLoginAction action in AgentLoginAction.values)
    describeAgentLoginAction(action),
};

String _describeLoginCommand(AgentPlace place) {
  return switch (place) {
    AgentPlace.container => 'claude setup-token',
    AgentPlace.localProcess => 'claude auth login',
  };
}

AgentPlace _otherPlace(AgentPlace place) {
  if (place == AgentPlace.container) {
    return AgentPlace.localProcess;
  }
  return AgentPlace.container;
}

Finder _findInSection(AgentPlace place, Finder matching) {
  return find.descendant(
    of: find.byKey(ValueKey<AgentPlace>(place)),
    matching: matching,
  );
}

List<String> _readActionLabels(WidgetTester tester, AgentPlace place) {
  final Finder buttons = _findInSection(place, find.byType(AppButton));
  return <String>[
    for (final AppButton button in tester.widgetList<AppButton>(buttons))
      if (_actionLabels.contains(button.label)) button.label,
  ];
}

void main() {
  testWidgets('test_agent_login_section_find_own_terminal_property_shows_'
      'its_own_terminal', (WidgetTester tester) async {
    final Random random = seededRandom(108601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final RecordingAgentLoginRepository repository = buildLoginRepository(
        randomLoginStatus(random),
      );
      await pumpLoginSections(
        tester,
        random,
        places: <AgentPlace>[place],
        repository: repository,
      );

      await repository.stored.openTerminal(place);
      await tester.pump();

      expect(find.byType(LoginTerminalPanel), findsOneWidget);
      final String command = _describeLoginCommand(place);
      expect(find.textContaining(command), findsOneWidget);
    }
  });

  testWidgets('test_agent_login_section_find_own_terminal_property_hides_'
      'the_other_places_terminal', (WidgetTester tester) async {
    final Random random = seededRandom(108602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginStatus status = randomLoginStatus(random);
      final RecordingAgentLoginRepository repository = buildLoginRepository(
        status,
      );
      await pumpLoginSections(
        tester,
        random,
        places: <AgentPlace>[place],
        repository: repository,
      );

      await repository.stored.openTerminal(_otherPlace(place));
      await tester.pump();

      final List<String> expected = <String>[
        for (final AgentLoginAction action in chooseAgentLoginActions(
          place: place,
          status: status,
        ))
          describeAgentLoginAction(action),
      ];
      expect(find.byType(LoginTerminalPanel), findsNothing);
      expect(_readActionLabels(tester, place), expected);
    }
  });

  testWidgets('test_agent_login_section_find_own_terminal_property_one_'
      'panel_under_the_matching_section', (WidgetTester tester) async {
    final Random random = seededRandom(108603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordingAgentLoginRepository repository = buildLoginRepository(
        randomLoginStatus(random),
      );
      await pumpLoginSections(
        tester,
        random,
        places: AgentPlace.values,
        repository: repository,
      );
      final AgentPlace opened = pickOne(random, AgentPlace.values);

      await repository.stored.openTerminal(opened);
      await tester.pump();

      final Finder panel = find.byType(LoginTerminalPanel);
      expect(panel, findsOneWidget);
      expect(_findInSection(opened, panel), findsOneWidget);
      expect(_findInSection(_otherPlace(opened), panel), findsNothing);
    }
  });

  testWidgets('test_agent_login_section_build_property_follows_the_'
      'repository', (WidgetTester tester) async {
    final Random random = seededRandom(108604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentLoginStatus status = AgentLoginStatus(
        claudeLogin: pickOne(random, ClaudeLogin.values),
        containerCredential: pickOne(random, AgentCredentialKind.values),
      );
      final RecordingAgentLoginRepository repository = buildLoginRepository(
        status,
      );
      await pumpLoginSections(
        tester,
        random,
        places: const <AgentPlace>[AgentPlace.container],
        repository: repository,
      );

      await repository.stored.forgetCredential();
      await tester.pump();

      expect(find.text(notConnectedText), findsOneWidget);
      expect(find.text(disconnectLabel), findsNothing);
    }
  });

  testWidgets('test_agent_login_section_build_property_renders_every_'
      'status_at_any_width', (WidgetTester tester) async {
    final Random random = seededRandom(108605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginStatus status = randomLoginStatus(random);
      await pumpLoginSections(
        tester,
        random,
        places: <AgentPlace>[place],
        repository: buildLoginRepository(status),
      );

      final AgentLoginDescription description = describeAgentLogin(
        place: place,
        status: status,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(description.statusText), findsOneWidget);
      expect(find.text(description.detail), findsOneWidget);
    }
  });

  testWidgets('test_agent_login_section_build_property_two_sections_share_'
      'one_repository', (WidgetTester tester) async {
    final Random random = seededRandom(108606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentLoginStatus status = randomLoginStatus(random);
      await pumpLoginSections(
        tester,
        random,
        places: AgentPlace.values,
        repository: buildLoginRepository(status),
      );

      for (final AgentPlace place in AgentPlace.values) {
        final AgentLoginDescription description = describeAgentLogin(
          place: place,
          status: status,
        );
        final Finder title = find.text(describeAgentLoginTitle(place));
        final Finder statusText = find.text(description.statusText);
        expect(_findInSection(place, title), findsOneWidget);
        expect(_findInSection(place, statusText), findsOneWidget);
      }
    }
  });

  testWidgets('test_agent_login_section_build_section_property_unknown_'
      'status_shows_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(108607);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordingAgentLoginRepository repository = buildLoginRepository(
        randomLoginStatus(random),
      );
      repository.isStatusHidden = true;
      await repository.stored.openTerminal(pickOne(random, AgentPlace.values));

      await pumpLoginSections(
        tester,
        random,
        places: AgentPlace.values,
        repository: repository,
      );

      expect(find.byType(LoginTerminalPanel), findsNothing);
      expect(find.byType(AppButton), findsNothing);
      for (final AgentPlace place in AgentPlace.values) {
        expect(find.text(describeAgentLoginTitle(place)), findsNothing);
      }
    }
  });

  testWidgets('test_agent_login_section_build_section_property_a_terminal_'
      'outranks_the_key_form', (WidgetTester tester) async {
    final Random random = seededRandom(108608);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordingAgentLoginRepository repository = buildLoginRepository(
        const AgentLoginStatus(
          claudeLogin: ClaudeLogin.loggedIn,
          containerCredential: null,
        ),
      );
      await pumpLoginSections(
        tester,
        random,
        places: const <AgentPlace>[AgentPlace.container],
        repository: repository,
      );
      await tapLoginButton(tester, useApiKeyLabel);

      await repository.stored.openTerminal(AgentPlace.container);
      await tester.pump();

      expect(find.byType(LoginTerminalPanel), findsOneWidget);
      expect(find.byType(ApiKeyForm), findsNothing);
      expect(_readActionLabels(tester, AgentPlace.container), isEmpty);
    }
  });

  testWidgets('test_agent_login_section_build_section_property_actions_'
      'follow_the_status_in_order', (WidgetTester tester) async {
    final Random random = seededRandom(108609);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginStatus status = randomLoginStatus(random);
      await pumpLoginSections(
        tester,
        random,
        places: <AgentPlace>[place],
        repository: buildLoginRepository(status),
      );

      final List<String> expected = <String>[
        for (final AgentLoginAction action in chooseAgentLoginActions(
          place: place,
          status: status,
        ))
          describeAgentLoginAction(action),
      ];
      expect(_readActionLabels(tester, place), expected);
      expect(find.byType(AgentLoginSection), findsOneWidget);
    }
  });
}
