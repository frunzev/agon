import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/naming.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/workspace_inputs.dart';
import 'support/contract_step_failures.dart';
import 'support/workspace_contract_checks.dart';
import 'support/workspace_contract_rigs.dart';
import 'support/workspace_contract_steps.dart';

const String _typePrefix = 'test_workspace_repository';
void main() {
  test('${_typePrefix}_list_workspaces_property_every_implementation_lists_'
      'the_same_workspaces', () async {
    await expectWorkspaceAgreementOn(86301, WorkspaceContractAction.values);
  });

  test('${_typePrefix}_list_workspaces_property_never_empty_and_never_'
      'repeats_a_workspace', () async {
    final Random random = seededRandom(86302);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world =
          await openWorkspaceWorldAfterRandomSteps(
            random,
            actions: WorkspaceContractAction.values,
          );

      for (final ContractWorkspaceImplementation implementation
          in world.implementations) {
        final List<Workspace> listed = implementation.repository
            .listWorkspaces();
        final Set<String> identifiers = <String>{
          for (final Workspace workspace in listed) workspace.id.value,
        };
        expect(listed, isNotEmpty, reason: implementation.name);
        expect(identifiers, hasLength(listed.length));
      }
    }
  });

  test('${_typePrefix}_list_workspaces_property_callers_cannot_change_the_'
      'listing', () async {
    final Random random = seededRandom(86303);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world =
          await openWorkspaceWorldAfterRandomSteps(
            random,
            actions: WorkspaceContractAction.values,
          );

      for (final ContractWorkspaceImplementation implementation
          in world.implementations) {
        final List<Workspace> listed = implementation.repository
            .listWorkspaces();
        final List<String> before = describeContractWorkspaces(implementation);
        final Object? failure = await findStepFailure(() async {
          listed.clear();
        });

        expect(failure, isA<UnsupportedError>(), reason: implementation.name);
        expect(describeContractWorkspaces(implementation), before);
      }
    }
  });

  test('${_typePrefix}_current_workspace_property_every_implementation_'
      'agrees_on_the_current_workspace', () async {
    await expectWorkspaceAgreementOn(86304, const <WorkspaceContractAction>[
      WorkspaceContractAction.switchWorkspace,
      WorkspaceContractAction.createWorkspace,
      WorkspaceContractAction.deleteWorkspace,
    ]);
  });

  test('${_typePrefix}_current_workspace_property_is_always_a_listed_'
      'workspace', () async {
    final Random random = seededRandom(86305);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world =
          await openWorkspaceWorldAfterRandomSteps(
            random,
            actions: WorkspaceContractAction.values,
          );

      for (final ContractWorkspaceImplementation implementation
          in world.implementations) {
        final Workspace current = implementation.repository.currentWorkspace();
        final Workspace? listed = findListedWorkspaceByKey(
          implementation,
          implementation.findKey(current.id),
        );
        expect(listed, isNotNull, reason: implementation.name);
        expect(
          describeContractWorkspace(implementation, current),
          describeContractWorkspace(implementation, listed!),
        );
      }
    }
  });

  test('${_typePrefix}_current_workspace_property_deleting_it_moves_to_the_'
      'first_remaining_workspace', () async {
    final Random random = seededRandom(86306);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world =
          await openWorkspaceWorldAfterRandomSteps(
            random,
            actions: WorkspaceContractAction.values,
          );
      final String deleted = currentWorkspaceKey(world);
      final bool isLast = listWorkspaceKeys(world).length == 1;

      final List<WorkspaceOutcome> outcomes =
          await performKeyedOnEveryWorkspaceRepository(
            random,
            world,
            action: WorkspaceContractAction.deleteWorkspace,
            key: deleted,
          );

      expectWorkspaceOutcomesAgree(outcomes);
      expect(isWorkspaceStepRefused(outcomes), isLast);
      for (final ContractWorkspaceImplementation implementation
          in world.implementations) {
        final Workspace current = implementation.repository.currentWorkspace();
        final Workspace first = implementation.repository
            .listWorkspaces()
            .first;
        final String currentKey = implementation.findKey(current.id);
        expect(currentKey == deleted, isLast, reason: implementation.name);
        if (!isLast) {
          expect(current.id, first.id, reason: implementation.name);
        }
      }
    }
  });

  test('${_typePrefix}_switch_workspace_property_every_implementation_'
      'agrees_on_the_outcome', () async {
    await expectWorkspaceAgreementOn(86307, const <WorkspaceContractAction>[
      WorkspaceContractAction.switchWorkspace,
    ]);
  });

  test('${_typePrefix}_switch_workspace_property_makes_a_listed_workspace_'
      'current', () async {
    final Random random = seededRandom(86308);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world =
          await openWorkspaceWorldAfterRandomSteps(
            random,
            actions: WorkspaceContractAction.values,
          );
      final String key = pickOne(random, listWorkspaceKeys(world));

      final List<WorkspaceOutcome> outcomes =
          await performKeyedOnEveryWorkspaceRepository(
            random,
            world,
            action: WorkspaceContractAction.switchWorkspace,
            key: key,
          );

      expectWorkspaceOutcomesAgree(outcomes);
      expect(isWorkspaceStepRefused(outcomes), isFalse);
      expect(currentWorkspaceKey(world), key);
      expectWorkspaceStateAgrees(world);
    }
  });

  test('${_typePrefix}_switch_workspace_property_missing_workspaces_keep_'
      'the_current_one', () async {
    final Random random = seededRandom(86309);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world =
          await openWorkspaceWorldAfterRandomSteps(
            random,
            actions: WorkspaceContractAction.values,
          );
      final String before = currentWorkspaceKey(world);

      final List<WorkspaceOutcome> outcomes =
          await performKeyedOnEveryWorkspaceRepository(
            random,
            world,
            action: WorkspaceContractAction.switchWorkspace,
            key: missingWorkspaceKey(random),
          );

      expectWorkspaceOutcomesAgree(outcomes);
      expect(isWorkspaceStepRefused(outcomes), isTrue);
      expect(currentWorkspaceKey(world), before);
      expectWorkspaceStateAgrees(world);
    }
  });

  test('${_typePrefix}_create_workspace_property_every_implementation_'
      'agrees_on_the_outcome', () async {
    await expectWorkspaceAgreementOn(86310, const <WorkspaceContractAction>[
      WorkspaceContractAction.createWorkspace,
    ]);
  });

  test('${_typePrefix}_create_workspace_property_lists_the_trimmed_name_'
      'with_default_patterns', () async {
    final Random random = seededRandom(86311);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world =
          await openWorkspaceWorldAfterRandomSteps(
            random,
            actions: WorkspaceContractAction.values,
          );
      final String name = randomWorkspaceName(random);
      final bool isValid = describeNameProblem(name.trim()) == null;
      final int countBefore = listWorkspaceKeys(world).length;
      final String createdKey = nextCreatedWorkspaceKey(world);

      final List<WorkspaceOutcome> outcomes =
          await createOnEveryWorkspaceRepository(world, name);

      expectWorkspaceOutcomesAgree(outcomes);
      expect(isWorkspaceStepRefused(outcomes), !isValid);
      expectWorkspaceStateAgrees(world);
      final int expectedCount = isValid ? countBefore + 1 : countBefore;
      expect(listWorkspaceKeys(world), hasLength(expectedCount));
      if (!isValid) {
        continue;
      }
      for (final ContractWorkspaceImplementation implementation
          in world.implementations) {
        final Workspace? created = findListedWorkspaceByKey(
          implementation,
          createdKey,
        );
        expect(created?.name, name.trim(), reason: implementation.name);
        expect(created?.protectedFiles, implementation.defaultPatterns);
      }
    }
  });

  test('${_typePrefix}_create_workspace_property_refused_names_change_'
      'nothing', () async {
    final Random random = seededRandom(86312);
    for (int i = 0; i < workspaceContractIterations; i += 1) {
      final WorkspaceContractWorld world =
          await openWorkspaceWorldAfterRandomSteps(
            random,
            actions: WorkspaceContractAction.values,
          );
      final List<String> before = describeContractWorkspaces(
        world.implementations.first,
      );
      final String currentBefore = currentWorkspaceKey(world);
      final String name = pickOne(random, <String>[
        '',
        '   ',
        'n' * (nameMaximumLength + 1 + random.nextInt(9)),
        'Has Space',
        'UPPER',
        'under_score',
        'café',
      ]);

      final List<WorkspaceOutcome> outcomes =
          await createOnEveryWorkspaceRepository(world, name);

      expectWorkspaceOutcomesAgree(outcomes);
      expect(isWorkspaceStepRefused(outcomes), isTrue);
      expectWorkspaceStateAgrees(world);
      expect(describeContractWorkspaces(world.implementations.first), before);
      expect(currentWorkspaceKey(world), currentBefore);
    }
  });
}
