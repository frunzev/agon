import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/folder_runner_notice.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/workflow_to_sign.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'task_form_scene.dart';

const int _mostProjects = 6;
const String _unknownPrefix = 'unknown-';

List<SelectOption<ProjectId>> _randomProjectOptions(Random random) {
  final int count = 1 + random.nextInt(_mostProjects);
  return <SelectOption<ProjectId>>[
    for (int index = 0; index < count; index += 1)
      SelectOption<ProjectId>(
        value: ProjectId('project-$index-${random.nextInt(1000)}'),
        label: randomHostileText(random),
      ),
  ];
}

const List<SelectOption<ProjectId>> _noProjects = <SelectOption<ProjectId>>[];
const Map<WorkflowId, WorkflowToSign> _noWorkflowsToSign =
    <WorkflowId, WorkflowToSign>{};

TaskFormOptions _buildOptions({
  required List<SelectOption<ProjectId>> projects,
  required Map<WorkflowId, WorkflowToSign> workflowsToSign,
}) {
  return TaskFormOptions(
    projects: projects,
    doers: const <SelectEntry<TaskDoer>>[],
    runners: const <SelectOption<RunnerTarget>>[],
    skills: gallerySkills,
    missingFolderRunners: const <ProjectId, MissingFolderRunner>{},
    workflowsToSign: workflowsToSign,
    deviceNames: DeviceNames(const <Device>[]),
  );
}

TaskFormOptions _buildSkillOptions() {
  return _buildOptions(
    projects: _noProjects,
    workflowsToSign: _noWorkflowsToSign,
  );
}

TaskFormOptions _buildProjectOptions(List<SelectOption<ProjectId>> projects) {
  return _buildOptions(
    projects: projects,
    workflowsToSign: _noWorkflowsToSign,
  );
}

List<SkillId> _randomSkillIds(Random random) {
  final List<SkillId> listed = <SkillId>[
    for (final Skill skill in gallerySkills) skill.id,
  ];
  final int count = random.nextInt(listed.length * 2);
  final List<SkillId> skillIds = <SkillId>[];
  for (int index = 0; index < count; index += 1) {
    if (random.nextBool()) {
      skillIds.add(pickOne(random, listed));
    } else {
      skillIds.add(SkillId('$_unknownPrefix${random.nextInt(4)}'));
    }
  }
  return skillIds;
}

ProjectId? _randomProjectChoice(Random random, TaskFormOptions options) {
  return pickOne(random, <ProjectId?>[
    null,
    ProjectId('$_unknownPrefix${random.nextInt(4)}'),
    pickOne(random, options.projects).value,
  ]);
}

void main() {
  test('test_first_project_id_property_is_the_first_listed_project', () {
    final Random random = seededRandom(1132001);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SelectOption<ProjectId>> projects = _randomProjectOptions(
        random,
      );

      final TaskFormOptions options = _buildProjectOptions(projects);

      expect(options.firstProjectId, projects.first.value);
    }
  });

  test('test_first_project_id_property_later_projects_change_nothing', () {
    final Random random = seededRandom(1132002);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SelectOption<ProjectId>> projects = _randomProjectOptions(
        random,
      );
      final List<SelectOption<ProjectId>> longer = <SelectOption<ProjectId>>[
        ...projects,
        ..._randomProjectOptions(random),
      ];

      final ProjectId first = _buildProjectOptions(projects).firstProjectId;
      final ProjectId firstOfLonger = _buildProjectOptions(longer)
          .firstProjectId;

      expect(firstOfLonger, first);
    }
  });

  test('test_find_workflow_to_sign_property_single_agents_never_sign', () {
    final Random random = seededRandom(1132003);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);

      for (final AgentKind agent in AgentKind.values) {
        expect(options.findWorkflowToSign(OneAgentDoer(agent)), isNull);
      }
    }
  });

  test('test_find_workflow_to_sign_property_returns_the_stored_entry', () {
    final Random random = seededRandom(1132004);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<WorkflowId, WorkflowToSign> workflowsToSign =
          <WorkflowId, WorkflowToSign>{
            for (final WorkflowId workflowId in sampleWorkflowIds)
              if (random.nextBool())
                workflowId: WorkflowToSign(
                  name: randomHostileText(random),
                  signRoute: WorkflowChangeRoute(workflowId),
                ),
          };
      final TaskFormOptions options = _buildOptions(
        projects: _noProjects,
        workflowsToSign: workflowsToSign,
      );

      for (final WorkflowId workflowId in sampleWorkflowIds) {
        final WorkflowToSign? found = options.findWorkflowToSign(
          WorkflowDoer(workflowId),
        );
        expect(found, same(workflowsToSign[workflowId]));
      }
    }
  });

  test('test_describe_skills_property_names_each_listed_skill_once', () {
    final Random random = seededRandom(1132005);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SkillId> skillIds = _randomSkillIds(random);
      final TaskFormOptions options = _buildSkillOptions();

      final List<String> names = options.describeSkills(skillIds);

      final List<String> expectedNames = <String>[
        for (final Skill skill in gallerySkills)
          if (skillIds.contains(skill.id)) skill.name,
      ];
      expect(names.toSet(), expectedNames.toSet());
      expect(names, hasLength(expectedNames.length));
    }
  });

  test('test_describe_skills_property_unknown_ids_add_no_names', () {
    final Random random = seededRandom(1132006);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SkillId> skillIds = _randomSkillIds(random);
      final TaskFormOptions options = _buildSkillOptions();
      final List<SkillId> listedOnly = options.pickShownSkills(skillIds);

      expect(
        options.describeSkills(skillIds),
        options.describeSkills(listedOnly),
      );
      expect(options.describeSkills(const <SkillId>[]), isEmpty);
    }
  });

  test('test_find_skill_id_property_unknown_names_are_refused', () {
    final Random random = seededRandom(1132007);
    final Set<String> names = <String>{
      for (final Skill skill in gallerySkills) skill.name,
    };
    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomHostileText(random);
      final TaskFormOptions options = _buildSkillOptions();

      if (names.contains(name)) {
        continue;
      }
      expect(() => options.findSkillId(name), throwsArgumentError);
    }
  });

  test('test_find_skill_id_property_names_must_match_exactly', () {
    final Random random = seededRandom(1132008);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Skill skill = pickOne(random, gallerySkills);
      final TaskFormOptions options = _buildSkillOptions();
      final List<String> nearNames = <String>[
        ' ${skill.name}',
        '${skill.name} ',
        skill.name.toUpperCase(),
        '${skill.name}​',
      ];

      expect(options.findSkillId(skill.name), skill.id);
      for (final String nearName in nearNames) {
        expect(() => options.findSkillId(nearName), throwsArgumentError);
      }
    }
  });

  test('test_pick_shown_project_property_listed_projects_stay', () {
    final Random random = seededRandom(1132009);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = _buildProjectOptions(
        _randomProjectOptions(random),
      );

      for (final SelectOption<ProjectId> project in options.projects) {
        expect(options.pickShownProject(project.value), project.value);
      }
    }
  });

  test('test_pick_shown_project_property_always_listed_and_idempotent', () {
    final Random random = seededRandom(1132010);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = _buildProjectOptions(
        _randomProjectOptions(random),
      );
      final ProjectId? choice = _randomProjectChoice(random, options);

      final ProjectId shown = options.pickShownProject(choice);

      expect(listOptionValues(options.projects), contains(shown));
      expect(options.pickShownProject(shown), shown);
    }
  });

  test('test_pick_shown_doer_property_listed_doers_stay', () {
    final Random random = seededRandom(1132011);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);

      for (final TaskDoer doer in listOptionValues(options.doers)) {
        expect(options.pickShownDoer(doer), doer);
      }
    }
  });

  test('test_pick_shown_doer_property_always_listed_and_idempotent', () {
    final Random random = seededRandom(1132012);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskDoer doer = pickOne(random, <TaskDoer>[
        randomTaskDoer(random),
        WorkflowDoer(WorkflowId('$_unknownPrefix${random.nextInt(4)}')),
      ]);

      final TaskDoer shown = options.pickShownDoer(doer);

      expect(listOptionValues(options.doers), contains(shown));
      expect(options.pickShownDoer(shown), shown);
    }
  });
}
