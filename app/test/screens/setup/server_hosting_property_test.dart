import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';
import 'package:agent_orchestration/screens/setup/server_hosting.dart';

const String _sampleDeviceName = 'air-laptop';

void main() {
  test('test_list_setup_roles_property_never_empty_nor_repeated', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final List<DeviceRole> roles = listSetupRoles(platform);

      expect(roles, isNotEmpty, reason: '$platform');
      expect(roles.toSet(), hasLength(roles.length), reason: '$platform');
    }
  });

  test('test_list_setup_roles_property_first_choice_can_use_the_app', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final DeviceRole firstRole = listSetupRoles(platform).first;

      expect(firstRole, isNot(DeviceRole.runner), reason: '$platform');
    }
  });

  test('test_list_setup_roles_property_callers_cannot_change_the_list', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final List<DeviceRole> roles = listSetupRoles(platform);

      expect(() => roles.add(DeviceRole.runner), throwsUnsupportedError);
      expect(roles.clear, throwsUnsupportedError);
      expect(listSetupRoles(platform), roles);
    }
  });

  test('test_can_host_app_server_property_only_for_an_offered_role', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final List<DeviceRole> offered = listSetupRoles(platform);
      for (final DeviceRole role in DeviceRole.values) {
        if (canHostAppServer(platform: platform, role: role)) {
          expect(offered, contains(role), reason: '$platform $role');
        }
      }
    }
  });

  test('test_can_host_app_server_property_runner_only_never_hosts', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      expect(
        canHostAppServer(platform: platform, role: DeviceRole.runner),
        isFalse,
        reason: '$platform',
      );
    }
  });

  test('test_can_host_app_server_property_computers_that_run_tasks_can_'
      'host', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final bool isComputer = listSetupRoles(platform).any(roleRunsTasks);
      final bool canHostSomeRole = DeviceRole.values.any(
        (DeviceRole role) => canHostAppServer(platform: platform, role: role),
      );

      expect(canHostSomeRole, isComputer, reason: '$platform');
    }
  });

  test('test_first_workspace_name_property_passes_the_name_rules', () {
    expect(describeNameProblem(firstWorkspaceName), isNull);
    expect(
      () => refuseBadHostedAccountNames(
        workspaceName: firstWorkspaceName,
        deviceName: _sampleDeviceName,
      ),
      returnsNormally,
    );
  });
}
