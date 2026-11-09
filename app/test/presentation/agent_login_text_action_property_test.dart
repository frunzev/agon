import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';

import '../support/random_inputs.dart';
import 'support/plain_shown_text.dart';

const String _bothOffersDesignPage = 'runner-detail-both-offers';
const String _loginDesignPage = 'runner-detail-claude-login';
const String _dockerConnectDesignPage = 'runner-detail-docker-connect';
const String _claudeCodeName = 'Claude Code';
const String _dockerWord = 'Docker';
const List<AgentLoginAction> _setUpActions = <AgentLoginAction>[
  AgentLoginAction.logIn,
  AgentLoginAction.connect,
  AgentLoginAction.useApiKey,
];
const Map<AgentLoginAction, String> _actionWordsInDetail =
    <AgentLoginAction, String>{
      AgentLoginAction.logIn: 'Log in',
      AgentLoginAction.connect: 'Connect',
      AgentLoginAction.useApiKey: 'API key',
    };
const Map<AgentLoginAction, String> _exportedActionLabels =
    <AgentLoginAction, String>{
      AgentLoginAction.logIn: logInLabel,
      AgentLoginAction.connect: connectClaudeCodeLabel,
      AgentLoginAction.useApiKey: useApiKeyLabel,
      AgentLoginAction.disconnect: disconnectLabel,
    };

AgentLoginStatus _randomStatus(Random random) {
  return AgentLoginStatus(
    claudeLogin: pickOne(random, ClaudeLogin.values),
    containerCredential: random.nextBool()
        ? null
        : pickOne(random, AgentCredentialKind.values),
  );
}

List<AgentLoginAction> _chooseActions(
  AgentPlace place,
  AgentLoginStatus status,
) {
  return chooseAgentLoginActions(place: place, status: status);
}

String _showActionLabels(List<AgentLoginAction> actions) {
  final List<String> labels = <String>[];
  for (final AgentLoginAction action in actions) {
    labels.add(describeAgentLoginAction(action));
  }
  return labels.join(' ');
}

void main() {
  test('test_choose_agent_login_actions_property_set_up_only_when_not_'
      'ready', () {
    final Random random = seededRandom(91601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginStatus status = _randomStatus(random);
      final bool isReady = describeAgentLogin(
        place: place,
        status: status,
      ).isReady;

      final List<AgentLoginAction> actions = _chooseActions(place, status);

      final bool offersSetUp = actions.any(_setUpActions.contains);
      final bool offersDisconnect = actions.contains(
        AgentLoginAction.disconnect,
      );
      expect(offersSetUp && isReady, isFalse);
      expect(offersDisconnect, isReady && place == AgentPlace.container);
    }
  });

  test('test_choose_agent_login_actions_property_never_repeats_an_'
      'action', () {
    final Random random = seededRandom(91602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginStatus status = _randomStatus(random);

      final List<AgentLoginAction> actions = _chooseActions(place, status);

      expect(actions.toSet().length, actions.length);
      if (place == AgentPlace.container) {
        expect(actions, isNotEmpty);
      }
    }
  });

  test('test_choose_agent_login_actions_property_the_detail_names_the_'
      'first_step', () {
    final Random random = seededRandom(91603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginStatus status = _randomStatus(random);
      final List<AgentLoginAction> actions = _chooseActions(place, status);
      final String detail = describeAgentLogin(
        place: place,
        status: status,
      ).detail;

      final String? firstStepWords = actions.isEmpty
          ? null
          : _actionWordsInDetail[actions.first];

      if (firstStepWords != null) {
        expect(detail, contains(firstStepWords));
      }
    }
  });

  test('test_choose_agent_login_actions_property_buttons_match_the_'
      'design', () {
    final Map<AgentLoginStatus, String> designPages =
        <AgentLoginStatus, String>{
          const AgentLoginStatus(
            claudeLogin: ClaudeLogin.loggedIn,
            containerCredential: null,
          ): _dockerConnectDesignPage,
          const AgentLoginStatus(
            claudeLogin: ClaudeLogin.loggedIn,
            containerCredential: AgentCredentialKind.longLivedToken,
          ): _bothOffersDesignPage,
        };

    for (final MapEntry<AgentLoginStatus, String> page
        in designPages.entries) {
      final AgentLoginStatus status = page.key;
      final String detail = describeAgentLogin(
        place: AgentPlace.container,
        status: status,
      ).detail;
      final List<AgentLoginAction> actions = _chooseActions(
        AgentPlace.container,
        status,
      );

      final String shownButtons = _showActionLabels(actions);

      expect(
        readDesignPageText(page.value),
        contains('$detail $shownButtons'),
      );
    }
  });

  test('test_describe_agent_login_title_property_is_a_plain_label_unique_'
      'per_place', () {
    final Random random = seededRandom(91604);
    final Set<String> titles = <String>{};

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);

      final String title = describeAgentLoginTitle(place);

      expectPlainLabel(title);
      expect(title, startsWith(_claudeCodeName));
      titles.add(title);
    }

    expect(titles.length, AgentPlace.values.length);
  });

  test('test_describe_agent_login_title_property_matches_the_design', () {
    final String designText = readDesignPageText(_bothOffersDesignPage);

    for (final AgentPlace place in AgentPlace.values) {
      expect(designText, contains(describeAgentLoginTitle(place)));
    }
  });

  test('test_describe_agent_login_title_property_names_docker_only_for_'
      'containers', () {
    for (final AgentPlace place in AgentPlace.values) {
      final String title = describeAgentLoginTitle(place);

      expect(title.contains(_dockerWord), place == AgentPlace.container);
    }
  });

  test('test_describe_agent_login_action_property_is_a_plain_label_unique_'
      'per_action', () {
    final Random random = seededRandom(91605);
    final Set<String> labels = <String>{};

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginAction action = pickOne(random, AgentLoginAction.values);

      final String label = describeAgentLoginAction(action);

      expectPlainLabel(label);
      expect(describeAgentLoginAction(action), label);
      labels.add(label);
    }

    expect(labels.length, AgentLoginAction.values.length);
  });

  test('test_describe_agent_login_action_property_matches_the_labels_used_'
      'elsewhere', () {
    for (final AgentLoginAction action in AgentLoginAction.values) {
      final String label = describeAgentLoginAction(action);

      expect(label, _exportedActionLabels[action]);
    }
  });

  test('test_describe_agent_login_action_property_matches_the_design', () {
    final String designText = <String>[
      readDesignPageText(_bothOffersDesignPage),
      readDesignPageText(_loginDesignPage),
      readDesignPageText(_dockerConnectDesignPage),
    ].join(' ');

    for (final AgentLoginAction action in AgentLoginAction.values) {
      expect(designText, contains(describeAgentLoginAction(action)));
    }
  });
}
