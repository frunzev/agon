import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/route_records.dart';

import '../support/app_harness.dart';
import '../support/fake_task_work_links.dart';
import '../support/random_inputs.dart';
import 'route_record_samples.dart';

const int _identifierSpan = 1 << 20;
const String _gonePrefix = 'gone-';

bool _isMissing(AppRoute route, AppDependencies dependencies) {
  return isRouteRecordMissing(route: route, dependencies: dependencies);
}

AppDependencies _buildEmptyDependencies() {
  final AppDependencies withoutTasks = buildDependenciesWithoutTasks();
  return replaceRepositories(
    withoutTasks,
    projectRepository: buildProjectRepositoryOver(
      withoutTasks,
      const <Project>[],
    ),
  );
}

void main() {
  test('test_is_route_record_missing_property_pages_without_records_are_'
      'never_missing', () {
    final Random random = seededRandom(5311001);
    final List<AppDependencies> dependencyChoices = <AppDependencies>[
      buildGalleryDependencies(),
      _buildEmptyDependencies(),
    ];

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = pickOne(random, dependencyChoices);
      final AppRoute route = pickOne(random, listPagesWithoutRecords(random));

      expect(_isMissing(route, dependencies), isFalse, reason: '$route');
    }
  });

  test('test_is_route_record_missing_property_matches_the_stored_records', () {
    final Random random = seededRandom(5311002);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final SampledRoute sample = sampleRecordRoute(random, dependencies);

      expect(
        _isMissing(sample.route, dependencies),
        sample.usesUnknownRecord,
        reason: '${sample.route.runtimeType} ${sample.route.identity}',
      );
    }
  });

  test('test_is_route_record_missing_property_deleting_a_record_misses_only_'
      'its_pages', () async {
    final Random random = seededRandom(5311003);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final List<Skill> skills = dependencies.skillRepository.listSkills();
      final List<Rule> rules = dependencies.ruleRepository.listRules();
      final Skill deletedSkill = pickOne(random, skills);
      final Rule deletedRule = pickOne(random, rules);

      await dependencies.skillRepository.deleteSkill(deletedSkill.id);
      await dependencies.ruleRepository.deleteRule(deletedRule.id);

      for (final Skill skill in skills) {
        final bool isDeleted = skill.id == deletedSkill.id;
        expect(
          _isMissing(SkillDetailRoute(skill.id), dependencies),
          isDeleted,
        );
        expect(_isMissing(EditSkillRoute(skill.id), dependencies), isDeleted);
      }
      for (final Rule rule in rules) {
        final bool isDeleted = rule.id == deletedRule.id;
        expect(_isMissing(RuleDetailRoute(rule.id), dependencies), isDeleted);
        expect(_isMissing(EditRuleRoute(rule.id), dependencies), isDeleted);
      }
    }
  });

  test('test_look_up_route_records_property_a_runner_page_needs_its_runner_'
      'in_this_workspace', () async {
    final Random random = seededRandom(5311004);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final DeviceId currentDeviceId = dependencies.deviceRepository
          .currentDevice()
          .id;
      final List<Runner> otherRunners = <Runner>[
        for (final Runner runner
            in dependencies.runnerRepository.listRunners())
          if (runner.deviceId != currentDeviceId) runner,
      ];
      final Runner removed = pickOne(random, otherRunners);
      final RunnerDetailRoute route = RunnerDetailRoute(removed.deviceId);
      final bool wasMissing = _isMissing(route, dependencies);

      await dependencies.deviceRepository.removeDeviceFromWorkspace(
        removed.deviceId,
        dependencies.workspaceRepository.currentWorkspace().id,
      );

      expect(wasMissing, isFalse);
      expect(_isMissing(route, dependencies), isTrue);
    }
  });

  test('test_look_up_route_records_property_presets_must_still_exist', () {
    final Random random = seededRandom(5311005);
    final AppDependencies dependencies = buildGalleryDependencies();
    final WorkspaceId workspaceId = dependencies.workspaceRepository
        .currentWorkspace()
        .id;
    final List<Project> projects = dependencies.projectRepository.listProjects(
      workspaceId,
    );
    final List<Workflow> workflows = dependencies.workflowRepository
        .listWorkflows();

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool usesUnknown = random.nextBool();
      final String unknown = '$_gonePrefix${random.nextInt(_identifierSpan)}';
      final ProjectId projectId = usesUnknown
          ? ProjectId(unknown)
          : pickOne(random, projects).id;
      final WorkflowId workflowId = usesUnknown
          ? WorkflowId(unknown)
          : pickOne(random, workflows).id;
      final List<AppRoute> presetPages = <AppRoute>[
        NewRuleRoute(presetProjectId: projectId),
        NewItemFormRoute(DraftKind.rule, presetProjectId: projectId),
        NewItemFormRoute(DraftKind.task, presetWorkflowId: workflowId),
        NewWorkflowTaskRoute(workflowId),
      ];

      final AppRoute route = pickOne(random, presetPages);

      expect(_isMissing(route, dependencies), usesUnknown, reason: '$route');
    }
  });

  test('test_look_up_route_records_property_files_pages_follow_their_'
      'project', () async {
    final Random random = seededRandom(5311006);

    for (int i = 0; i < propertyIterations ~/ 10; i += 1) {
      final AppDependencies gallery = buildGalleryDependencies();
      final WorkspaceId workspaceId = gallery.workspaceRepository
          .currentWorkspace()
          .id;
      final List<Project> projects = gallery.projectRepository.listProjects(
        workspaceId,
      );
      final AppDependencies dependencies = replaceRepositories(
        gallery,
        projectRepository: FakeProjectRepository(
          projects: projects,
          taskWork: buildEmptyTaskWork(),
        ),
      );
      final Project project = pickOne(random, projects);
      final ProjectFilesRoute filesRoute = ProjectFilesRoute(
        projectId: project.id,
        repositoryAddress: randomText(random),
      );
      final RepositoryFileRoute fileRoute = RepositoryFileRoute(
        filesRoute: filesRoute,
        source: FilesFromRunner(
          runnerId: DeviceId('runner-${random.nextInt(9)}'),
          runnerName: randomText(random),
          branches: const <String>[],
          taskBranches: const <String>[],
        ),
        branch: randomText(random),
        path: randomText(random),
      );
      final List<AppRoute> projectPages = <AppRoute>[
        ProjectRoute(project.id),
        filesRoute,
        fileRoute,
      ];
      final bool wasMissing = projectPages.any(
        (AppRoute route) => _isMissing(route, dependencies),
      );

      await dependencies.projectRepository.deleteProject(project.id);

      expect(wasMissing, isFalse);
      for (final AppRoute route in projectPages) {
        expect(_isMissing(route, dependencies), isTrue, reason: '$route');
      }
    }
  });
}
