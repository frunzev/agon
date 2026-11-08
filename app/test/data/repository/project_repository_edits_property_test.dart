import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/catalog_twin_steps.dart';
import '../fakes/support/project_inputs.dart';
import 'support/contract_step_failures.dart';
import 'support/project_contract_rigs.dart';

const String _typePrefix = 'test_project_repository';

Repository _randomNewRepository(Random random) {
  return randomRepositoryAt(random, randomCanonicalAddress(random));
}

Future<void> _expectMissingProjectRefused(
  Random random,
  ProjectStep Function(ProjectId projectId) buildStep,
) async {
  final ProjectContractWorld world = await buildProjectWorldAfterRandomSteps(
    random,
  );

  final List<ProjectStepOutcome> outcomes = await runOnProjectRepositories(
    world,
    buildStep(missingTwinProjectId),
  );

  for (final ProjectStepOutcome outcome in outcomes) {
    expect(outcome.failure, isNotNull, reason: outcome.name);
  }
  expectSameProjectOutcome(outcomes, label: missingTwinProjectId.value);
  expectProjectListingsAgree(world);
  closeProjectContractWorld(world);
}

Future<Project> _createEmptyProject(
  ProjectRepository repository,
  WorkspaceId workspaceId,
  String name,
) {
  return repository.createProject(
    ProjectDraft(
      workspaceId: workspaceId,
      name: name,
      repositories: const <Repository>[],
      approvalPolicy: null,
    ),
  );
}

void main() {
  test('${_typePrefix}_add_repository_property_appends_the_repository_'
      'and_keeps_the_rest', () async {
    final Random random = seededRandom(85711);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final ProjectContractWorld world =
          await buildProjectWorldAfterRandomSteps(random);
      final Project? project = pickSeededProject(random, world);
      final Repository repository = _randomNewRepository(random);
      if (project == null) {
        closeProjectContractWorld(world);
        continue;
      }

      for (final NamedProjectRepository implementation
          in world.implementations) {
        final List<String> before = listAddresses(
          implementation.repository.findProject(project.id),
        );
        final Project updated = await implementation.repository.addRepository(
          project.id,
          repository,
        );
        expect(listAddresses(updated), <String>[
          ...before,
          repository.address,
        ], reason: implementation.name);
        expect(
          listAddresses(implementation.repository.findProject(project.id)),
          listAddresses(updated),
        );
      }
      expectProjectListingsAgree(world);
      closeProjectContractWorld(world);
    }
  });

  test('${_typePrefix}_add_repository_property_refuses_an_address_already_'
      'listed_however_spelled', () async {
    final Random random = seededRandom(85712);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final ProjectContractWorld world =
          await buildProjectWorldAfterRandomSteps(random);
      final Project? project = pickSeededProject(random, world);
      if (project == null || project.repositories.isEmpty) {
        closeProjectContractWorld(world);
        continue;
      }
      final String listed = pickOne(random, listAddresses(project));
      final Repository repeated = randomRepositoryAt(
        random,
        spellAddressDifferently(random, listed),
      );

      final List<ProjectStepOutcome> outcomes = await runOnProjectRepositories(
        world,
        (ProjectRepository repository) =>
            repository.addRepository(project.id, repeated),
      );

      for (final ProjectStepOutcome outcome in outcomes) {
        expect(outcome.failure, isA<StateError>(), reason: '$outcome');
      }
      expectProjectListingsAgree(world);
      closeProjectContractWorld(world);
    }
  });

  test('${_typePrefix}_add_repository_property_unknown_projects_are_'
      'refused_alike', () async {
    final Random random = seededRandom(85713);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final Repository repository = _randomNewRepository(random);
      await _expectMissingProjectRefused(
        random,
        (ProjectId projectId) =>
            (ProjectRepository projects) =>
                projects.addRepository(projectId, repository),
      );
    }
  });

  test('${_typePrefix}_remove_repository_property_removes_exactly_that_'
      'address', () async {
    final Random random = seededRandom(85714);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final ProjectContractWorld world =
          await buildProjectWorldAfterRandomSteps(random);
      final Project? project = pickSeededProject(random, world);
      if (project == null || project.repositories.isEmpty) {
        closeProjectContractWorld(world);
        continue;
      }
      final String removed = pickOne(random, listAddresses(project));
      final String spelled = spellAddressDifferently(random, removed);

      for (final NamedProjectRepository implementation
          in world.implementations) {
        final Project updated = await implementation.repository
            .removeRepository(project.id, spelled);
        expect(
          listAddresses(updated),
          listAddresses(project).where((String address) => address != removed),
          reason: implementation.name,
        );
      }
      expectProjectListingsAgree(world);
      closeProjectContractWorld(world);
    }
  });

  test('${_typePrefix}_remove_repository_property_absent_addresses_are_'
      'refused_without_change', () async {
    final Random random = seededRandom(85715);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final ProjectContractWorld world =
          await buildProjectWorldAfterRandomSteps(random);
      final Project? project = pickSeededProject(random, world);
      final String absent = randomCanonicalAddress(random);
      if (project == null) {
        closeProjectContractWorld(world);
        continue;
      }

      final List<ProjectStepOutcome> outcomes = await runOnProjectRepositories(
        world,
        (ProjectRepository repository) =>
            repository.removeRepository(project.id, absent),
      );

      for (final ProjectStepOutcome outcome in outcomes) {
        expect(outcome.failure, isA<StateError>(), reason: '$outcome');
      }
      expectProjectListingsAgree(world);
      closeProjectContractWorld(world);
    }
  });

  test('${_typePrefix}_remove_repository_property_unknown_projects_are_'
      'refused_alike', () async {
    final Random random = seededRandom(85716);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final String address = randomCanonicalAddress(random);
      await _expectMissingProjectRefused(
        random,
        (ProjectId projectId) =>
            (ProjectRepository projects) =>
                projects.removeRepository(projectId, address),
      );
    }
  });

  test('${_typePrefix}_delete_project_property_removes_an_idle_project_'
      'and_keeps_the_rest', () async {
    final Random random = seededRandom(85717);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final ProjectContractWorld world =
          await buildProjectWorldAfterRandomSteps(random);
      final WorkspaceId workspaceId = pickOne(
        random,
        world.twins.seeds.workspaceIds,
      );
      final String name = 'idle-${random.nextInt(propertyIterations)}';

      for (final NamedProjectRepository implementation
          in world.implementations) {
        final List<String> before = describeProjectsIn(
          implementation.repository,
          workspaceId,
        );
        final Project created = await _createEmptyProject(
          implementation.repository,
          workspaceId,
          name,
        );
        await implementation.repository.deleteProject(created.id);
        expect(
          describeProjectsIn(implementation.repository, workspaceId),
          unorderedEquals(before),
          reason: implementation.name,
        );
      }
      expectProjectListingsAgree(world);
      closeProjectContractWorld(world);
    }
  });

  test('${_typePrefix}_delete_project_property_unknown_projects_are_'
      'refused_alike', () async {
    final Random random = seededRandom(85718);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      await _expectMissingProjectRefused(
        random,
        (ProjectId projectId) =>
            (ProjectRepository projects) => projects.deleteProject(projectId),
      );
    }
  });

  test('${_typePrefix}_delete_project_property_a_deleted_project_is_gone_'
      'for_good', () async {
    final Random random = seededRandom(85719);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final ProjectContractWorld world = await buildProjectContractWorld(
        random,
      );
      final WorkspaceId workspaceId = pickOne(
        random,
        world.twins.seeds.workspaceIds,
      );

      for (final NamedProjectRepository implementation
          in world.implementations) {
        final Project created = await _createEmptyProject(
          implementation.repository,
          workspaceId,
          'gone-${random.nextInt(propertyIterations)}',
        );
        await implementation.repository.deleteProject(created.id);
        final Object? findFailure = await findStepFailure(
          () async => implementation.repository.findProject(created.id),
        );
        final Object? deleteFailure = await findStepFailure(
          () => implementation.repository.deleteProject(created.id),
        );
        expect(
          findFailure,
          isA<RecordNotFound>(),
          reason: implementation.name,
        );
        expect(deleteFailure, isNotNull, reason: implementation.name);
      }
      closeProjectContractWorld(world);
    }
  });
}
