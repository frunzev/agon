import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';
import 'package:agent_orchestration/widgets/forms/tag_input_field.dart';

import '../../support/random_inputs.dart';
import '../../support/random_signature_workflows.dart';
import 'task_form_scene.dart';

const String _goneSkillPrefix = 'gone-skill-';
const int _mostGoneSkills = 3;

TaskFormOptions _buildOptions({
  required Random random,
  required List<Project> projects,
  required FakeWorkflowRepository workflowRepository,
  required List<Workflow> workflows,
}) {
  return buildTaskFormOptions(
    projects: projects,
    workflows: workflows,
    findPendingChange: workflowRepository.findPendingChange,
    runners: randomRunnersOnDistinctDevices(random),
    deviceNames: DeviceNames(galleryDevices),
    skills: gallerySkills,
    chosenTarget: const AnyFreeRunner(),
  );
}

List<Project> _projectsWithout(Random random, ProjectId lostProjectId) {
  final List<Project> kept = <Project>[
    for (final Project project in galleryProjects)
      if (project.id != lostProjectId && random.nextBool()) project,
  ];
  if (kept.isEmpty) {
    return <Project>[
      for (final Project project in galleryProjects)
        if (project.id != lostProjectId) project,
    ];
  }
  return kept;
}

List<T> _readShownEntries<T>(WidgetTester tester) {
  final SelectField<T> field = tester.widget(find.byType(SelectField<T>));
  return listOptionValues(field.entries);
}

T _readShownValue<T>(WidgetTester tester) {
  final SelectField<T> field = tester.widget(find.byType(SelectField<T>));
  return field.value;
}

void main() {
  testWidgets('test_pick_shown_choices_property_lost_choices_never_assert', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131901);
    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final FakeWorkflowRepository workflowRepository =
          buildSignatureStateRepository(
            randomWorkflowsInSignatureStates(random),
          );
      final List<Workflow> workflows = workflowRepository.listWorkflows();
      final TaskFormOptions options = _buildOptions(
        random: random,
        projects: galleryProjects,
        workflowRepository: workflowRepository,
        workflows: workflows,
      );
      final TaskFormValues initial = randomTaskFormValues(random, options);
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: initial,
        options: options,
        answerSubmit: answerAtOnce,
      );
      final TaskFormOptions shrunk = _buildOptions(
        random: random,
        projects: _projectsWithout(random, initial.projectId),
        workflowRepository: workflowRepository,
        workflows: <Workflow>[
          for (final Workflow workflow in workflows)
            if (WorkflowDoer(workflow.id) != initial.doer) workflow,
        ],
      );

      await repumpInSameWindow(
        tester,
        scene.buildForm(initialValues: initial, options: shrunk),
      );

      expect(tester.takeException(), isNull, reason: 'round $i');
      final ProjectId shownProject = _readShownValue<ProjectId>(tester);
      final TaskDoer shownDoer = _readShownValue<TaskDoer>(tester);
      expect(shownProject, initial.projectId);
      expect(shownDoer, initial.doer);
      expect(_readShownEntries<ProjectId>(tester), contains(shownProject));
      expect(_readShownEntries<TaskDoer>(tester), contains(shownDoer));
      final bool isDoerDeleted = initial.doer is WorkflowDoer;
      await tapTaskFormSubmit(tester);
      expect(scene.submitted, isEmpty);
      expect(
        find.text(deletedChoiceProblem),
        findsNWidgets(isDoerDeleted ? 2 : 1),
      );
    }
  });

  testWidgets('test_pick_shown_choices_property_unknown_skills_never_saved', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131902);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskFormValues listed = randomSavableValues(random, options);
      final int goneCount = 1 + random.nextInt(_mostGoneSkills);
      final List<SkillId> skillIds = <SkillId>[
        ...listed.skillIds,
        for (int gone = 0; gone < goneCount; gone += 1)
          SkillId('$_goneSkillPrefix$gone'),
      ]..shuffle(random);
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: listed.copyWith(skillIds: skillIds),
        options: options,
        answerSubmit: answerAtOnce,
      );

      await tapTaskFormSubmit(tester);

      final List<SkillId> saved = scene.submitted.single.skillIds;
      expect(saved, options.pickShownSkills(skillIds));
      final TagInputField tags = tester.widget(find.byType(TagInputField));
      expect(tags.tags, options.describeSkills(saved));
    }
  });

  testWidgets('test_pick_shown_choices_property_listed_choices_are_kept', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131903);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkflowRepository workflowRepository =
          buildSignatureStateRepository(
            randomWorkflowsInSignatureStates(random),
          );
      final List<Workflow> workflows = workflowRepository.listWorkflows();
      final TaskFormOptions options = _buildOptions(
        random: random,
        projects: galleryProjects,
        workflowRepository: workflowRepository,
        workflows: workflows,
      );
      final TaskFormValues initial = randomSavableValues(random, options);
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: initial,
        options: options,
        answerSubmit: answerAtOnce,
      );

      await repumpInSameWindow(
        tester,
        scene.buildForm(
          initialValues: initial,
          options: _buildOptions(
            random: random,
            projects: galleryProjects,
            workflowRepository: workflowRepository,
            workflows: workflows,
          ),
        ),
      );
      await tapTaskFormSubmit(tester);

      final TaskFormValues saved = scene.submitted.single;
      expect(saved.projectId, initial.projectId);
      expect(saved.doer, initial.doer);
      expect(saved.skillIds, initial.skillIds);
    }
  });
}
