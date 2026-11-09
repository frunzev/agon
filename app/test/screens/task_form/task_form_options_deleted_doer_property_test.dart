import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/folder_runner_notice.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/workflow_to_sign.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../support/random_inputs.dart';
import 'task_form_scene.dart';

const String _deletedWorkflowLabel = 'Deleted workflow';
const String _deletedChoiceProblem =
    'This was deleted. Pick one from the list.';

TaskDoer _randomDeletedWorkflowDoer(Random random) {
  return WorkflowDoer(WorkflowId('deleted-${randomText(random)}'));
}

TaskDoer _randomShownDoer(Random random, TaskFormOptions options) {
  if (random.nextBool()) {
    return _randomDeletedWorkflowDoer(random);
  }
  return pickOne(random, listOptionValues(options.doers));
}

TaskFormOptions _buildOptionsWithoutDoers() {
  return TaskFormOptions(
    projects: const <SelectOption<ProjectId>>[],
    doers: const <SelectEntry<TaskDoer>>[],
    runners: const <SelectOption<RunnerTarget>>[],
    skills: gallerySkills,
    missingFolderRunners: const <ProjectId, MissingFolderRunner>{},
    workflowsToSign: const <WorkflowId, WorkflowToSign>{},
    deviceNames: DeviceNames(const <Device>[]),
  );
}

int _countDoerChoices(List<SelectEntry<TaskDoer>> entries, TaskDoer doer) {
  int count = 0;
  for (final TaskDoer listed in listOptionValues(entries)) {
    if (listed == doer) {
      count += 1;
    }
  }
  return count;
}

void main() {
  test('test_list_doer_choices_property_listed_doer_keeps_the_list', () {
    final Random random = seededRandom(1161201);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);

      for (final TaskDoer doer in listOptionValues(options.doers)) {
        expect(options.listDoerChoices(doer), options.doers);
      }
    }
  });

  test('test_list_doer_choices_property_deleted_workflow_labelled_last', () {
    final Random random = seededRandom(1161202);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskDoer deleted = _randomDeletedWorkflowDoer(random);

      final List<SelectEntry<TaskDoer>> entries = options.listDoerChoices(
        deleted,
      );

      expect(entries.sublist(0, entries.length - 1), options.doers);
      final SelectEntry<TaskDoer> last = entries.last;
      expect(last, isA<SelectOption<TaskDoer>>());
      final SelectOption<TaskDoer> deletedChoice =
          last as SelectOption<TaskDoer>;
      expect(deletedChoice.value, deleted);
      expect(deletedChoice.label, _deletedWorkflowLabel);
      expect(deletedChoice.isEnabled, isFalse);
    }
  });

  test('test_list_doer_choices_property_shown_doer_listed_once', () {
    final Random random = seededRandom(1161203);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = random.nextInt(4) == 0
          ? _buildOptionsWithoutDoers()
          : buildRandomTaskFormOptions(random);
      final TaskDoer shown = options.doers.isEmpty
          ? OneAgentDoer(pickOne(random, AgentKind.values))
          : _randomShownDoer(random, options);

      final List<SelectEntry<TaskDoer>> entries = options.listDoerChoices(
        shown,
      );

      expect(_countDoerChoices(entries, shown), 1);
      for (final TaskDoer listed in listOptionValues(options.doers)) {
        expect(_countDoerChoices(entries, listed), 1);
      }
      final SelectOption<TaskDoer> shownChoice = entries
          .whereType<SelectOption<TaskDoer>>()
          .singleWhere((SelectOption<TaskDoer> entry) => entry.value == shown);
      expect(shownChoice.label, isNotEmpty);
    }
  });

  test('test_describe_doer_problem_property_listed_doers_are_fine', () {
    final Random random = seededRandom(1161204);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);

      for (final TaskDoer doer in listOptionValues(options.doers)) {
        expect(options.describeDoerProblem(doer), isNull);
      }
    }
  });

  test('test_describe_doer_problem_property_deleted_workflow_refused', () {
    final Random random = seededRandom(1161205);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskDoer shown = _randomShownDoer(random, options);
      final bool isListed = listOptionValues(options.doers).contains(shown);

      final String? problem = options.describeDoerProblem(shown);

      expect(problem, isListed ? isNull : _deletedChoiceProblem);
    }
  });

  test('test_describe_doer_problem_property_agrees_with_disabled_choice', () {
    final Random random = seededRandom(1161206);
    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskDoer shown = _randomShownDoer(random, options);

      final SelectOption<TaskDoer> shownChoice = options
          .listDoerChoices(shown)
          .whereType<SelectOption<TaskDoer>>()
          .singleWhere((SelectOption<TaskDoer> entry) => entry.value == shown);
      final String? problem = options.describeDoerProblem(shown);

      expect(problem == null, shownChoice.isEnabled);
    }
  });
}
