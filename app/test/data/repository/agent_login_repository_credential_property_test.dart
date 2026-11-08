import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/agent_login_inputs.dart';
import '../node_backed/support/node_backed_agent_login_rig.dart';
import 'support/agent_login_contract_rigs.dart';
import 'support/contract_step_failures.dart';

const String _typePrefix = 'test_agent_login_repository';
const int _statusIterations = 40;

void main() {
  test('${_typePrefix}_save_api_key_property_a_valid_key_keeps_an_api_key_'
      'and_the_claude_login', () async {
    final Random random = seededRandom(84507);
    for (int i = 0; i < _statusIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildEveryAgentLoginRepository(
            randomKnownAgentLoginStatus(random),
          );
      final String apiKey = randomValidApiKey(random);

      for (final NamedAgentLoginRepository implementation in implementations) {
        final ClaudeLogin claudeLogin = implementation.repository
            .findStatus()!
            .claudeLogin;

        await implementation.repository.saveApiKey(apiKey);

        expect(projectStatus(implementation.repository.findStatus()), (
          claudeLogin: claudeLogin,
          containerCredential: AgentCredentialKind.apiKey,
        ), reason: implementation.name);
      }
    }
  });

  test('${_typePrefix}_save_api_key_property_refused_keys_change_'
      'nothing', () async {
    final Random random = seededRandom(84508);
    for (int i = 0; i < _statusIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildEveryAgentLoginRepository(
            randomKnownAgentLoginStatus(random),
          );
      final String apiKey = randomRefusedApiKey(random);

      for (final NamedAgentLoginRepository implementation in implementations) {
        final StatusProjection? before = projectStatus(
          implementation.repository.findStatus(),
        );

        final Object? failure = await findStepFailure(
          () => implementation.repository.saveApiKey(apiKey),
        );

        expect(failure, isA<StateError>(), reason: implementation.name);
        expect(projectStatus(implementation.repository.findStatus()), before);
      }
    }
  });

  test('${_typePrefix}_save_api_key_property_every_implementation_judges_'
      'a_key_alike', () async {
    final Random random = seededRandom(84509);
    for (int i = 0; i < _statusIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildEveryAgentLoginRepository(
            randomKnownAgentLoginStatus(random),
          );
      final String apiKey = pickOne(random, <String>[
        randomApiKeyAttempt(random),
        '\uFEFF${randomValidApiKey(random).trim()}',
        '${randomValidApiKey(random).trim()}\u0085',
        'key\u200Bkey',
      ]);
      final List<bool> refusals = <bool>[];

      for (final NamedAgentLoginRepository implementation in implementations) {
        final Object? failure = await findStepFailure(
          () => implementation.repository.saveApiKey(apiKey),
        );
        refusals.add(failure != null);
      }

      expect(refusals.toSet(), hasLength(1), reason: apiKey);
    }
  });

  test('${_typePrefix}_forget_credential_property_forgets_only_the_'
      'container_credential', () async {
    final Random random = seededRandom(84510);
    for (int i = 0; i < _statusIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildEveryAgentLoginRepository(
            randomKnownAgentLoginStatus(random),
          );
      await runRandomStepsOnEvery(random, implementations);

      for (final NamedAgentLoginRepository implementation in implementations) {
        final ClaudeLogin claudeLogin = implementation.repository
            .findStatus()!
            .claudeLogin;

        await implementation.repository.forgetCredential();

        expect(projectStatus(implementation.repository.findStatus()), (
          claudeLogin: claudeLogin,
          containerCredential: null,
        ), reason: implementation.name);
      }
    }
  });

  test('${_typePrefix}_forget_credential_property_forgetting_twice_is_'
      'idempotent_and_notifies', () async {
    final Random random = seededRandom(84511);
    for (int i = 0; i < _statusIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildEveryAgentLoginRepository(
            randomKnownAgentLoginStatus(random),
          );

      for (final NamedAgentLoginRepository implementation in implementations) {
        await implementation.repository.forgetCredential();
        final StatusProjection? once = projectStatus(
          implementation.repository.findStatus(),
        );
        final int notificationsBefore = implementation.notifications.count;

        await implementation.repository.forgetCredential();

        expect(projectStatus(implementation.repository.findStatus()), once);
        expect(
          implementation.notifications.count,
          greaterThan(notificationsBefore),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_forget_credential_property_a_saved_key_is_'
      'forgotten', () async {
    final Random random = seededRandom(84512);
    for (int i = 0; i < _statusIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildEveryAgentLoginRepository(
            randomKnownAgentLoginStatus(random),
          );

      for (final NamedAgentLoginRepository implementation in implementations) {
        await implementation.repository.saveApiKey(randomValidApiKey(random));
        await implementation.repository.forgetCredential();

        expect(
          implementation.repository.findStatus()!.containerCredential,
          isNull,
          reason: implementation.name,
        );
      }
    }
  });
}
