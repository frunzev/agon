import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../fakes/support/project_inputs.dart';
import 'support/contract_step_failures.dart';
import 'support/project_contract_rigs.dart';

const String _typePrefix = 'test_project_repository';
const int _longestSequence = 4;
const WorkspaceId _unknownWorkspaceId = WorkspaceId('workspace-never-made');

ProjectDraft _withName(ProjectDraft draft, String name) {
  return ProjectDraft(
    workspaceId: draft.workspaceId,
    name: name,
    repositories: draft.repositories,
    approvalPolicy: draft.approvalPolicy,
  );
}

void main() {
  test('${_typePrefix}_list_projects_property_every_implementation_lists_'
      'the_same_projects', () async {
    final Random random = seededRandom(85701);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final ProjectContractWorld world = await buildProjectContractWorld(
        random,
      );
      expectProjectListingsAgree(world);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        await runRandomProjectStep(random, world);
        expectProjectListingsAgree(world);
      }
      closeProjectContractWorld(world);
    }
  });

  test('${_typePrefix}_list_projects_property_lists_unique_projects_of_'
      'the_asked_workspace_only', () async {
    final Random random = seededRandom(85702);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final ProjectContractWorld world =
          await buildProjectWorldAfterRandomSteps(random);

      for (final NamedProjectRepository implementation
          in world.implementations) {
        final ProjectRepository repository = implementation.repository;
        expect(repository.listProjects(_unknownWorkspaceId), isEmpty);
        for (final WorkspaceId workspaceId in world.twins.seeds.workspaceIds) {
          final List<Project> listed = repository.listProjects(workspaceId);
          final Set<ProjectId> identifiers = <ProjectId>{
            for (final Project project in listed) project.id,
          };
          expect(identifiers, hasLength(listed.length));
          for (final Project project in listed) {
            expect(project.workspaceId, workspaceId);
          }
        }
      }
      closeProjectContractWorld(world);
    }
  });

  test('${_typePrefix}_list_projects_property_callers_cannot_change_the_'
      'listing', () async {
    final Random random = seededRandom(85703);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final ProjectContractWorld world =
          await buildProjectWorldAfterRandomSteps(random);
      final WorkspaceId workspaceId = pickOne(
        random,
        world.twins.seeds.workspaceIds,
      );

      for (final NamedProjectRepository implementation
          in world.implementations) {
        final List<Project> listed = implementation.repository.listProjects(
          workspaceId,
        );
        final List<String> before = describeProjectsIn(
          implementation.repository,
          workspaceId,
        );
        final Object? failure = await findStepFailure(
          () async => listed.clear(),
        );

        expect(failure, isA<UnsupportedError>(), reason: implementation.name);
        expect(
          describeProjectsIn(implementation.repository, workspaceId),
          before,
        );
      }
      closeProjectContractWorld(world);
    }
  });

  test('${_typePrefix}_find_project_property_finds_every_listed_project_'
      'as_listed', () async {
    final Random random = seededRandom(85704);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final ProjectContractWorld world =
          await buildProjectWorldAfterRandomSteps(random);

      for (final NamedProjectRepository implementation
          in world.implementations) {
        for (final WorkspaceId workspaceId in world.twins.seeds.workspaceIds) {
          for (final Project listed in implementation.repository.listProjects(
            workspaceId,
          )) {
            final Project found = implementation.repository.findProject(
              listed.id,
            );
            expect(describeProject(found), describeProject(listed));
          }
        }
      }
      closeProjectContractWorld(world);
    }
  });

  test('${_typePrefix}_find_project_property_unknown_identifiers_name_the_'
      'missing_project', () async {
    final Random random = seededRandom(85705);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final ProjectContractWorld world =
          await buildProjectWorldAfterRandomSteps(random);
      final ProjectId missing = ProjectId('missing ${randomText(random)}');

      for (final NamedProjectRepository implementation
          in world.implementations) {
        final Object? failure = await findStepFailure(
          () async => implementation.repository.findProject(missing),
        );
        expect(failure, isA<RecordNotFound>(), reason: implementation.name);
        expect((failure! as RecordNotFound).kind, projectKind);
        expect((failure as RecordNotFound).identifier, missing.value);
      }
      closeProjectContractWorld(world);
    }
  });

  test('${_typePrefix}_find_project_property_every_implementation_finds_'
      'the_same_seeded_project', () async {
    final Random random = seededRandom(85706);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final ProjectContractWorld world =
          await buildProjectWorldAfterRandomSteps(random);

      for (final Project seeded in world.twins.seeds.projects) {
        final String expected = describeProject(
          world.implementations.first.repository.findProject(seeded.id),
        );
        for (final NamedProjectRepository implementation
            in world.implementations) {
          expect(
            describeProject(implementation.repository.findProject(seeded.id)),
            expected,
            reason: implementation.name,
          );
        }
      }
      closeProjectContractWorld(world);
    }
  });

  test('${_typePrefix}_create_project_property_lists_the_new_project_once_'
      'in_its_workspace', () async {
    final Random random = seededRandom(85707);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final ProjectContractWorld world = await buildProjectContractWorld(
        random,
      );
      final ProjectDraft draft = randomContractProjectDraft(random, world);

      for (final NamedProjectRepository implementation
          in world.implementations) {
        final Project created = await implementation.repository.createProject(
          draft,
        );
        final Iterable<Project> listings = implementation.repository
            .listProjects(draft.workspaceId)
            .where((Project project) => project.id == created.id);
        expect(listings, hasLength(1), reason: implementation.name);
        expect(created.name, draft.name, reason: implementation.name);
        expect(created.workspaceId, draft.workspaceId);
        expect(listAddresses(created), <String>[
          for (final Repository repository in draft.repositories)
            repository.address,
        ], reason: implementation.name);
      }
      expectProjectListingsAgree(world);
      closeProjectContractWorld(world);
    }
  });

  test('${_typePrefix}_create_project_property_refuses_bad_names_without_'
      'change', () async {
    final Random random = seededRandom(85708);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final ProjectContractWorld world = await buildProjectContractWorld(
        random,
      );
      final ProjectDraft draft = _withName(
        randomContractProjectDraft(random, world),
        'Bad ${randomHostileText(random)}',
      );

      final List<ProjectStepOutcome> outcomes = await runOnProjectRepositories(
        world,
        (ProjectRepository repository) => repository.createProject(draft),
      );

      for (final ProjectStepOutcome outcome in outcomes) {
        expect(outcome.failure, isA<ArgumentError>(), reason: outcome.name);
      }
      expectProjectListingsAgree(world);
      closeProjectContractWorld(world);
    }
  });

  test('${_typePrefix}_create_project_property_every_implementation_'
      'accepts_and_refuses_alike', () async {
    final Random random = seededRandom(85709);
    for (int i = 0; i < projectSequenceIterations; i += 1) {
      final ProjectContractWorld world = await buildProjectContractWorld(
        random,
      );
      final ProjectDraft base = randomContractProjectDraft(random, world);
      final String name = random.nextBool()
          ? base.name
          : randomHostileText(random);
      final ProjectDraft draft = _withName(base, name);

      final List<ProjectStepOutcome> outcomes = await runOnProjectRepositories(
        world,
        (ProjectRepository repository) => repository.createProject(draft),
      );

      expectSameProjectOutcome(outcomes, label: 'create "$name"');
      expectProjectListingsAgree(world);
      closeProjectContractWorld(world);
    }
  });
}
