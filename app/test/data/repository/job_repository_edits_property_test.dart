import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/blank_task_titles.dart';
import '../fakes/support/chat_inputs.dart';
import '../fakes/support/workspace_work_picks.dart';
import '../fakes/support/workspace_work_rig.dart';
import 'support/job_contract_rigs.dart';

const String _typePrefix = 'test_job_repository';

JobDraft _randomCurrentJobDraft(Random random, WorkspaceWorkRig rig) {
  final List<ProjectId> current = listCurrentWorkProjectIds(rig);
  final JobDraft draft = randomWorkJobDraft(random, rig.projects);
  if (current.isEmpty) {
    return draft;
  }
  final ProjectId projectId = pickOne(random, current);
  return JobDraft(
    task: randomWorkDraftIn(random, rig, projectId),
    schedule: draft.schedule,
  );
}

JobDraft _withTitle(JobDraft draft, String title) {
  return JobDraft(
    task: replaceDraftTitle(draft.task, title),
    schedule: draft.schedule,
  );
}

Future<Task> _createAndCheck(
  NamedJobRepository implementation,
  JobDraft draft,
) async {
  final Task created = await implementation.repository.createJob(draft);
  final List<String> identifiers = listJobIdentifiers(
    implementation.repository,
  );
  final Iterable<String> createdListings = identifiers.where(
    (String identifier) => identifier == created.id.value,
  );

  expect(createdListings, hasLength(1), reason: implementation.name);
  expect(created.title, draft.task.title, reason: implementation.name);
  expect(created.projectId, draft.task.projectId);
  expect(
    describeSchedule(created.schedule!),
    describeSchedule(draft.schedule),
    reason: implementation.name,
  );
  expect(created.status, TaskStatus.toDo, reason: implementation.name);
  return created;
}

Future<Task> _updateAndCheck(
  NamedJobRepository implementation,
  TaskId fakeId,
  JobDraft draft,
) async {
  final TaskId jobId = implementation.translate(fakeId);
  final Task before = implementation.repository.findJob(jobId);
  final Task updated = await implementation.repository.updateJob(jobId, draft);

  expect(updated.id, before.id, reason: implementation.name);
  expect(updated.status, before.status, reason: implementation.name);
  expect(updated.createdAt, before.createdAt, reason: implementation.name);
  expect(updated.title, draft.task.title, reason: implementation.name);
  expect(
    describeSchedule(updated.schedule!),
    describeSchedule(draft.schedule),
    reason: implementation.name,
  );
  return updated;
}

void main() {
  test('${_typePrefix}_create_job_property_lists_the_created_job_once_'
      'with_the_draft_content', () async {
    final Random random = seededRandom(85211);
    for (int i = 0; i < jobSequenceIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildJobRigAfterRandomSteps(random);
      final JobDraft draft = _randomCurrentJobDraft(random, rig);

      final List<JobStepOutcome> outcomes = await runOnEveryJobRepository(
        rig,
        (NamedJobRepository implementation) =>
            _createAndCheck(implementation, draft),
      );

      expectSameJobStepOutcome(outcomes);
      expectJobListingsAgree(rig);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_create_job_property_refuses_blank_titles_without_'
      'change', () async {
    final Random random = seededRandom(85212);
    for (int i = 0; i < jobSequenceIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildJobRigAfterRandomSteps(random);
      final JobDraft draft = _withTitle(
        _randomCurrentJobDraft(random, rig),
        pickOne(random, blankChatTexts),
      );
      final List<String> before = describeListedJobs(rig.fakeJobs);

      final List<JobStepOutcome> outcomes = await runOnEveryJobRepository(
        rig,
        (NamedJobRepository implementation) =>
            implementation.repository.createJob(draft),
      );

      expectEveryJobStepRefused(outcomes);
      expect(describeListedJobs(rig.fakeJobs), unorderedEquals(before));
      expectJobListingsAgree(rig);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_create_job_property_every_implementation_accepts_'
      'and_refuses_alike', () async {
    final Random random = seededRandom(85213);
    for (int i = 0; i < jobSequenceIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildJobRigAfterRandomSteps(random);
      final JobDraft draft = randomWorkJobDraft(random, rig.projects);

      final List<JobStepOutcome> outcomes = await runOnEveryJobRepository(
        rig,
        (NamedJobRepository implementation) =>
            implementation.repository.createJob(draft),
      );

      expectSameJobStepOutcome(outcomes);
      expectJobListingsAgree(rig);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_update_job_property_keeps_identity_and_takes_the_'
      'draft', () async {
    final Random random = seededRandom(85214);
    for (int i = 0; i < jobSequenceIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildJobRigAfterRandomSteps(random);
      final TaskId? fakeId = pickListedJobId(random, rig);
      final JobDraft draft = _randomCurrentJobDraft(random, rig);
      if (fakeId == null) {
        await closeWorkspaceWorkRig(rig);
        continue;
      }

      final List<JobStepOutcome> outcomes = await runOnEveryJobRepository(
        rig,
        (NamedJobRepository implementation) =>
            _updateAndCheck(implementation, fakeId, draft),
      );

      expectSameJobStepOutcome(outcomes);
      expectJobListingsAgree(rig);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_update_job_property_unknown_jobs_are_refused_'
      'without_change', () async {
    final Random random = seededRandom(85215);
    for (int i = 0; i < jobSequenceIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildJobRigAfterRandomSteps(random);
      final TaskId missing = TaskId('missing ${randomText(random)}');
      final JobDraft draft = _randomCurrentJobDraft(random, rig);
      final List<String> before = describeListedJobs(rig.fakeJobs);

      final List<JobStepOutcome> outcomes = await runOnEveryJobRepository(
        rig,
        (NamedJobRepository implementation) =>
            implementation.repository.updateJob(missing, draft),
      );

      expectEveryJobStepRefused(outcomes);
      expect(describeListedJobs(rig.fakeJobs), unorderedEquals(before));
      expectJobListingsAgree(rig);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_update_job_property_repeating_an_update_changes_'
      'nothing_more', () async {
    final Random random = seededRandom(85216);
    for (int i = 0; i < jobSequenceIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildJobRigAfterRandomSteps(random);
      final TaskId? fakeId = pickListedJobId(random, rig);
      final JobDraft draft = _randomCurrentJobDraft(random, rig);
      if (fakeId == null) {
        await closeWorkspaceWorkRig(rig);
        continue;
      }

      await runOnEveryJobRepository(
        rig,
        (NamedJobRepository implementation) => implementation.repository
            .updateJob(implementation.translate(fakeId), draft),
      );
      final List<String> once = describeListedJobs(rig.fakeJobs);
      final List<JobStepOutcome> again = await runOnEveryJobRepository(
        rig,
        (NamedJobRepository implementation) => implementation.repository
            .updateJob(implementation.translate(fakeId), draft),
      );

      expectSameJobStepOutcome(again);
      expect(describeListedJobs(rig.fakeJobs), unorderedEquals(once));
      expectJobListingsAgree(rig);
      await closeWorkspaceWorkRig(rig);
    }
  });
}
