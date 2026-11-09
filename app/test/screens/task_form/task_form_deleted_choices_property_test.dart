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
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import '../../support/random_inputs.dart';
import '../../support/random_signature_workflows.dart';
import 'task_form_scene.dart';

const String _deletedProjectLabel = 'Deleted project';
const String _deletedWorkflowLabel = 'Deleted workflow';
const String _deletedChoiceProblem =
    'This was deleted. Pick one from the list.';

final class _DeletedChoices {
  const _DeletedChoices({
    required this.initial,
    required this.options,
    required this.isProjectDeleted,
    required this.isDoerDeleted,
  });

  final TaskFormValues initial;
  final TaskFormOptions options;
  final bool isProjectDeleted;
  final bool isDoerDeleted;
}

_DeletedChoices _randomDeletedChoices(Random random) {
  final FakeWorkflowRepository workflowRepository =
      buildSignatureStateRepository(randomWorkflowsInSignatureStates(random));
  final List<Workflow> workflows = workflowRepository.listWorkflows();
  final Workflow deletedWorkflow = pickOne(random, workflows);
  final Project deletedProject = pickOne(random, galleryProjects);
  final int deletion = 1 + random.nextInt(3);
  final bool isProjectDeleted = deletion != 2;
  final bool isDoerDeleted = deletion != 1;
  final TaskFormOptions options = buildTaskFormOptions(
    projects: <Project>[
      for (final Project project in galleryProjects)
        if (!isProjectDeleted || project.id != deletedProject.id) project,
    ],
    workflows: <Workflow>[
      for (final Workflow workflow in workflows)
        if (!isDoerDeleted || workflow.id != deletedWorkflow.id) workflow,
    ],
    findPendingChange: workflowRepository.findPendingChange,
    runners: randomRunnersOnDistinctDevices(random),
    deviceNames: DeviceNames(galleryDevices),
    skills: gallerySkills,
    chosenTarget: const AnyFreeRunner(),
  );
  final TaskFormValues listed = randomSavableValues(random, options);
  return _DeletedChoices(
    initial: listed.copyWith(
      projectId: isProjectDeleted ? deletedProject.id : null,
      doer: isDoerDeleted ? WorkflowDoer(deletedWorkflow.id) : null,
    ),
    options: options,
    isProjectDeleted: isProjectDeleted,
    isDoerDeleted: isDoerDeleted,
  );
}

SelectField<T> _findSelect<T>(WidgetTester tester) {
  return tester.widget(find.byType(SelectField<T>));
}

String _readShownLabel<T>(WidgetTester tester) {
  final SelectField<T> field = _findSelect<T>(tester);
  return field.entries
      .whereType<SelectOption<T>>()
      .singleWhere((SelectOption<T> entry) => entry.value == field.value)
      .label;
}

Future<TaskFormScene> _pumpDeletedChoices(
  WidgetTester tester,
  Random random,
  _DeletedChoices choices,
) {
  return pumpTaskFormScene(
    tester,
    random: random,
    initialValues: choices.initial,
    options: choices.options,
    answerSubmit: answerAtOnce,
  );
}

void main() {
  testWidgets('test_pick_shown_choices_property_deleted_choice_stays_shown', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161401);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeletedChoices choices = _randomDeletedChoices(random);

      await _pumpDeletedChoices(tester, random, choices);

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(_findSelect<ProjectId>(tester).value, choices.initial.projectId);
      expect(_findSelect<TaskDoer>(tester).value, choices.initial.doer);
      if (choices.isProjectDeleted) {
        expect(_readShownLabel<ProjectId>(tester), _deletedProjectLabel);
      }
      if (choices.isDoerDeleted) {
        expect(_readShownLabel<TaskDoer>(tester), _deletedWorkflowLabel);
      }
    }
  });

  testWidgets('test_pick_shown_choices_property_problem_names_each_deleted', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161402);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeletedChoices choices = _randomDeletedChoices(random);
      final int deletedCount =
          (choices.isProjectDeleted ? 1 : 0) + (choices.isDoerDeleted ? 1 : 0);

      await _pumpDeletedChoices(tester, random, choices);

      expect(find.text(_deletedChoiceProblem), findsNWidgets(deletedCount));
    }
  });

  testWidgets('test_pick_shown_choices_property_listed_choices_no_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161403);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);

      await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: randomSavableValues(random, options),
        options: options,
        answerSubmit: answerAtOnce,
      );

      expect(find.text(_deletedChoiceProblem), findsNothing);
      expect(find.text(_deletedProjectLabel), findsNothing);
      expect(find.text(_deletedWorkflowLabel), findsNothing);
    }
  });

  testWidgets('test_task_form_submit_property_deleted_choice_never_saved', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161404);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeletedChoices choices = _randomDeletedChoices(random);
      final TaskFormScene scene = await _pumpDeletedChoices(
        tester,
        random,
        choices,
      );

      await tapTaskFormSubmit(tester);
      await tapTaskFormSubmit(tester);

      expect(scene.submitted, isEmpty, reason: 'round $i');
    }
  });

  testWidgets('test_task_form_submit_property_listed_pick_saves_it_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1161405);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeletedChoices choices = _randomDeletedChoices(random);
      final TaskFormScene scene = await _pumpDeletedChoices(
        tester,
        random,
        choices,
      );
      final TaskFormValues listed = randomSavableValues(
        random,
        choices.options,
      );

      _findSelect<ProjectId>(tester).onChanged(listed.projectId);
      await tester.pump();
      _findSelect<TaskDoer>(tester).onChanged(listed.doer);
      await tester.pump();
      await tapTaskFormSubmit(tester);

      expect(find.text(_deletedChoiceProblem), findsNothing);
      expect(scene.submitted, hasLength(1), reason: 'round $i');
      expect(scene.submitted.single.projectId, listed.projectId);
      expect(scene.submitted.single.doer, listed.doer);
    }
  });
}
