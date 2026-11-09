import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../support/random_inputs.dart';
import 'task_form_scene.dart';
import 'task_form_values_inputs.dart';

const String _deletedPrefix = 'deleted-';
const String _deletedProjectLabel = 'Deleted project';
const String _deletedWorkflowLabel = 'Deleted workflow';

DraftedWork _replaceChoices(
  DraftedWork work, {
  required ProjectId? projectId,
  required TaskDoer doer,
}) {
  return DraftedWork(
    title: work.title,
    details: work.details,
    projectId: projectId,
    doer: doer,
    runsOn: work.runsOn,
    agentPlace: work.agentPlace,
    skills: work.skills,
    usesAutomaticSkills: work.usesAutomaticSkills,
    approvalPolicy: work.approvalPolicy,
    schedule: work.schedule,
  );
}

DraftedWork _randomListedWork(Random random, TaskFormOptions options) {
  return draftFromValues(randomTaskFormValues(random, options), null);
}

ProjectId _randomDeletedProjectId(Random random) {
  return ProjectId('$_deletedPrefix${randomText(random)}');
}

TaskDoer _randomDeletedWorkflowDoer(Random random) {
  return WorkflowDoer(WorkflowId('$_deletedPrefix${randomText(random)}'));
}

TaskFormValues _readDraft(DraftedWork work, TaskFormOptions options) {
  return TaskFormValues.fromDraftedWork(
    work: work,
    options: options,
    unscheduledRepeat: RepeatChoice.none,
  );
}

List<String> _listLabels<T>(List<SelectEntry<T>> entries, T value) {
  final List<String> labels = <String>[];
  for (final SelectEntry<T> entry in entries) {
    if (entry is SelectOption<T> && entry.value == value) {
      labels.add(entry.label);
    }
  }
  return labels;
}

void main() {
  test('test_from_drafted_work_property_deleted_project_is_kept_and_'
      'shown_as_deleted', () {
    final Random random = seededRandom(1190401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final DraftedWork listed = _randomListedWork(random, options);
      final ProjectId deletedProjectId = _randomDeletedProjectId(random);
      final DraftedWork work = _replaceChoices(
        listed,
        projectId: deletedProjectId,
        doer: listed.doer,
      );

      final TaskFormValues values = _readDraft(work, options);

      expect(values.projectId, deletedProjectId);
      expect(options.describeProjectProblem(values.projectId), isNotNull);
      expect(
        _listLabels(
          options.listProjectChoices(values.projectId),
          values.projectId,
        ),
        <String>[_deletedProjectLabel],
      );
      expect(values.doer, listed.doer);
    }
  });

  test('test_from_drafted_work_property_deleted_workflow_is_kept_and_'
      'shown_as_deleted', () {
    final Random random = seededRandom(1190402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final DraftedWork listed = _randomListedWork(random, options);
      final TaskDoer deletedDoer = _randomDeletedWorkflowDoer(random);
      final DraftedWork work = _replaceChoices(
        listed,
        projectId: listed.projectId,
        doer: deletedDoer,
      );

      final TaskFormValues values = _readDraft(work, options);

      expect(values.doer, deletedDoer);
      expect(options.describeDoerProblem(values.doer), isNotNull);
      expect(
        _listLabels(options.listDoerChoices(values.doer), values.doer),
        <String>[_deletedWorkflowLabel],
      );
      expect(values.projectId, listed.projectId);
    }
  });

  test('test_from_drafted_work_property_missing_project_takes_the_first_'
      'listed_one', () {
    final Random random = seededRandom(1190403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final DraftedWork listed = _randomListedWork(random, options);
      final TaskDoer doer = random.nextBool()
          ? listed.doer
          : _randomDeletedWorkflowDoer(random);
      final DraftedWork work = _replaceChoices(
        listed,
        projectId: null,
        doer: doer,
      );

      final TaskFormValues values = _readDraft(work, options);

      expect(values.projectId, options.firstProjectId);
      expect(options.describeProjectProblem(values.projectId), isNull);
      expect(values.doer, doer);
    }
  });
}
