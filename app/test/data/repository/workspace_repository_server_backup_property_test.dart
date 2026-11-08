import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/simulated_catalog_node.dart';
import 'support/workspace_contract_checks.dart';
import 'support/workspace_contract_rigs.dart';
import 'support/workspace_contract_steps.dart';

const String _typePrefix = 'test_workspace_repository';
const int _backupIterations = 30;
const DeviceId _thisDevice = DeviceId(simulatedDeviceId);
const List<WorkspaceContractAction> _serverActions = <WorkspaceContractAction>[
  WorkspaceContractAction.retryAppServer,
  WorkspaceContractAction.startServerBackup,
  WorkspaceContractAction.stopServerBackup,
];
const List<WorkspaceContractAction> _workspaceActions =
    <WorkspaceContractAction>[
      WorkspaceContractAction.switchWorkspace,
      WorkspaceContractAction.createWorkspace,
      WorkspaceContractAction.deleteWorkspace,
      WorkspaceContractAction.saveProtectedFiles,
      WorkspaceContractAction.resetProtectedFiles,
      WorkspaceContractAction.changeApprovalPolicy,
    ];

typedef _BackupRule = bool Function(AppServerGroup group);

AppServerGroup _readFirstGroup(WorkspaceContractWorld world) {
  return firstWorkspaceRepository(world).findAppServerGroup();
}

bool _canStartBackup(AppServerGroup group) {
  final bool hasActiveServer = group.members.any(
    (AppServerMember member) => member.standing == ServerStanding.active,
  );
  return group.canKeepBackup &&
      group.thisDeviceStanding == ThisDeviceStanding.none &&
      hasActiveServer;
}

bool _canStopBackup(AppServerGroup group) {
  return group.thisDeviceStanding == ThisDeviceStanding.backup;
}

List<String> _describeOtherMembers(AppServerGroup group) {
  final List<String> others = <String>[
    for (final AppServerMember member in group.members)
      if (member.deviceId != _thisDevice)
        '${member.deviceId.value} ${member.standing.name}',
  ];
  others.sort();
  return others;
}

Future<void> _expectServerActionFollowsRule(
  int seed, {
  required WorkspaceContractAction action,
  required _BackupRule isAllowed,
  required ThisDeviceStanding standingAfter,
}) async {
  final Random random = seededRandom(seed);
  int allowedCount = 0;
  int refusedCount = 0;
  for (int i = 0; i < _backupIterations; i += 1) {
    final WorkspaceContractWorld world =
        await openWorkspaceWorldAfterRandomSteps(
          random,
          actions: _serverActions,
        );
    final AppServerGroup before = _readFirstGroup(world);
    final bool isExpectedAllowed = isAllowed(before);

    final List<WorkspaceOutcome> outcomes =
        await performServerActionOnEveryRepository(world, action);

    expectWorkspaceOutcomesAgree(outcomes);
    expectWorkspaceStateAgrees(world);
    expect(isWorkspaceStepRefused(outcomes), !isExpectedAllowed);
    final AppServerGroup after = _readFirstGroup(world);
    expect(_describeOtherMembers(after), _describeOtherMembers(before));
    expect(after.canKeepBackup, before.canKeepBackup);
    if (isExpectedAllowed) {
      allowedCount += 1;
      expect(after.thisDeviceStanding, standingAfter);
    } else {
      refusedCount += 1;
      expect(describeAppServerGroup(after), describeAppServerGroup(before));
    }
  }
  expect(allowedCount, greaterThan(0));
  expect(refusedCount, greaterThan(0));
}

void main() {
  test('${_typePrefix}_find_app_server_group_property_every_implementation_'
      'reports_the_same_group', () async {
    await expectWorkspaceAgreementOn(86507, _serverActions);
  });

  test('${_typePrefix}_find_app_server_group_property_this_device_member_'
      'matches_its_standing', () async {
    final Random random = seededRandom(86508);
    for (int i = 0; i < _backupIterations; i += 1) {
      final WorkspaceContractWorld world =
          await openWorkspaceWorldAfterRandomSteps(
            random,
            actions: _serverActions,
          );

      for (final ContractWorkspaceImplementation implementation
          in world.implementations) {
        final AppServerGroup group = implementation.repository
            .findAppServerGroup();
        final List<String> ownStandings = <String>[
          for (final AppServerMember member in group.members)
            if (member.deviceId == _thisDevice) member.standing.name,
        ];
        final List<String> expected =
            group.thisDeviceStanding == ThisDeviceStanding.none
            ? <String>[]
            : <String>[group.thisDeviceStanding.name];
        expect(ownStandings, expected, reason: implementation.name);
      }
    }
  });

  test('${_typePrefix}_find_app_server_group_property_workspace_changes_'
      'leave_the_group_alone', () async {
    final Random random = seededRandom(86509);
    for (int i = 0; i < _backupIterations; i += 1) {
      final WorkspaceContractWorld world = await openWorkspaceContractWorld(
        random,
      );
      final String before = describeAppServerGroup(_readFirstGroup(world));

      await performRandomWorkspaceSteps(
        random,
        world,
        stepCount: randomWorkspaceStepCount(random),
        actions: _workspaceActions,
      );

      expect(describeAppServerGroup(_readFirstGroup(world)), before);
    }
  });

  test('${_typePrefix}_start_server_backup_property_every_implementation_'
      'agrees_on_the_outcome', () async {
    await expectWorkspaceAgreementOn(86510, const <WorkspaceContractAction>[
      WorkspaceContractAction.startServerBackup,
    ]);
  });

  test('${_typePrefix}_start_server_backup_property_follows_the_backup_'
      'rules', () async {
    await _expectServerActionFollowsRule(
      86511,
      action: WorkspaceContractAction.startServerBackup,
      isAllowed: _canStartBackup,
      standingAfter: ThisDeviceStanding.backup,
    );
  });

  test('${_typePrefix}_start_server_backup_property_starting_twice_is_'
      'refused', () async {
    final Random random = seededRandom(86512);
    for (int i = 0; i < _backupIterations; i += 1) {
      final WorkspaceContractWorld world = await openWorkspaceContractWorld(
        random,
      );
      await performServerActionOnEveryRepository(
        world,
        WorkspaceContractAction.startServerBackup,
      );

      final List<WorkspaceOutcome> outcomes =
          await performServerActionOnEveryRepository(
            world,
            WorkspaceContractAction.startServerBackup,
          );

      expectWorkspaceOutcomesAgree(outcomes);
      expect(isWorkspaceStepRefused(outcomes), isTrue);
      expectWorkspaceStateAgrees(world);
    }
  });

  test('${_typePrefix}_stop_server_backup_property_every_implementation_'
      'agrees_on_the_outcome', () async {
    await expectWorkspaceAgreementOn(86513, const <WorkspaceContractAction>[
      WorkspaceContractAction.stopServerBackup,
    ]);
  });

  test('${_typePrefix}_stop_server_backup_property_follows_the_backup_'
      'rules', () async {
    await _expectServerActionFollowsRule(
      86514,
      action: WorkspaceContractAction.stopServerBackup,
      isAllowed: _canStopBackup,
      standingAfter: ThisDeviceStanding.none,
    );
  });

  test('${_typePrefix}_stop_server_backup_property_start_then_stop_'
      'restores_the_group', () async {
    final Random random = seededRandom(86515);
    int restoredCount = 0;
    for (int i = 0; i < _backupIterations; i += 1) {
      final WorkspaceContractWorld world = await openWorkspaceContractWorld(
        random,
      );
      final AppServerGroup before = _readFirstGroup(world);
      if (!_canStartBackup(before)) {
        continue;
      }

      await performServerActionOnEveryRepository(
        world,
        WorkspaceContractAction.startServerBackup,
      );
      final List<WorkspaceOutcome> outcomes =
          await performServerActionOnEveryRepository(
            world,
            WorkspaceContractAction.stopServerBackup,
          );

      expectWorkspaceOutcomesAgree(outcomes);
      expect(isWorkspaceStepRefused(outcomes), isFalse);
      expectWorkspaceStateAgrees(world);
      restoredCount += 1;
      expect(
        describeAppServerGroup(_readFirstGroup(world)),
        describeAppServerGroup(before),
      );
    }
    expect(restoredCount, greaterThan(0));
  });
}
