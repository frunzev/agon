import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/agent_login_inputs.dart';
import 'support/agent_login_contract_rigs.dart';

const String _typePrefix = 'test_agent_login_repository';
const int _statusIterations = 40;

void main() {
  test('${_typePrefix}_find_status_property_every_implementation_reports_'
      'the_same_status_after_any_steps', () async {
    final Random random = seededRandom(84501);
    for (int i = 0; i < _statusIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildEveryAgentLoginRepository(
            randomKnownAgentLoginStatus(random),
          );

      await runRandomStepsOnEvery(random, implementations);

      final StatusProjection? expected = projectStatus(
        implementations.first.repository.findStatus(),
      );
      for (final NamedAgentLoginRepository implementation in implementations) {
        expect(
          projectStatus(implementation.repository.findStatus()),
          expected,
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_find_status_property_starts_at_the_checked_'
      'status', () async {
    final Random random = seededRandom(84502);
    for (int i = 0; i < _statusIterations; i += 1) {
      final AgentLoginStatus status = randomKnownAgentLoginStatus(random);
      final List<NamedAgentLoginRepository> implementations =
          await buildEveryAgentLoginRepository(status);

      for (final NamedAgentLoginRepository implementation in implementations) {
        expect(
          projectStatus(implementation.repository.findStatus()),
          projectStatus(status),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_find_status_property_reading_twice_changes_nothing_'
      'and_notifies_nobody', () async {
    final Random random = seededRandom(84503);
    for (int i = 0; i < _statusIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildEveryAgentLoginRepository(
            randomKnownAgentLoginStatus(random),
          );
      await runRandomStepsOnEvery(random, implementations);

      for (final NamedAgentLoginRepository implementation in implementations) {
        final int notificationsBefore = implementation.notifications.count;
        final StatusProjection? first = projectStatus(
          implementation.repository.findStatus(),
        );
        final StatusProjection? second = projectStatus(
          implementation.repository.findStatus(),
        );

        expect(second, first, reason: implementation.name);
        expect(implementation.notifications.count, notificationsBefore);
      }
    }
  });

  test('${_typePrefix}_check_status_property_keeps_an_unchanged_status_'
      'and_notifies', () async {
    final Random random = seededRandom(84504);
    for (int i = 0; i < _statusIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildEveryAgentLoginRepository(
            randomKnownAgentLoginStatus(random),
          );
      await runRandomStepsOnEvery(random, implementations);

      for (final NamedAgentLoginRepository implementation in implementations) {
        final StatusProjection? before = projectStatus(
          implementation.repository.findStatus(),
        );
        final int notificationsBefore = implementation.notifications.count;

        await implementation.repository.checkStatus();

        expect(
          projectStatus(implementation.repository.findStatus()),
          before,
          reason: implementation.name,
        );
        expect(
          implementation.notifications.count,
          greaterThan(notificationsBefore),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_check_status_property_checking_again_is_'
      'idempotent', () async {
    final Random random = seededRandom(84505);
    for (int i = 0; i < _statusIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildEveryAgentLoginRepository(
            randomKnownAgentLoginStatus(random),
          );
      await runRandomStepsOnEvery(random, implementations);

      for (final NamedAgentLoginRepository implementation in implementations) {
        await implementation.repository.checkStatus();
        final StatusProjection? once = projectStatus(
          implementation.repository.findStatus(),
        );
        await implementation.repository.checkStatus();

        expect(
          projectStatus(implementation.repository.findStatus()),
          once,
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_check_status_property_never_touches_the_'
      'terminal', () async {
    final Random random = seededRandom(84506);
    for (int i = 0; i < _statusIterations; i += 1) {
      final List<NamedAgentLoginRepository> implementations =
          await buildEveryAgentLoginRepository(
            randomKnownAgentLoginStatus(random),
          );
      await runRandomStepsOnEvery(random, implementations);

      for (final NamedAgentLoginRepository implementation in implementations) {
        final TerminalProjection? before = projectTerminal(
          implementation.repository.findTerminal(),
        );

        await implementation.repository.checkStatus();

        expect(
          projectTerminal(implementation.repository.findTerminal()),
          before,
          reason: implementation.name,
        );
      }
    }
  });
}
