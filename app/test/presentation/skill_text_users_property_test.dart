import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/skill_text.dart';

import '../support/random_inputs.dart';
import '../support/random_scope_catalogs.dart';
import '../support/random_workflows.dart';
import '../support/sample_records.dart';

const String _unusedLabel = 'Not used yet';
const int _mostTasks = 6;
const int _mostWorkflows = 4;

Task _taskWithSkills(Random random, List<SkillId> skills) {
  final TaskDraft draft = randomTaskDraft(random);
  return Task(
    id: TaskId('task-${random.nextInt(1 << 30)}'),
    title: draft.title,
    details: draft.details,
    projectId: draft.projectId,
    doer: draft.doer,
    runsOn: draft.runsOn,
    agentPlace: draft.agentPlace,
    skills: skills,
    usesAutomaticSkills: draft.usesAutomaticSkills,
    approvalPolicy: draft.approvalPolicy,
    schedule: null,
    status: pickOne(random, TaskStatus.values),
    createdAt: randomUtcMoment(random),
  );
}

List<Task> _randomTasks(Random random) {
  final int taskCount = random.nextInt(_mostTasks);
  return <Task>[
    for (int i = 0; i < taskCount; i += 1)
      _taskWithSkills(random, randomTaskDraft(random).skills),
  ];
}

List<Workflow> _randomNamedWorkflows(Random random) {
  final int workflowCount = random.nextInt(_mostWorkflows);
  return <Workflow>[
    for (int i = 0; i < workflowCount; i += 1)
      randomAcyclicWorkflow(random)
          .withName(randomUniqueHostileName(random, i)),
  ];
}

bool _usesSkill(Workflow workflow, SkillId skillId) {
  for (final WorkflowAgent agent in workflow.agents) {
    if (agent.skills.contains(skillId)) {
      return true;
    }
  }
  return false;
}

int _countUsing(List<Task> tasks, SkillId skillId) {
  int count = 0;
  for (final Task task in tasks) {
    if (task.skills.contains(skillId)) {
      count += 1;
    }
  }
  return count;
}

String _expectedUsers({
  required SkillId skillId,
  required List<Workflow> workflows,
  required List<Task> jobs,
  required List<Task> tasks,
}) {
  final int jobCount = _countUsing(jobs, skillId);
  final int taskCount = _countUsing(tasks, skillId);
  final List<String> parts = <String>[
    for (final Workflow workflow in workflows)
      if (_usesSkill(workflow, skillId)) workflow.name,
    if (jobCount == 1) '1 job',
    if (jobCount > 1) '$jobCount jobs',
    if (taskCount == 1) '1 task',
    if (taskCount > 1) '$taskCount tasks',
  ];
  return parts.isEmpty ? _unusedLabel : parts.join(', ');
}

void main() {
  test('test_count_tasks_using_property_singular_only_for_one', () {
    final Random random = seededRandom(94311);

    for (int count = 0; count < _mostTasks * 2; count += 1) {
      final SkillId skillId = pickOne(random, sampleSkillIds);
      final List<Task> jobs = <Task>[
        for (int i = 0; i < count; i += 1)
          _taskWithSkills(random, <SkillId>[skillId]),
      ];

      final String users = describeSkillUsers(
        skillId: skillId,
        workflows: const <Workflow>[],
        jobs: jobs,
        tasks: const <Task>[],
      );

      expect(users, switch (count) {
        0 => _unusedLabel,
        1 => '1 job',
        _ => '$count jobs',
      });
    }
  });

  test('test_count_tasks_using_property_repeated_skill_counts_once', () {
    final Random random = seededRandom(94312);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillId skillId = pickOne(random, sampleSkillIds);
      final int repeats = 1 + random.nextInt(4);
      final Task task = _taskWithSkills(random, <SkillId>[
        for (int j = 0; j < repeats; j += 1) skillId,
      ]);

      expect(
        describeSkillUsers(
          skillId: skillId,
          workflows: const <Workflow>[],
          jobs: const <Task>[],
          tasks: <Task>[task],
        ),
        '1 task',
      );
    }
  });

  test('test_count_tasks_using_property_unrelated_work_changes_nothing', () {
    final Random random = seededRandom(94313);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillId skillId = pickOne(random, sampleSkillIds);
      final List<Workflow> workflows = _randomNamedWorkflows(random);
      final List<Task> jobs = _randomTasks(random);
      final List<Task> tasks = _randomTasks(random);
      final List<SkillId> otherSkills = <SkillId>[
        for (final SkillId candidate in sampleSkillIds)
          if (candidate != skillId) candidate,
      ];
      final Task unrelated = _taskWithSkills(random, otherSkills);

      final String before = describeSkillUsers(
        skillId: skillId,
        workflows: workflows,
        jobs: jobs,
        tasks: tasks,
      );
      final String after = describeSkillUsers(
        skillId: skillId,
        workflows: workflows,
        jobs: <Task>[...jobs, unrelated],
        tasks: <Task>[unrelated, ...tasks],
      );

      expect(after, before);
    }
  });

  test('test_does_workflow_use_property_listed_once_when_any_agent_uses', () {
    final Random random = seededRandom(94314);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillId skillId = pickOne(random, sampleSkillIds);
      final List<Workflow> workflows = _randomNamedWorkflows(random);

      final String users = describeSkillUsers(
        skillId: skillId,
        workflows: workflows,
        jobs: const <Task>[],
        tasks: const <Task>[],
      );

      final List<String> listedNames = <String>[
        for (final Workflow workflow in workflows)
          if (_usesSkill(workflow, skillId)) workflow.name,
      ];
      final String expected = listedNames.isEmpty
          ? _unusedLabel
          : listedNames.join(', ');
      expect(users, expected);
    }
  });

  test(
    'test_does_workflow_use_property_workflow_without_agents_is_unused',
    () {
      final Random random = seededRandom(94315);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow workflow = randomAcyclicWorkflow(random).withGraph(
          agents: const <WorkflowAgent>[],
          connections: const <AgentConnection>[],
        );

        expect(
          describeSkillUsers(
            skillId: pickOne(random, sampleSkillIds),
            workflows: <Workflow>[workflow],
            jobs: const <Task>[],
            tasks: const <Task>[],
          ),
          _unusedLabel,
        );
      }
    },
  );

  test('test_does_workflow_use_property_order_follows_given_workflows', () {
    final Random random = seededRandom(94316);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillId skillId = pickOne(random, sampleSkillIds);
      final List<Workflow> workflows = _randomNamedWorkflows(random);
      final List<Workflow> reversed = workflows.reversed.toList();
      final List<String> usingNames = <String>[
        for (final Workflow workflow in reversed)
          if (_usesSkill(workflow, skillId)) workflow.name,
      ];
      if (usingNames.isEmpty) {
        continue;
      }

      expect(
        describeSkillUsers(
          skillId: skillId,
          workflows: reversed,
          jobs: const <Task>[],
          tasks: const <Task>[],
        ),
        usingNames.join(', '),
      );
    }
  });

  test('test_describe_skill_users_property_matches_reference_model', () {
    final Random random = seededRandom(94317);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillId skillId = pickOne(random, sampleSkillIds);
      final List<Workflow> workflows = _randomNamedWorkflows(random);
      final List<Task> jobs = _randomTasks(random);
      final List<Task> tasks = _randomTasks(random);

      expect(
        describeSkillUsers(
          skillId: skillId,
          workflows: workflows,
          jobs: jobs,
          tasks: tasks,
        ),
        _expectedUsers(
          skillId: skillId,
          workflows: workflows,
          jobs: jobs,
          tasks: tasks,
        ),
      );
    }
  });

  test('test_describe_skill_users_property_never_shows_the_skill_id', () {
    final Random random = seededRandom(94318);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillId skillId = pickOne(random, sampleSkillIds);
      final List<Task> jobs = _randomTasks(random);
      final List<Task> tasks = _randomTasks(random);

      final String users = describeSkillUsers(
        skillId: skillId,
        workflows: _randomNamedWorkflows(random),
        jobs: jobs,
        tasks: tasks,
      );

      expect(users, isNot(contains(skillId.value)));
      expect(users.trim(), isNotEmpty);
      for (final Task task in <Task>[...jobs, ...tasks]) {
        expect(users, isNot(contains(task.id.value)));
      }
    }
  });
}
