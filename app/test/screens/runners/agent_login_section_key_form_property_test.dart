import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/screens/runners/api_key_form.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import 'agent_login_probe.dart';

const List<String> _controlCharacters = <String>[
  '\u0000',
  '\u0007',
  '\u001B',
  '\u007F',
  '\u0085',
  '\u009F',
];

AgentLoginStatus _randomKeylessStatus(Random random) {
  return AgentLoginStatus(
    claudeLogin: pickOne(random, ClaudeLogin.values),
    containerCredential: null,
  );
}

Future<RecordingAgentLoginRepository> _openKeyForm(
  WidgetTester tester,
  Random random,
) async {
  final RecordingAgentLoginRepository repository = buildLoginRepository(
    _randomKeylessStatus(random),
  );
  await pumpLoginSections(
    tester,
    random,
    places: const <AgentPlace>[AgentPlace.container],
    repository: repository,
  );
  await tapLoginButton(tester, useApiKeyLabel);
  return repository;
}

String _readKeyField(WidgetTester tester) {
  final TextField field = tester.widget<TextField>(
    findFieldInput(apiKeyFieldLabel),
  );
  return field.controller?.text ?? '';
}

String _randomKey(Random random, RuleTitleWhiteSpaceTable table) {
  final StringBuffer key = StringBuffer(table.randomWhiteSpaceRun(random));
  key.write('sk-ant-${random.nextInt(1 << 30)}');
  if (random.nextInt(3) == 0) {
    key.write(pickOne(random, _controlCharacters));
  }
  if (random.nextInt(3) == 0) {
    key.write(table.randomWhiteSpaceRun(random));
    key.write('x');
  }
  key.write(table.randomWhiteSpaceRun(random));
  if (random.nextInt(8) == 0) {
    return table.randomWhiteSpaceRun(random);
  }
  return key.toString();
}

bool _isControl(int rune) {
  return rune < 0x20 || (rune >= 0x7F && rune <= 0x9F);
}

bool _isAcceptedByRust(String key, RuleTitleWhiteSpaceTable table) {
  final String trimmed = table.trimByModel(key);
  if (trimmed.isEmpty) {
    return false;
  }
  for (final int rune in trimmed.runes) {
    final String character = String.fromCharCode(rune);
    if (table.isWhiteSpace(character) || _isControl(rune)) {
      return false;
    }
  }
  return true;
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  testWidgets('test_agent_login_section_open_api_key_form_property_shows_'
      'the_form_instead_of_actions', (WidgetTester tester) async {
    final Random random = seededRandom(108801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openKeyForm(tester, random);

      expect(find.byType(ApiKeyForm), findsOneWidget);
      expect(find.text(useApiKeyLabel), findsNothing);
      expect(find.text(connectClaudeCodeLabel), findsNothing);
    }
  });

  testWidgets('test_agent_login_section_open_api_key_form_property_asks_'
      'the_repository_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(108802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordingAgentLoginRepository repository = await _openKeyForm(
        tester,
        random,
      );

      expect(repository.refusal.attempts, 0);
      expect(repository.findTerminal(), isNull);
      expect(repository.findStatus()?.containerCredential, isNull);
    }
  });

  testWidgets('test_agent_login_section_open_api_key_form_property_starts_'
      'empty_each_time', (WidgetTester tester) async {
    final Random random = seededRandom(108803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openKeyForm(tester, random);
      await enterFieldText(
        tester,
        label: apiKeyFieldLabel,
        text: _randomKey(random, table),
      );
      await tapLoginButton(tester, cancelLabel);

      await tapLoginButton(tester, useApiKeyLabel);

      expect(_readKeyField(tester), isEmpty);
    }
  });

  testWidgets('test_agent_login_section_close_api_key_form_property_cancel_'
      'brings_back_the_actions', (WidgetTester tester) async {
    final Random random = seededRandom(108804);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordingAgentLoginRepository repository = await _openKeyForm(
        tester,
        random,
      );

      await tapLoginButton(tester, cancelLabel);

      final AgentLoginStatus? status = repository.findStatus();
      if (status == null) {
        throw StateError('the login status vanished');
      }
      expect(find.byType(ApiKeyForm), findsNothing);
      for (final AgentLoginAction action in chooseAgentLoginActions(
        place: AgentPlace.container,
        status: status,
      )) {
        expect(find.text(describeAgentLoginAction(action)), findsOneWidget);
      }
      expect(repository.refusal.attempts, 0);
    }
  });

  testWidgets('test_agent_login_section_close_api_key_form_property_a_'
      'saved_key_closes_the_form', (WidgetTester tester) async {
    final Random random = seededRandom(108805);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openKeyForm(tester, random);
      await enterFieldText(
        tester,
        label: apiKeyFieldLabel,
        text: 'sk-ant-api03-${random.nextInt(1 << 30)}',
      );

      await tapLoginButton(tester, saveKeyLabel);

      expect(find.byType(ApiKeyForm), findsNothing);
      expect(find.text(connectedWithApiKeyText), findsOneWidget);
      expect(find.text(disconnectLabel), findsOneWidget);
    }
  });

  testWidgets('test_agent_login_section_close_api_key_form_property_a_'
      'refused_key_keeps_the_form', (WidgetTester tester) async {
    final Random random = seededRandom(108806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openKeyForm(tester, random);
      final String key = 'sk ${table.randomWhiteSpaceRun(random)}ant';
      await enterFieldText(tester, label: apiKeyFieldLabel, text: key);
      final String typed = _readKeyField(tester);

      await tapLoginButton(tester, saveKeyLabel);
      expect(find.text('$saveKeyLabel did not work'), findsOneWidget);
      await tapLoginButton(tester, closeLabel);

      expect(find.byType(ApiKeyForm), findsOneWidget);
      expect(_readKeyField(tester), typed);
      expect(find.text(notConnectedText), findsOneWidget);
    }
  });

  testWidgets('test_save_api_key_property_matches_the_rust_credential_'
      'rules', (WidgetTester tester) async {
    final Random random = seededRandom(108807);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final RecordingAgentLoginRepository repository = await _openKeyForm(
        tester,
        random,
      );
      await enterFieldText(
        tester,
        label: apiKeyFieldLabel,
        text: _randomKey(random, table),
      );
      final String typed = _readKeyField(tester);
      final bool isAccepted = _isAcceptedByRust(typed, table);

      await tapLoginButton(tester, saveKeyLabel);

      final AgentCredentialKind? credential = repository
          .findStatus()
          ?.containerCredential;
      final String reason = typed.runes.toString();
      final Matcher refusalShown = isAccepted ? findsNothing : findsOneWidget;
      expect(find.text('$saveKeyLabel did not work'), refusalShown);
      expect(
        credential,
        isAccepted ? AgentCredentialKind.apiKey : isNull,
        reason: reason,
      );
    }
  });
}
