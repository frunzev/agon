import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../../support/sample_records.dart';
import 'support/blank_task_titles.dart';
import 'support/job_inputs.dart';

const String _typePrefix = 'test_fake_job_repository';
const String _titleCore = 'J';

JobDraft _randomJobDraftTitled(Random random, String title) {
  return JobDraft(
    task: replaceDraftTitle(randomTaskDraft(random), title),
    schedule: randomJobSchedule(random),
  );
}

String _randomPaddedTitle(Random random, RuleTitleWhiteSpaceTable table) {
  return '${table.randomWhiteSpaceRun(random)}$_titleCore'
      '${table.randomExoticTitle(random)}'
      '${table.randomWhiteSpaceRun(random)}';
}

CountedJobs _buildCountedJobs(Random random) {
  return buildCountedJobRepository(random, randomStoredRecords(random));
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  test('${_typePrefix}_create_job_property_refuses_exactly_the_node_blank_'
      'titles', () async {
    final Random random = seededRandom(90331);
    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = _buildCountedJobs(random);
      final String title = table.randomExoticTitle(random);
      final JobDraft draft = _randomJobDraftTitled(random, title);

      if (table.trimByModel(title).isEmpty) {
        await expectLater(
          counted.repository.createJob(draft),
          throwsNodeBlankTitleRefusal,
        );
      } else {
        final Task created = await counted.repository.createJob(draft);
        expect(created.title, title);
      }
      counted.taskRepository.dispose();
    }
  });

  test('${_typePrefix}_create_job_property_refusal_stores_nothing_and_'
      'stays_silent', () async {
    final Random random = seededRandom(90332);
    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = _buildCountedJobs(random);
      final List<String> before = describeTaskIds(
        counted.taskRepository.listTasksAndJobs(),
      );
      final JobDraft draft = _randomJobDraftTitled(
        random,
        table.randomWhiteSpaceRun(random),
      );

      await expectLater(
        counted.repository.createJob(draft),
        throwsNodeBlankTitleRefusal,
      );

      expect(
        describeTaskIds(counted.taskRepository.listTasksAndJobs()),
        before,
      );
      expect(counted.notifications.count, 0);
      counted.taskRepository.dispose();
    }
  });

  test('${_typePrefix}_create_job_property_accepted_titles_are_kept_'
      'verbatim', () async {
    final Random random = seededRandom(90333);
    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = _buildCountedJobs(random);
      final String title = _randomPaddedTitle(random, table);

      final Task created = await counted.repository.createJob(
        _randomJobDraftTitled(random, title),
      );

      expect(counted.repository.findJob(created.id).title, title);
      counted.taskRepository.dispose();
    }
  });

  test('${_typePrefix}_update_job_property_refuses_exactly_the_node_blank_'
      'titles', () async {
    final Random random = seededRandom(90334);
    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = _buildCountedJobs(random);
      final Task stored = await counted.repository.createJob(
        randomJobDraft(random),
      );
      final String title = table.randomExoticTitle(random);
      final JobDraft draft = _randomJobDraftTitled(random, title);

      if (table.trimByModel(title).isEmpty) {
        await expectLater(
          counted.repository.updateJob(stored.id, draft),
          throwsNodeBlankTitleRefusal,
        );
      } else {
        final Task updated = await counted.repository.updateJob(
          stored.id,
          draft,
        );
        expect(updated.title, title);
      }
      counted.taskRepository.dispose();
    }
  });

  test('${_typePrefix}_update_job_property_refusal_keeps_the_stored_job_and_'
      'stays_silent', () async {
    final Random random = seededRandom(90335);
    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = _buildCountedJobs(random);
      final Task stored = await counted.repository.createJob(
        randomJobDraft(random),
      );
      final int notificationsBefore = counted.notifications.count;
      final String contentBefore = describeJobContent(stored);
      final JobDraft draft = _randomJobDraftTitled(
        random,
        table.randomWhiteSpaceRun(random),
      );

      await expectLater(
        counted.repository.updateJob(stored.id, draft),
        throwsNodeBlankTitleRefusal,
      );

      expect(
        describeJobContent(counted.repository.findJob(stored.id)),
        contentBefore,
      );
      expect(counted.notifications.count, notificationsBefore);
      counted.taskRepository.dispose();
    }
  });

  test('${_typePrefix}_update_job_property_blank_title_is_refused_before_'
      'the_job_is_looked_up', () async {
    final Random random = seededRandom(90336);
    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedJobs counted = _buildCountedJobs(random);
      final TaskId unknown = TaskId('unknown-${randomText(random)}');
      final JobDraft draft = _randomJobDraftTitled(
        random,
        table.randomWhiteSpaceRun(random),
      );

      await expectLater(
        counted.repository.updateJob(unknown, draft),
        throwsNodeBlankTitleRefusal,
      );
      counted.taskRepository.dispose();
    }
  });
}
