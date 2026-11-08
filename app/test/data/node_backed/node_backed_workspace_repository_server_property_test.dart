import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';
import 'support/simulated_catalog_node.dart';
import 'support/workspace_repository_rig.dart';

const int _iterations = 40;
const int _largestLoadCount = 8;

String _describeGroup(AppServerGroup group) {
  final List<String> members = <String>[
    for (final AppServerMember member in group.members)
      '${member.deviceId.value}:${member.standing.name}',
  ];
  return '${group.thisDeviceStanding.name} ${group.canKeepBackup} $members';
}

void main() {
  test('test_find_app_server_status_property_mirrors_address_and_'
      'reachability', () async {
    final Random random = seededRandom(96508);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = WorkspaceRepositoryRig.open(
        random,
        hasAccount: true,
      );
      rig.node.isServerReachable = random.nextBool();

      await rig.repository.load();

      final AppServerStatus status = rig.repository.findAppServerStatus();
      final AppServerState expectedState = rig.node.isServerReachable
          ? AppServerState.online
          : AppServerState.unreachable;
      expect(status.address, simulatedServerAddress);
      expect(status.state, expectedState);
    }
  });

  test('test_find_app_server_status_property_no_account_has_no_'
      'status', () async {
    final Random random = seededRandom(96509);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = WorkspaceRepositoryRig.open(
        random,
        hasAccount: false,
      );

      await rig.repository.load();

      expect(rig.repository.findAppServerStatus, throwsStateError);
    }
  });

  test('test_find_app_server_status_property_keeps_the_last_connection_'
      'while_unreachable', () async {
    final Random random = seededRandom(96510);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = await openLoadedWorkspaceRig(random);
      final int unreachableLoads = 1 + random.nextInt(_largestLoadCount);

      rig.node.isServerReachable = false;
      for (int load = 0; load < unreachableLoads; load += 1) {
        await rig.repository.load();
      }

      final AppServerStatus status = rig.repository.findAppServerStatus();
      expect(status.state, AppServerState.unreachable);
      expect(status.lastConnectedAt, workspaceRigMoment);
    }
  });

  test('test_find_app_server_group_property_a_failed_reload_keeps_the_'
      'group', () async {
    final Random random = seededRandom(96511);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = await openLoadedWorkspaceRig(random);
      final String groupBefore = _describeGroup(
        rig.repository.findAppServerGroup(),
      );
      rig.node.failingCommands.add(
        pickOne(random, <String>['status', 'list_workspaces']),
      );

      final Object? problem = await readRepositoryProblem(rig.repository.load);

      expect(problem, isA<StateError>());
      expect(_describeGroup(rig.repository.findAppServerGroup()), groupBefore);
    }
  });

  test('test_find_app_server_group_property_reads_without_asking_the_'
      'node', () async {
    final Random random = seededRandom(96512);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = await openLoadedWorkspaceRig(random);
      final int exchangesBefore = rig.transport.exchanges.length;

      final String first = _describeGroup(rig.repository.findAppServerGroup());
      final String second = _describeGroup(
        rig.repository.findAppServerGroup(),
      );

      expect(rig.transport.exchanges, hasLength(exchangesBefore));
      expect(second, first);
    }
  });
}
