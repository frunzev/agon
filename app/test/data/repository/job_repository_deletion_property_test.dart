import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/workspace_work_rig.dart';
import 'support/job_contract_rigs.dart';

const String _typePrefix = 'test_job_repository';

void main() {
  test('${_typePrefix}_delete_job_property_removes_exactly_that_'
      'job', () async {
    final Random random = seededRandom(85217);
    for (int i = 0; i < jobSequenceIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildJobRigAfterRandomSteps(random);
      final TaskId? fakeId = pickListedJobId(random, rig);
      if (fakeId == null) {
        await closeWorkspaceWorkRig(rig);
        continue;
      }

      for (final NamedJobRepository implementation in listJobImplementations(
        rig,
      )) {
        final TaskId jobId = implementation.translate(fakeId);
        final List<String> before = listJobIdentifiers(
          implementation.repository,
        );
        await implementation.repository.deleteJob(jobId);
        final List<String> expected = <String>[
          for (final String identifier in before)
            if (identifier != jobId.value) identifier,
        ];
        expect(
          listJobIdentifiers(implementation.repository),
          unorderedEquals(expected),
          reason: implementation.name,
        );
      }
      expectJobListingsAgree(rig);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_delete_job_property_a_deleted_job_cannot_be_'
      'deleted_again', () async {
    final Random random = seededRandom(85218);
    for (int i = 0; i < jobSequenceIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildJobRigAfterRandomSteps(random);
      final TaskId? fakeId = pickListedJobId(random, rig);
      if (fakeId == null) {
        await closeWorkspaceWorkRig(rig);
        continue;
      }

      await runOnEveryJobRepository(
        rig,
        (NamedJobRepository implementation) => implementation.repository
            .deleteJob(implementation.translate(fakeId)),
      );
      final List<JobStepOutcome> again = await runOnEveryJobRepository(
        rig,
        (NamedJobRepository implementation) => implementation.repository
            .deleteJob(implementation.translate(fakeId)),
      );

      for (final JobStepOutcome outcome in again) {
        expect(outcome.failure, isA<RecordNotFound>(), reason: outcome.name);
      }
      expectJobListingsAgree(rig);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('${_typePrefix}_delete_job_property_plain_tasks_are_not_deleted_'
      'as_jobs', () async {
    final Random random = seededRandom(85219);
    for (int i = 0; i < jobSequenceIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildJobRigAfterRandomSteps(random);
      final List<TaskId> plainTaskIds = listStoredPlainTaskIds(rig);
      if (plainTaskIds.isEmpty) {
        await closeWorkspaceWorkRig(rig);
        continue;
      }
      final TaskId fakeId = pickOne(random, plainTaskIds);

      final List<JobStepOutcome> outcomes = await runOnEveryJobRepository(
        rig,
        (NamedJobRepository implementation) => implementation.repository
            .deleteJob(implementation.translate(fakeId)),
      );

      for (final JobStepOutcome outcome in outcomes) {
        expect(outcome.failure, isA<RecordNotFound>(), reason: outcome.name);
      }
      expect(listStoredPlainTaskIds(rig), contains(fakeId));
      await closeWorkspaceWorkRig(rig);
    }
  });
}
