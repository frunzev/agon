import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../../screens/support/planned_refusal.dart';
import '../../../screens/support/refusing_place_repositories.dart';
import '../../../support/fake_task_work_links.dart';
import '../../../support/random_inputs.dart';
import '../../../support/workflow_repositories.dart';
import '../../fakes/support/catalog_twin_steps.dart';
import '../../fakes/support/catalog_twin_world.dart';
import '../../fakes/support/project_inputs.dart';
import '../../fakes/support/task_inputs.dart';
import 'contract_step_failures.dart';

const String projectKind = 'project';
const int projectSequenceIterations = 12;
const int _longestSequence = 5;
const int _largestNameNumber = 1000;

typedef NamedProjectRepository = ({String name, ProjectRepository repository});

typedef ProjectStep = Future<Object?> Function(ProjectRepository repository);

typedef ProjectStepOutcome = ({String name, Object? failure});

typedef ProjectContractWorld = ({
  CatalogTwinWorld twins,
  List<NamedProjectRepository> implementations,
});

FakeProjectRepository _buildSeededFake(CatalogTwinWorld twins) {
  final FakeTaskRepository tasks = buildTaskRepository(
    tasks: twins.seeds.tasks,
    runs: twins.seeds.runs,
    workflows: buildGalleryWorkflowRepository(),
  );
  return FakeProjectRepository(
    projects: twins.seeds.projects,
    taskWork: buildTaskWorkOver(tasks),
  );
}

Future<ProjectContractWorld> buildProjectContractWorld(Random random) async {
  final CatalogTwinWorld twins = await buildCatalogTwinWorld(random);
  return (
    twins: twins,
    implementations: <NamedProjectRepository>[
      (name: 'fake', repository: twins.fakeProjects),
      (name: 'node backed', repository: twins.nodeProjects),
      (
        name: 'refusing double',
        repository: RefusingProjectRepository(
          stored: _buildSeededFake(twins),
          refusal: PlannedRefusal(),
        ),
      ),
    ],
  );
}

String describeProject(Project project) {
  return '${project.workspaceId.value} ${project.name} '
      '${listAddresses(project)} ${project.approvalPolicy}';
}

List<String> describeProjectsIn(
  ProjectRepository repository,
  WorkspaceId workspaceId,
) {
  return <String>[
    for (final Project project in repository.listProjects(workspaceId))
      describeProject(project),
  ];
}

void expectProjectListingsAgree(ProjectContractWorld world) {
  for (final WorkspaceId workspaceId in world.twins.seeds.workspaceIds) {
    final List<String> expected = describeProjectsIn(
      world.implementations.first.repository,
      workspaceId,
    );
    for (final NamedProjectRepository implementation
        in world.implementations) {
      expect(
        describeProjectsIn(implementation.repository, workspaceId),
        unorderedEquals(expected),
        reason: '${implementation.name} in ${workspaceId.value}',
      );
    }
  }
}

Future<List<ProjectStepOutcome>> runOnProjectRepositories(
  ProjectContractWorld world,
  ProjectStep step,
) async {
  final List<ProjectStepOutcome> outcomes = <ProjectStepOutcome>[];
  for (final NamedProjectRepository implementation in world.implementations) {
    final Object? failure = await findStepFailure(
      () => step(implementation.repository),
    );
    outcomes.add((name: implementation.name, failure: failure));
  }
  return outcomes;
}

void expectSameProjectOutcome(
  List<ProjectStepOutcome> outcomes, {
  required String label,
}) {
  final bool isFirstRefused = outcomes.first.failure != null;
  for (final ProjectStepOutcome outcome in outcomes) {
    expect(outcome.failure != null, isFirstRefused, reason: '$label $outcome');
    if (outcome.failure != null) {
      final bool isExpected =
          isContractRefusal(outcome.failure) ||
          outcome.failure is RecordNotFound;
      expect(isExpected, isTrue, reason: '$label $outcome');
    }
  }
}

Project? pickSeededProject(Random random, ProjectContractWorld world) {
  final Set<ProjectId> listed = <ProjectId>{
    for (final WorkspaceId workspaceId in world.twins.seeds.workspaceIds)
      for (final Project project in world.twins.fakeProjects.listProjects(
        workspaceId,
      ))
        project.id,
  };
  final List<Project> seeded = <Project>[
    for (final Project project in world.twins.seeds.projects)
      if (listed.contains(project.id))
        world.twins.fakeProjects.findProject(project.id),
  ];
  if (seeded.isEmpty) {
    return null;
  }
  return pickOne(random, seeded);
}

ProjectDraft randomContractProjectDraft(
  Random random,
  ProjectContractWorld world,
) {
  return ProjectDraft(
    workspaceId: pickOne(random, world.twins.seeds.workspaceIds),
    name: 'project-${random.nextInt(_largestNameNumber)}',
    repositories: randomDistinctRepositories(random),
    approvalPolicy: null,
  );
}

Future<void> runRandomProjectStep(
  Random random,
  ProjectContractWorld world,
) async {
  final Project? project = pickSeededProject(random, world);
  final ProjectId projectId = project?.id ?? missingTwinProjectId;
  final ProjectDraft draft = randomContractProjectDraft(random, world);
  final Repository repository = randomRepositoryAt(
    random,
    randomCanonicalAddress(random),
  );
  final List<String> addresses = project == null
      ? <String>[repository.address]
      : <String>[...listAddresses(project), repository.address];
  final String address = pickOne(random, addresses);
  final List<({String label, ProjectStep step})> steps =
      <({String label, ProjectStep step})>[
        (
          label: 'create',
          step: (ProjectRepository projects) => projects.createProject(draft),
        ),
        (
          label: 'add to ${projectId.value}',
          step: (ProjectRepository projects) =>
              projects.addRepository(projectId, repository),
        ),
        (
          label: 'remove $address from ${projectId.value}',
          step: (ProjectRepository projects) =>
              projects.removeRepository(projectId, address),
        ),
      ];
  final ({String label, ProjectStep step}) chosen = pickOne(random, steps);
  final List<ProjectStepOutcome> outcomes = await runOnProjectRepositories(
    world,
    chosen.step,
  );
  expectSameProjectOutcome(outcomes, label: chosen.label);
}

Future<ProjectContractWorld> buildProjectWorldAfterRandomSteps(
  Random random,
) async {
  final ProjectContractWorld world = await buildProjectContractWorld(random);
  final int stepCount = random.nextInt(_longestSequence);
  for (int step = 0; step < stepCount; step += 1) {
    await runRandomProjectStep(random, world);
  }
  return world;
}

void closeProjectContractWorld(ProjectContractWorld world) {
  closeCatalogTwinWorld(world.twins);
}
