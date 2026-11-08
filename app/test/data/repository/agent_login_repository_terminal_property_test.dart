import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import 'support/agent_login_contract_rigs.dart';
import 'support/contract_step_failures.dart';

const String _typePrefix = 'test_agent_login_repository';
const int _terminalIterations = 40;
const int _longestSequence = 6;

void main() {
  test('${_typePrefix}_find_terminal_property_no_terminal_before_one_is_'
      'opened', () async {
    final Random random = seededRandom(84601);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildRandomAgentLoginRepositories(random);

      for (final NamedAgentLoginRepository implementation in implementations) {
        expect(
          implementation.repository.findTerminal(),
          isNull,
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_find_terminal_property_every_implementation_shows_'
      'the_same_terminal', () async {
    final Random random = seededRandom(84602);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildRandomAgentLoginRepositories(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        final LoginStep loginStep = pickOne(random, LoginStep.values);
        final AgentPlace place = pickOne(random, AgentPlace.values);
        final String text = randomStepText(random, loginStep);
        for (final NamedAgentLoginRepository implementation
            in implementations) {
          await findStepFailure(
            () => runLoginStep(
              implementation.repository,
              step: loginStep,
              place: place,
              text: text,
            ),
          );
        }

        final TerminalProjection? expected = projectTerminal(
          implementations.first.repository.findTerminal(),
        );
        for (final NamedAgentLoginRepository implementation
            in implementations) {
          expect(
            projectTerminal(implementation.repository.findTerminal()),
            expected,
            reason: '${implementation.name} after $loginStep',
          );
        }
      }
    }
  });

  test('${_typePrefix}_find_terminal_property_reading_notifies_'
      'nobody', () async {
    final Random random = seededRandom(84603);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildRandomAgentLoginRepositories(random);
      final AgentPlace place = pickOne(random, AgentPlace.values);

      for (final NamedAgentLoginRepository implementation in implementations) {
        await implementation.repository.openTerminal(place);
        final int notificationsBefore = implementation.notifications.count;

        final LoginTerminal? first = implementation.repository.findTerminal();
        final LoginTerminal? second = implementation.repository.findTerminal();

        expect(projectTerminal(second), projectTerminal(first));
        expect(implementation.notifications.count, notificationsBefore);
      }
    }
  });

  test('${_typePrefix}_open_terminal_property_opens_a_running_login_for_'
      'the_place', () async {
    final Random random = seededRandom(84604);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildRandomAgentLoginRepositories(random);
      final AgentPlace place = pickOne(random, AgentPlace.values);

      for (final NamedAgentLoginRepository implementation in implementations) {
        await implementation.repository.openTerminal(place);

        expect(
          projectTerminal(implementation.repository.findTerminal()),
          describeOpenTerminal(place),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_open_terminal_property_a_second_open_is_refused_and_'
      'keeps_the_first', () async {
    final Random random = seededRandom(84605);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildRandomAgentLoginRepositories(random);
      final AgentPlace firstPlace = pickOne(random, AgentPlace.values);
      final AgentPlace secondPlace = pickOne(random, AgentPlace.values);

      for (final NamedAgentLoginRepository implementation in implementations) {
        await implementation.repository.openTerminal(firstPlace);

        final Object? failure = await findStepFailure(
          () => implementation.repository.openTerminal(secondPlace),
        );

        expect(failure, isA<StateError>(), reason: implementation.name);
        expect(
          projectTerminal(implementation.repository.findTerminal()),
          describeOpenTerminal(firstPlace),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_open_terminal_property_a_closed_login_can_be_opened_'
      'again', () async {
    final Random random = seededRandom(84606);
    for (int i = 0; i < _terminalIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildRandomAgentLoginRepositories(random);
      final AgentPlace firstPlace = pickOne(random, AgentPlace.values);
      final AgentPlace secondPlace = pickOne(random, AgentPlace.values);

      for (final NamedAgentLoginRepository implementation in implementations) {
        await implementation.repository.openTerminal(firstPlace);
        await implementation.repository.closeTerminal();
        await implementation.repository.openTerminal(secondPlace);

        expect(
          projectTerminal(implementation.repository.findTerminal()),
          describeOpenTerminal(secondPlace),
          reason: implementation.name,
        );
      }
    }
  });
}
