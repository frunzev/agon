import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';

import '../../support/random_inputs.dart';

const Map<DeviceRole, bool> _nodeCanRunTasks = <DeviceRole, bool>{
  DeviceRole.client: false,
  DeviceRole.runner: true,
  DeviceRole.clientAndRunner: true,
};
const String _runnerWord = 'runner';

void main() {
  test('test_role_runs_tasks_property_agrees_with_node_can_run_tasks', () {
    for (final DeviceRole role in DeviceRole.values) {
      expect(roleRunsTasks(role), _nodeCanRunTasks[role], reason: role.name);
    }
  });

  test('test_role_runs_tasks_property_follows_the_runner_label', () {
    final Random random = seededRandom(87801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceRole role = pickOne(random, DeviceRole.values);

      final bool mentionsRunner = role.label.toLowerCase().contains(
        _runnerWord,
      );

      expect(roleRunsTasks(role), mentionsRunner, reason: role.label);
    }
  });
}
