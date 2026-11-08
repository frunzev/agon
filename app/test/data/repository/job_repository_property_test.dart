import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/job_inputs.dart';
import '../fakes/support/workspace_work_rig.dart';
import 'support/contract_step_failures.dart';
import 'support/job_contract_rigs.dart';

const String _typePrefix = 'test_job_repository';

void main() {
  test('${_typePrefix}_list_jobs_property_lists_unique_scheduled_jobs_of_'
      'the_current_workspace', () async {
    final Random random = seededRandom(85201);
    for (int i = 0; i < jobSequenceIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildJobRigAfterRandomSteps(random);
      final Set<ProjectId> currentProjects = listCurrentProjectIds(rig);

      for (final NamedJobRepository implementation in listJobImplementations(
        rig,
      )) {
        final List<Task> jobs = implementation.repository.listJobs();
        final List<String> identifiers = listJobIdentifiers(
          implementation.repository,
        );
        expect(identifiers.toSet(), hasLength(identifiers.length));
        for (final Task job in jobs) {
          expect(job.schedule, isNotNull, reason: implementation.name);
          expect(
            currentProjects,
            contains(job.projectId),
            reason: implementation.name,
          );
        }
      }
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_list_jobs_property_callers_cannot_change_the_'
      'listing', () async {
    final Random random = seededRandom(85202);
    for (int i = 0; i < jobSequenceIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildJobRigAfterRandomSteps(random);

      for (final NamedJobRepository implementation in listJobImplementations(
        rig,
      )) {
        final List<Task> listed = implementation.repository.listJobs();
        final List<String> before = listJobIdentifiers(
          implementation.repository,
        );
        final Object? failure = await findStepFailure(
          () async => listed.clear(),
        );

        expect(failure, isA<UnsupportedError>(), reason: implementation.name);
        expect(
          listJobIdentifiers(implementation.repository),
          orderedEquals(before),
          reason: implementation.name,
        );
      }
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_list_jobs_property_every_implementation_lists_the_'
      'same_jobs', () async {
    final Random random = seededRandom(85203);
    for (int i = 0; i < jobSequenceIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildJobRigAfterRandomSteps(random);

      expectJobListingsAgree(rig);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_find_job_property_finds_every_listed_job_as_'
      'listed', () async {
    final Random random = seededRandom(85204);
    for (int i = 0; i < jobSequenceIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildJobRigAfterRandomSteps(random);

      for (final NamedJobRepository implementation in listJobImplementations(
        rig,
      )) {
        for (final Task listed in implementation.repository.listJobs()) {
          final Task found = implementation.repository.findJob(listed.id);
          expect(found.id, listed.id, reason: implementation.name);
          expect(
            describeJobContent(found),
            describeJobContent(listed),
            reason: implementation.name,
          );
        }
      }
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_find_job_property_unknown_identifiers_name_the_'
      'missing_job', () async {
    final Random random = seededRandom(85205);
    for (int i = 0; i < jobSequenceIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildJobRigAfterRandomSteps(random);
      final TaskId missing = TaskId('missing ${randomText(random)}');

      for (final NamedJobRepository implementation in listJobImplementations(
        rig,
      )) {
        final Object? failure = await findStepFailure(
          () async => implementation.repository.findJob(missing),
        );
        expect(failure, isA<RecordNotFound>(), reason: implementation.name);
        final RecordNotFound notFound = failure! as RecordNotFound;
        expect(notFound.kind, jobKind);
        expect(notFound.identifier, missing.value);
      }
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_find_job_property_plain_tasks_are_never_found_as_'
      'jobs', () async {
    final Random random = seededRandom(85206);
    for (int i = 0; i < jobSequenceIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildJobRigAfterRandomSteps(random);

      for (final TaskId plainTaskId in listStoredPlainTaskIds(rig)) {
        for (final NamedJobRepository implementation in listJobImplementations(
          rig,
        )) {
          final TaskId asked = implementation.translate(plainTaskId);
          final Object? failure = await findStepFailure(
            () async => implementation.repository.findJob(asked),
          );
          expect(failure, isA<RecordNotFound>(), reason: implementation.name);
        }
      }
      await closeWorkspaceWorkRig(rig);
    }
  });
}
