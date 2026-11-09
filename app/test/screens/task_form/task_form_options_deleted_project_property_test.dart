import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/folder_runner_notice.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/workflow_to_sign.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'task_form_scene.dart';

const String _deletedProjectLabel = 'Deleted project';
const String _deletedChoiceProblem =
    'This was deleted. Pick one from the list.';
const int _mostProjects = 6;

List<SelectOption<ProjectId>> _randomProjectOptions(Random random) {
  final int count = random.nextInt(_mostProjects);
  return <SelectOption<ProjectId>>[
    for (int index = 0; index < count; index += 1)
      SelectOption<ProjectId>(
        value: ProjectId('project-$index'),
        label: randomHostileText(random),
      ),
  ];
}

TaskFormOptions _buildProjectOptions(List<SelectOption<ProjectId>> projects) {
  return TaskFormOptions(
    projects: projects,
    doers: const <SelectEntry<TaskDoer>>[],
    runners: const <SelectOption<RunnerTarget>>[],
    skills: gallerySkills,
    missingFolderRunners: const <ProjectId, MissingFolderRunner>{},
    workflowsToSign: const <WorkflowId, WorkflowToSign>{},
    deviceNames: DeviceNames(const <Device>[]),
  );
}

ProjectId _randomDeletedProjectId(Random random) {
  return ProjectId('deleted-${randomText(random)}');
}

ProjectId _randomShownProjectId(Random random, TaskFormOptions options) {
  if (options.projects.isEmpty || random.nextBool()) {
    return _randomDeletedProjectId(random);
  }
  return pickOne(random, options.projects).value;
}

int _countChoices(List<SelectOption<ProjectId>> choices, ProjectId value) {
  int count = 0;
  for (final SelectOption<ProjectId> choice in choices) {
    if (choice.value == value) {
      count += 1;
    }
  }
  return count;
}

void main() {
  test('test_list_project_choices_property_listed_choice_keeps_the_list', () {
    final Random random = seededRandom(1161101);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = _buildProjectOptions(
        _randomProjectOptions(random),
      );

      for (final SelectOption<ProjectId> project in options.projects) {
        expect(options.listProjectChoices(project.value), options.projects);
      }
    }
  });

  test(
    'test_list_project_choices_property_deleted_choice_is_labelled_last',
    () {
      final Random random = seededRandom(1161102);
      for (int i = 0; i < propertyIterations; i += 1) {
        final TaskFormOptions options = _buildProjectOptions(
          _randomProjectOptions(random),
        );
        final ProjectId deleted = _randomDeletedProjectId(random);

        final List<SelectOption<ProjectId>> choices = options
            .listProjectChoices(deleted);

        expect(choices.sublist(0, choices.length - 1), options.projects);
        expect(choices.last.value, deleted);
        expect(choices.last.label, _deletedProjectLabel);
        expect(choices.last.isEnabled, isFalse);
      }
    },
  );

  test('test_list_project_choices_property_shown_choice_listed_once', () {
    final Random random = seededRandom(1161103);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = _buildProjectOptions(
        _randomProjectOptions(random),
      );
      final ProjectId shown = _randomShownProjectId(random, options);

      final List<SelectOption<ProjectId>> choices = options.listProjectChoices(
        shown,
      );

      expect(_countChoices(choices, shown), 1);
      for (final SelectOption<ProjectId> project in options.projects) {
        expect(_countChoices(choices, project.value), 1);
      }
    }
  });

  test('test_describe_project_problem_property_listed_projects_are_fine', () {
    final Random random = seededRandom(1161104);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = _buildProjectOptions(
        _randomProjectOptions(random),
      );

      for (final SelectOption<ProjectId> project in options.projects) {
        expect(options.describeProjectProblem(project.value), isNull);
      }
    }
  });

  test('test_describe_project_problem_property_deleted_project_refused', () {
    final Random random = seededRandom(1161105);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = _buildProjectOptions(
        _randomProjectOptions(random),
      );
      final ProjectId shown = _randomShownProjectId(random, options);
      final bool isListed = listOptionValues(options.projects).contains(shown);

      final String? problem = options.describeProjectProblem(shown);

      expect(problem, isListed ? isNull : _deletedChoiceProblem);
    }
  });

  test('test_describe_project_problem_property_listing_it_clears_problem', () {
    final Random random = seededRandom(1161106);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SelectOption<ProjectId>> projects = _randomProjectOptions(
        random,
      );
      final ProjectId deleted = _randomDeletedProjectId(random);
      final List<SelectOption<ProjectId>> withDeleted =
          List<SelectOption<ProjectId>>.of(projects);
      withDeleted.insert(
        random.nextInt(projects.length + 1),
        SelectOption<ProjectId>(value: deleted, label: randomText(random)),
      );

      final String? before = _buildProjectOptions(projects)
          .describeProjectProblem(deleted);
      final String? after = _buildProjectOptions(withDeleted)
          .describeProjectProblem(deleted);

      expect(before, _deletedChoiceProblem);
      expect(after, isNull);
    }
  });
}
