import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import 'support/agent_login_contract_rigs.dart';
import 'support/contract_step_failures.dart';

const String _typePrefix = 'test_agent_login_repository';
const int _terminalIterations = 40;
const int _longestSequence = 6;

void main() {
  test('${_typePrefix}_type_into_terminal_property_without_a_login_typing_'
      'is_refused', () async {
    final Random random = seededRandom(84607);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildRandomAgentLoginRepositories(random);
      final bool hasClosedOne = random.nextBool();

      for (final NamedAgentLoginRepository implementation in implementations) {
        if (hasClosedOne) {
          await implementation.repository.openTerminal(AgentPlace.container);
          await implementation.repository.closeTerminal();
        }

        final Object? failure = await findStepFailure(
          () => typeRandomKeys(random, implementation.repository),
        );

        expect(failure, isA<StateError>(), reason: implementation.name);
        expect(implementation.repository.findTerminal(), isNull);
      }
    }
  });

  test('${_typePrefix}_type_into_terminal_property_keeps_the_login_running_'
      'for_its_place', () async {
    final Random random = seededRandom(84608);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildRandomAgentLoginRepositories(random);
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final int typingCount = 1 + random.nextInt(_longestSequence);

      for (final NamedAgentLoginRepository implementation in implementations) {
        await implementation.repository.openTerminal(place);
        for (int typing = 0; typing < typingCount; typing += 1) {
          await typeRandomKeys(random, implementation.repository);
        }

        expect(
          projectTerminal(implementation.repository.findTerminal()),
          describeOpenTerminal(place),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_type_into_terminal_property_never_changes_the_'
      'status', () async {
    final Random random = seededRandom(84609);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildRandomAgentLoginRepositories(random);
      final AgentPlace place = pickOne(random, AgentPlace.values);

      for (final NamedAgentLoginRepository implementation in implementations) {
        await implementation.repository.openTerminal(place);
        final StatusProjection? before = projectStatus(
          implementation.repository.findStatus(),
        );

        await typeRandomKeys(random, implementation.repository);

        expect(projectStatus(implementation.repository.findStatus()), before);
      }
    }
  });

  test('${_typePrefix}_close_terminal_property_leaves_no_terminal', () async {
    final Random random = seededRandom(84610);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildRandomAgentLoginRepositories(random);
      final bool isOpen = random.nextBool();

      for (final NamedAgentLoginRepository implementation in implementations) {
        if (isOpen) {
          await implementation.repository.openTerminal(
            pickOne(random, AgentPlace.values),
          );
        }

        await implementation.repository.closeTerminal();

        expect(
          implementation.repository.findTerminal(),
          isNull,
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_close_terminal_property_closing_twice_is_idempotent_'
      'and_notifies', () async {
    final Random random = seededRandom(84611);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildRandomAgentLoginRepositories(random);

      for (final NamedAgentLoginRepository implementation in implementations) {
        await implementation.repository.openTerminal(
          pickOne(random, AgentPlace.values),
        );
        await implementation.repository.closeTerminal();
        final int notificationsBefore = implementation.notifications.count;

        await implementation.repository.closeTerminal();

        expect(implementation.repository.findTerminal(), isNull);
        expect(
          implementation.notifications.count,
          greaterThan(notificationsBefore),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_close_terminal_property_never_changes_the_'
      'status', () async {
    final Random random = seededRandom(84612);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildRandomAgentLoginRepositories(random);

      for (final NamedAgentLoginRepository implementation in implementations) {
        await implementation.repository.openTerminal(
          pickOne(random, AgentPlace.values),
        );
        final StatusProjection? before = projectStatus(
          implementation.repository.findStatus(),
        );

        await implementation.repository.closeTerminal();

        expect(projectStatus(implementation.repository.findStatus()), before);
      }
    }
  });
}
