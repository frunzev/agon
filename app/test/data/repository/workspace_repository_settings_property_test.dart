import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/protected_patterns.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/workspace_inputs.dart';
import 'support/workspace_contract_checks.dart';
import 'support/workspace_contract_rigs.dart';
import 'support/workspace_contract_steps.dart';

const String _typePrefix = 'test_workspace_repository';
void main() {
  test('${_typePrefix}_delete_workspace_property_every_implementation_'
      'agrees_on_the_outcome', () async {
    await expectWorkspaceAgreementOn(86401, const <WorkspaceContractAction>[
      WorkspaceContractAction.deleteWorkspace,
    ]);
  });

  test('${_typePrefix}_delete_workspace_property_removes_exactly_the_'
      'deleted_workspace', () async {
    final Random random = seededRandom(86402);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world =
          await openWorkspaceWorldAfterRandomSteps(
            random,
            actions: WorkspaceContractAction.values,
          );
      final List<String> keysBefore = listWorkspaceKeys(world);
      final String key = pickOne(random, keysBefore);
      final bool isLast = keysBefore.length == 1;

      final List<WorkspaceOutcome> outcomes =
          await performKeyedOnEveryWorkspaceRepository(
            random,
            world,
            action: WorkspaceContractAction.deleteWorkspace,
            key: key,
          );

      expectWorkspaceOutcomesAgree(outcomes);
      expect(isWorkspaceStepRefused(outcomes), isLast);
      final List<String> expectedKeys = <String>[
        for (final String listed in keysBefore)
          if (isLast || listed != key) listed,
      ];
      for (final ContractWorkspaceImplementation implementation
          in world.implementations) {
        final List<String> keysAfter = <String>[
          for (final Workspace workspace
              in implementation.repository.listWorkspaces())
            implementation.findKey(workspace.id),
        ];
        expect(
          keysAfter.toSet(),
          expectedKeys.toSet(),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_delete_workspace_property_missing_workspaces_change_'
      'nothing', () async {
    await expectMissingWorkspaceChangesNothing(
      86403,
      WorkspaceContractAction.deleteWorkspace,
    );
  });

  test('${_typePrefix}_save_protected_files_property_every_implementation_'
      'agrees_on_the_outcome', () async {
    await expectWorkspaceAgreementOn(86404, const <WorkspaceContractAction>[
      WorkspaceContractAction.saveProtectedFiles,
    ]);
  });

  test('${_typePrefix}_save_protected_files_property_valid_patterns_read_'
      'back_exactly', () async {
    final Random random = seededRandom(86405);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world =
          await openWorkspaceWorldAfterRandomSteps(
            random,
            actions: WorkspaceContractAction.values,
          );
      final String key = pickOne(random, listWorkspaceKeys(world));
      final List<String> patterns = randomPatterns(random);
      final WorkspaceFields? before = readWorkspaceFields(
        world.implementations.first,
        key,
      );

      final List<WorkspaceOutcome> outcomes =
          await saveOnEveryWorkspaceRepository(
            world,
            key: key,
            patterns: patterns,
          );

      expectWorkspaceOutcomesAgree(outcomes);
      expect(isWorkspaceStepRefused(outcomes), isFalse);
      for (final ContractWorkspaceImplementation implementation
          in world.implementations) {
        final WorkspaceFields? after = readWorkspaceFields(
          implementation,
          key,
        );
        expect(after?.protectedFiles, patterns, reason: implementation.name);
        expect(after?.name, before?.name);
        expect(after?.approvalPolicy, before?.approvalPolicy);
      }
    }
  });

  test('${_typePrefix}_save_protected_files_property_refused_patterns_'
      'change_nothing', () async {
    final Random random = seededRandom(86406);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world =
          await openWorkspaceWorldAfterRandomSteps(
            random,
            actions: WorkspaceContractAction.values,
          );
      final String key = pickOne(random, listWorkspaceKeys(world));
      final List<String> patterns = <String>[
        ...randomPatterns(random),
        pickOne(random, <String>['', ' padded', 'quote"d', r'back\slash']),
      ];
      final List<String> before = describeContractWorkspaces(
        world.implementations.first,
      );

      final List<WorkspaceOutcome> outcomes =
          await saveOnEveryWorkspaceRepository(
            world,
            key: key,
            patterns: patterns,
          );

      expect(describeProtectedFilesProblem(patterns), isNotNull);
      expectWorkspaceOutcomesAgree(outcomes);
      expect(isWorkspaceStepRefused(outcomes), isTrue);
      expectWorkspaceStateAgrees(world);
      expect(describeContractWorkspaces(world.implementations.first), before);
    }
  });

  test('${_typePrefix}_reset_protected_files_property_every_implementation_'
      'agrees_on_the_outcome', () async {
    await expectWorkspaceAgreementOn(86407, const <WorkspaceContractAction>[
      WorkspaceContractAction.resetProtectedFiles,
    ]);
  });

  test('${_typePrefix}_reset_protected_files_property_restores_the_'
      'defaults_and_is_idempotent', () async {
    final Random random = seededRandom(86408);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world =
          await openWorkspaceWorldAfterRandomSteps(
            random,
            actions: WorkspaceContractAction.values,
          );
      final String key = pickOne(random, listWorkspaceKeys(world));
      final WorkspaceFields? before = readWorkspaceFields(
        world.implementations.first,
        key,
      );

      for (int reset = 0; reset < 2; reset += 1) {
        final List<WorkspaceOutcome> outcomes =
            await performKeyedOnEveryWorkspaceRepository(
              random,
              world,
              action: WorkspaceContractAction.resetProtectedFiles,
              key: key,
            );
        expectWorkspaceOutcomesAgree(outcomes);
        expect(isWorkspaceStepRefused(outcomes), isFalse);
      }

      for (final ContractWorkspaceImplementation implementation
          in world.implementations) {
        final WorkspaceFields? after = readWorkspaceFields(
          implementation,
          key,
        );
        expect(after?.protectedFiles, implementation.defaultPatterns);
        expect(after?.name, before?.name, reason: implementation.name);
        expect(after?.approvalPolicy, before?.approvalPolicy);
      }
    }
  });

  test('${_typePrefix}_reset_protected_files_property_missing_workspaces_'
      'change_nothing', () async {
    await expectMissingWorkspaceChangesNothing(
      86409,
      WorkspaceContractAction.resetProtectedFiles,
    );
  });

  test('${_typePrefix}_change_approval_policy_property_every_'
      'implementation_agrees_on_the_outcome', () async {
    await expectWorkspaceAgreementOn(86410, const <WorkspaceContractAction>[
      WorkspaceContractAction.changeApprovalPolicy,
    ]);
  });

  test('${_typePrefix}_change_approval_policy_property_reads_back_and_'
      'keeps_other_fields', () async {
    final Random random = seededRandom(86411);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world =
          await openWorkspaceWorldAfterRandomSteps(
            random,
            actions: WorkspaceContractAction.values,
          );
      final String key = pickOne(random, listWorkspaceKeys(world));
      final ApprovalPolicy policy = pickOne(random, ApprovalPolicy.values);
      final List<WorkspaceFields?> before = readFieldsOfEveryImplementation(
        world,
        key,
      );

      final List<WorkspaceOutcome> outcomes =
          await changePolicyOnEveryWorkspaceRepository(
            world,
            key: key,
            approvalPolicy: policy,
          );

      expectWorkspaceOutcomesAgree(outcomes);
      expect(isWorkspaceStepRefused(outcomes), isFalse);
      for (int index = 0; index < world.implementations.length; index += 1) {
        final ContractWorkspaceImplementation implementation =
            world.implementations[index];
        final WorkspaceFields? after = readWorkspaceFields(
          implementation,
          key,
        );
        expect(after?.approvalPolicy, policy, reason: implementation.name);
        expect(after?.name, before[index]?.name);
        expect(after?.protectedFiles, before[index]?.protectedFiles);
      }
    }
  });

  test('${_typePrefix}_change_approval_policy_property_missing_workspaces_'
      'change_nothing', () async {
    await expectMissingWorkspaceChangesNothing(
      86412,
      WorkspaceContractAction.changeApprovalPolicy,
    );
  });
}
