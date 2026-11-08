import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';
import 'support/workspace_contract_checks.dart';
import 'support/workspace_contract_rigs.dart';
import 'support/workspace_contract_steps.dart';

const String _typePrefix = 'test_workspace_repository';
const List<WorkspaceContractAction> _workspaceActions =
    <WorkspaceContractAction>[
      WorkspaceContractAction.switchWorkspace,
      WorkspaceContractAction.createWorkspace,
      WorkspaceContractAction.deleteWorkspace,
      WorkspaceContractAction.saveProtectedFiles,
      WorkspaceContractAction.resetProtectedFiles,
      WorkspaceContractAction.changeApprovalPolicy,
    ];

String _describeFirstStatus(WorkspaceContractWorld world) {
  return describeAppServerStatus(
    firstWorkspaceRepository(world).findAppServerStatus(),
  );
}

void main() {
  test('${_typePrefix}_find_app_server_status_property_every_'
      'implementation_reports_the_same_status', () async {
    await expectWorkspaceAgreementOn(86501, WorkspaceContractAction.values);
  });

  test('${_typePrefix}_find_app_server_status_property_address_and_retry_'
      'interval_never_change', () async {
    final Random random = seededRandom(86502);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world = await openWorkspaceContractWorld(
        random,
      );
      final AppServerStatus before = firstWorkspaceRepository(world)
          .findAppServerStatus();

      await performRandomWorkspaceSteps(
        random,
        world,
        stepCount: randomWorkspaceStepCount(random),
        actions: WorkspaceContractAction.values,
      );

      for (final ContractWorkspaceImplementation implementation
          in world.implementations) {
        final AppServerStatus after = implementation.repository
            .findAppServerStatus();
        expect(after.address, before.address, reason: implementation.name);
        expect(after.retryInterval, before.retryInterval);
      }
    }
  });

  test('${_typePrefix}_find_app_server_status_property_workspace_changes_'
      'leave_the_status_alone', () async {
    final Random random = seededRandom(86503);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world = await openWorkspaceContractWorld(
        random,
      );
      final String before = _describeFirstStatus(world);

      await performRandomWorkspaceSteps(
        random,
        world,
        stepCount: randomWorkspaceStepCount(random),
        actions: _workspaceActions,
      );

      expect(_describeFirstStatus(world), before);
    }
  });

  test('${_typePrefix}_retry_app_server_property_every_implementation_'
      'agrees_on_the_outcome', () async {
    await expectWorkspaceAgreementOn(86504, const <WorkspaceContractAction>[
      WorkspaceContractAction.retryAppServer,
    ]);
  });

  test('${_typePrefix}_retry_app_server_property_returns_the_status_it_'
      'then_reports', () async {
    final Random random = seededRandom(86505);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world = await openWorkspaceContractWorld(
        random,
      );

      for (final ContractWorkspaceImplementation implementation
          in world.implementations) {
        final AppServerStatus returned = await implementation.repository
            .retryAppServer();
        final AppServerStatus reported = implementation.repository
            .findAppServerStatus();
        expect(
          describeAppServerStatus(returned),
          describeAppServerStatus(reported),
          reason: implementation.name,
        );
        expect(returned.state, AppServerState.online);
      }
      expectWorkspaceStateAgrees(world);
    }
  });

  test('${_typePrefix}_retry_app_server_property_repeating_it_changes_'
      'nothing_more', () async {
    final Random random = seededRandom(86506);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world = await openWorkspaceContractWorld(
        random,
      );

      for (final ContractWorkspaceImplementation implementation
          in world.implementations) {
        final AppServerStatus first = await implementation.repository
            .retryAppServer();
        final AppServerStatus second = await implementation.repository
            .retryAppServer();
        expect(
          describeAppServerStatus(second),
          describeAppServerStatus(first),
          reason: implementation.name,
        );
      }
      expectWorkspaceStateAgrees(world);
    }
  });
}
