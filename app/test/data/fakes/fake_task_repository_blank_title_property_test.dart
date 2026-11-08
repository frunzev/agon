import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../../support/sample_records.dart';
import 'support/blank_task_titles.dart';
import 'support/notification_counter.dart';
import 'support/task_inputs.dart';
import 'support/task_rigs.dart';

const String _typePrefix = 'test_fake_task_repository';
const String _titleCore = 'T';

String _randomPaddedTitle(Random random, RuleTitleWhiteSpaceTable table) {
  return '${table.randomWhiteSpaceRun(random)}'
      '${table.randomExoticTitle(random)}$_titleCore'
      '${table.randomWhiteSpaceRun(random)}';
}

FakeTaskRepository _buildRepository(Random random) {
  return buildSeededTaskRepository(randomTaskSeed(random));
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  test('${_typePrefix}_create_task_property_refuses_exactly_the_node_blank_'
      'titles', () async {
    final Random random = seededRandom(90321);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = _buildRepository(random);
      final String title = table.randomExoticTitle(random);
      final TaskDraft draft = replaceDraftTitle(
        randomTaskDraft(random),
        title,
      );

      if (table.trimByModel(title).isEmpty) {
        await expectLater(
          repository.createTask(draft),
          throwsNodeBlankTitleRefusal,
        );
      } else {
        final Task created = await repository.createTask(draft);
        expect(created.title, title);
      }
      repository.dispose();
    }
  });

  test('${_typePrefix}_create_task_property_refusal_stores_nothing_and_'
      'stays_silent', () async {
    final Random random = seededRandom(90322);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = _buildRepository(random);
      final List<String> before = describeTaskRepository(repository);
      final NotificationCounter notifications = NotificationCounter();
      repository.addListener(notifications.record);
      final TaskDraft draft = replaceDraftTitle(
        randomTaskDraft(random),
        table.randomWhiteSpaceRun(random),
      );

      await expectLater(
        repository.createTask(draft),
        throwsNodeBlankTitleRefusal,
      );

      expect(describeTaskRepository(repository), before);
      expect(notifications.count, 0);
      repository.dispose();
    }
  });

  test('${_typePrefix}_create_task_property_accepted_titles_are_kept_'
      'verbatim', () async {
    final Random random = seededRandom(90323);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = _buildRepository(random);
      final String title = _randomPaddedTitle(random, table);
      final TaskDraft draft = replaceDraftTitle(
        randomTaskDraft(random),
        title,
      );

      final Task created = await repository.createTask(draft);

      expect(repository.findTask(created.id).title, title);
      repository.dispose();
    }
  });

  test('${_typePrefix}_update_task_property_refuses_exactly_the_node_blank_'
      'titles', () async {
    final Random random = seededRandom(90324);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = _buildRepository(random);
      final Task stored = await repository.createTask(randomTaskDraft(random));
      final String title = table.randomExoticTitle(random);
      final TaskDraft draft = replaceDraftTitle(
        randomTaskDraft(random),
        title,
      );

      if (table.trimByModel(title).isEmpty) {
        await expectLater(
          repository.updateTask(stored.id, draft),
          throwsNodeBlankTitleRefusal,
        );
      } else {
        final Task updated = await repository.updateTask(stored.id, draft);
        expect(updated.title, title);
      }
      repository.dispose();
    }
  });

  test('${_typePrefix}_update_task_property_refusal_keeps_the_stored_task_'
      'and_stays_silent', () async {
    final Random random = seededRandom(90325);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = _buildRepository(random);
      final Task stored = await repository.createTask(randomTaskDraft(random));
      final List<String> before = describeTaskRepository(repository);
      final NotificationCounter notifications = NotificationCounter();
      repository.addListener(notifications.record);
      final TaskDraft draft = replaceDraftTitle(
        randomTaskDraft(random),
        table.randomWhiteSpaceRun(random),
      );

      await expectLater(
        repository.updateTask(stored.id, draft),
        throwsNodeBlankTitleRefusal,
      );

      expect(describeTaskRepository(repository), before);
      expect(repository.findTask(stored.id).title, stored.title);
      expect(notifications.count, 0);
      repository.dispose();
    }
  });

  test('${_typePrefix}_update_task_property_blank_title_is_refused_before_'
      'the_task_is_looked_up', () async {
    final Random random = seededRandom(90326);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository repository = _buildRepository(random);
      final TaskId unknown = TaskId('unknown-${randomText(random)}');
      final TaskDraft draft = replaceDraftTitle(
        randomTaskDraft(random),
        table.randomWhiteSpaceRun(random),
      );

      await expectLater(
        repository.updateTask(unknown, draft),
        throwsNodeBlankTitleRefusal,
      );
      repository.dispose();
    }
  });
}
