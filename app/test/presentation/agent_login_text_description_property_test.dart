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
const String _apiKeyWords = 'API key';
const List<String> _hostileTexts = <String>[
  '',
  '   ',
  '\n\t',
  'Ünïcødé ✓ 漢字',
  'snake_case_name',
  r'$runner {name}',
];

const Map<ClaudeLogin, String> _localStatusTexts = <ClaudeLogin, String>{
  ClaudeLogin.loggedIn: loggedInText,
  ClaudeLogin.notLoggedIn: notLoggedInText,
  ClaudeLogin.notInstalled: notInstalledText,
  ClaudeLogin.unknown: unknownLoginText,
};

AgentCredentialKind? _randomCredential(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return pickOne(random, AgentCredentialKind.values);
}

AgentLoginStatus _randomStatus(Random random) {
  return AgentLoginStatus(
    claudeLogin: pickOne(random, ClaudeLogin.values),
    containerCredential: _randomCredential(random),
  );
}

String _randomShownText(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _hostileTexts);
  }
  return randomText(random);
}

AgentLoginDescription _describe(AgentPlace place, AgentLoginStatus status) {
  return describeAgentLogin(place: place, status: status);
}

String _showLoginSection(AgentPlace place, AgentLoginStatus status) {
  final AgentLoginDescription description = _describe(place, status);
  final String title = describeAgentLoginTitle(place);
  return '$title ${description.statusText} ${description.detail}';
}

void main() {
  test('test_agent_login_description_constructor_property_keeps_every_'
      'field', () {
    final Random random = seededRandom(91501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String statusText = _randomShownText(random);
      final String detail = _randomShownText(random);
      final bool isReady = random.nextBool();

      final AgentLoginDescription description = AgentLoginDescription(
        statusText: statusText,
        detail: detail,
        isReady: isReady,
      );

      expect(identical(description.statusText, statusText), isTrue);
      expect(identical(description.detail, detail), isTrue);
      expect(description.isReady, isReady);
    }
  });

  test('test_agent_login_description_constructor_property_never_trims_or_'
      'swaps_texts', () {
    for (final String statusText in _hostileTexts) {
      for (final String detail in _hostileTexts) {
        final AgentLoginDescription description = AgentLoginDescription(
          statusText: statusText,
          detail: detail,
          isReady: false,
        );

        expect(description.statusText, statusText);
        expect(description.detail, detail);
      }
    }
  });

  test('test_agent_login_description_constructor_property_const_values_are_'
      'shared', () {
    const AgentLoginDescription first = AgentLoginDescription(
      statusText: loggedInText,
      detail: notInstalledText,
      isReady: true,
    );
    const AgentLoginDescription second = AgentLoginDescription(
      statusText: loggedInText,
      detail: notInstalledText,
      isReady: true,
    );

    expect(identical(first, second), isTrue);
  });

  test('test_describe_agent_login_property_equal_statuses_read_the_same', () {
    final Random random = seededRandom(91502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginStatus status = _randomStatus(random);
      final AgentLoginStatus sameStatus = AgentLoginStatus(
        claudeLogin: status.claudeLogin,
        containerCredential: status.containerCredential,
      );

      final AgentLoginDescription first = _describe(place, status);
      final AgentLoginDescription second = _describe(place, sameStatus);

      expect(second.statusText, first.statusText);
      expect(second.detail, first.detail);
      expect(second.isReady, first.isReady);
    }
  });

  test('test_describe_local_login_property_only_the_claude_login_counts', () {
    final Random random = seededRandom(91503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginStatus status = _randomStatus(random);
      final AgentLoginStatus statusWithoutCredential = AgentLoginStatus(
        claudeLogin: status.claudeLogin,
        containerCredential: null,
      );

      final AgentLoginDescription description = _describe(
        AgentPlace.localProcess,
        status,
      );
      final AgentLoginDescription withoutCredential = _describe(
        AgentPlace.localProcess,
        statusWithoutCredential,
      );

      expect(description.isReady, status.claudeLogin == ClaudeLogin.loggedIn);
      expect(description.statusText, withoutCredential.statusText);
      expect(description.detail, withoutCredential.detail);
    }
  });

  test('test_describe_local_login_property_each_login_reads_plainly', () {
    final Set<String> details = <String>{};

    for (final ClaudeLogin login in ClaudeLogin.values) {
      final AgentLoginStatus status = AgentLoginStatus(
        claudeLogin: login,
        containerCredential: null,
      );

      final AgentLoginDescription description = _describe(
        AgentPlace.localProcess,
        status,
      );

      expectPlainLabel(description.statusText);
      expectPlainSentences(description.detail);
      expect(description.statusText, _localStatusTexts[login]);
      details.add(description.detail);
    }

    expect(details.length, ClaudeLogin.values.length);
  });

  test('test_describe_local_login_property_matches_the_design', () {
    final Map<ClaudeLogin, String> designPages = <ClaudeLogin, String>{
      ClaudeLogin.loggedIn: _bothOffersDesignPage,
      ClaudeLogin.notLoggedIn: _loginDesignPage,
    };

    for (final MapEntry<ClaudeLogin, String> page in designPages.entries) {
      final AgentLoginStatus status = AgentLoginStatus(
        claudeLogin: page.key,
        containerCredential: null,
      );

      final String shownSection = _showLoginSection(
        AgentPlace.localProcess,
        status,
      );

      expect(readDesignPageText(page.value), contains(shownSection));
    }
  });

  test('test_describe_container_login_property_a_credential_decides_'
      'alone', () {
    final Random random = seededRandom(91504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginStatus status = _randomStatus(random);
      final AgentCredentialKind? credential = status.containerCredential;
      final AgentLoginStatus otherLoginStatus = AgentLoginStatus(
        claudeLogin: pickOne(random, ClaudeLogin.values),
        containerCredential: credential,
      );

      final AgentLoginDescription description = _describe(
        AgentPlace.container,
        status,
      );
      final AgentLoginDescription otherLogin = _describe(
        AgentPlace.container,
        otherLoginStatus,
      );

      expect(description.isReady, credential != null);
      if (credential != null) {
        expect(otherLogin.statusText, description.statusText);
        expect(otherLogin.detail, description.detail);
      }
    }
  });

  test('test_describe_container_login_property_every_outcome_reads_'
      'plainly', () {
    final Set<String> details = <String>{};

    for (final ClaudeLogin login in ClaudeLogin.values) {
      for (final AgentCredentialKind? credential in <AgentCredentialKind?>[
        null,
        ...AgentCredentialKind.values,
      ]) {
        final AgentLoginStatus status = AgentLoginStatus(
          claudeLogin: login,
          containerCredential: credential,
        );

        final AgentLoginDescription description = _describe(
          AgentPlace.container,
          status,
        );

        expectPlainLabel(description.statusText);
        expectPlainSentences(description.detail);
        expect(
          description.statusText.contains(_apiKeyWords),
          credential == AgentCredentialKind.apiKey,
        );
        details.add(description.detail);
      }
    }

    expect(details.length, AgentCredentialKind.values.length + 2);
  });

  test('test_describe_container_login_property_matches_the_design', () {
    final Map<AgentLoginStatus, String> designPages =
        <AgentLoginStatus, String>{
          const AgentLoginStatus(
            claudeLogin: ClaudeLogin.loggedIn,
            containerCredential: AgentCredentialKind.longLivedToken,
          ): _bothOffersDesignPage,
          const AgentLoginStatus(
            claudeLogin: ClaudeLogin.loggedIn,
            containerCredential: null,
          ): _dockerConnectDesignPage,
        };

    for (final MapEntry<AgentLoginStatus, String> page
        in designPages.entries) {
      final String shownSection = _showLoginSection(
        AgentPlace.container,
        page.key,
      );

      expect(readDesignPageText(page.value), contains(shownSection));
    }
  });
}
