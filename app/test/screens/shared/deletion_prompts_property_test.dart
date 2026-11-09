import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/screens/shared/deletion_prompts.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

typedef _NamedPrompt = ({String name, DeletionPrompt prompt});

const String _nextWorkspaceName = 'personal';

final class _DeletionCase {
  const _DeletionCase({
    required this.functionName,
    required this.kind,
    required this.isQuoted,
    required this.designedExplanation,
    required this.describeEvery,
  });

  final String functionName;
  final String kind;
  final bool isQuoted;
  final String designedExplanation;
  final List<_NamedPrompt> Function() describeEvery;
}

Workspace _findNextWorkspace() {
  return galleryWorkspaces.firstWhere(
    (Workspace workspace) => workspace.name == _nextWorkspaceName,
  );
}

List<_NamedPrompt> _describeEveryProject() => <_NamedPrompt>[
  for (final Project project in galleryProjects)
    (name: project.name, prompt: describeProjectDeletion(project)),
];

List<_NamedPrompt> _describeEveryWorkflow() => <_NamedPrompt>[
  for (final Workflow workflow in galleryWorkflows)
    (name: workflow.name, prompt: describeWorkflowDeletion(workflow)),
];

List<_NamedPrompt> _describeEveryTask() => <_NamedPrompt>[
  for (final Task task in galleryTasks)
    (name: task.title, prompt: describeTaskDeletion(task)),
];

List<_NamedPrompt> _describeEveryJob() => <_NamedPrompt>[
  for (final Task job in galleryJobs)
    (name: job.title, prompt: describeJobDeletion(job)),
];

List<_NamedPrompt> _describeEverySkill() => <_NamedPrompt>[
  for (final Skill skill in gallerySkills)
    (
      name: skill.name,
      prompt: describeSkillDeletion(skill: skill, users: skill.summary),
    ),
];

List<_NamedPrompt> _describeEveryRule() => <_NamedPrompt>[
  for (final Rule rule in galleryRules)
    (name: rule.title, prompt: describeRuleDeletion(rule)),
];

List<_NamedPrompt> _describeEveryWorkspace() => <_NamedPrompt>[
  for (final Workspace workspace in galleryWorkspaces)
    (
      name: workspace.name,
      prompt: describeWorkspaceDeletion(
        doomed: workspace,
        next: _findNextWorkspace(),
      ),
    ),
];

const List<_DeletionCase> _deletionCases = <_DeletionCase>[
  _DeletionCase(
    functionName: 'describe_project_deletion',
    kind: 'project',
    isQuoted: false,
    designedExplanation:
        'Its tasks and jobs go with it, with their runs, logs and chats. '
        "The code stays in its repos. A project with a running task can't "
        'be deleted.',
    describeEvery: _describeEveryProject,
  ),
  _DeletionCase(
    functionName: 'describe_workflow_deletion',
    kind: 'workflow',
    isQuoted: false,
    designedExplanation:
        "It leaves every workspace it's in, with its signed version. A "
        "workflow that tasks or jobs still use can't be deleted.",
    describeEvery: _describeEveryWorkflow,
  ),
  _DeletionCase(
    functionName: 'describe_task_deletion',
    kind: 'task',
    isQuoted: true,
    designedExplanation:
        'Its runs go with it, with their logs and chats. Branches already '
        "pushed stay in their repos. A running task can't be deleted.",
    describeEvery: _describeEveryTask,
  ),
  _DeletionCase(
    functionName: 'describe_job_deletion',
    kind: 'job',
    isQuoted: true,
    designedExplanation:
        'It stops repeating, and its runs go with it, with their logs and '
        "chats. A job with a run in progress can't be deleted.",
    describeEvery: _describeEveryJob,
  ),
  _DeletionCase(
    functionName: 'describe_skill_deletion',
    kind: 'skill',
    isQuoted: false,
    designedExplanation:
        'Agents stop using it. Tasks, jobs and workflows that chose it keep '
        'running without it.',
    describeEvery: _describeEverySkill,
  ),
  _DeletionCase(
    functionName: 'describe_rule_deletion',
    kind: 'rule',
    isQuoted: true,
    designedExplanation:
        'Agents stop getting it in AGENTS.md from their next run.',
    describeEvery: _describeEveryRule,
  ),
  _DeletionCase(
    functionName: 'describe_workspace_deletion',
    kind: 'workspace',
    isQuoted: false,
    designedExplanation:
        'Its projects go with it, with their tasks, jobs and runs, and so '
        'do the skills, rules and workflows only it can use. Your devices '
        "stay paired. You switch to personal. The last workspace can't be "
        'deleted, nor one with a running task.',
    describeEvery: _describeEveryWorkspace,
  ),
];

void _registerDeletionCase(_DeletionCase deletionCase) {
  final String prefix = 'test_${deletionCase.functionName}_property';

  test('${prefix}_labels_name_the_kind', () {
    for (final _NamedPrompt named in deletionCase.describeEvery()) {
      expect(named.prompt.keepLabel, 'Keep ${deletionCase.kind}');
      expect(named.prompt.deleteLabel, 'Delete ${deletionCase.kind}');
    }
  });

  test('${prefix}_explanation_matches_the_design', () {
    for (final _NamedPrompt named in deletionCase.describeEvery()) {
      expect(named.prompt.explanation, deletionCase.designedExplanation);
    }
  });

  test('${prefix}_title_quotes_only_free_text', () {
    for (final _NamedPrompt named in deletionCase.describeEvery()) {
      final String shownName = deletionCase.isQuoted
          ? '"${named.name}"'
          : named.name;

      expect(named.prompt.title, 'Delete $shownName?');
    }
  });
}

void main() {
  _deletionCases.forEach(_registerDeletionCase);

  test('test_deletion_prompt_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(111501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Fact> facts = <Fact>[
        Fact(
          term: randomHostileText(random),
          description: <TextSegment>[TextSegment(randomText(random))],
        ),
      ];
      final String title = randomHostileText(random);
      final String explanation = randomHostileText(random);
      final String keepLabel = randomText(random);
      final String deleteLabel = randomText(random);

      final DeletionPrompt prompt = DeletionPrompt(
        title: title,
        explanation: explanation,
        keepLabel: keepLabel,
        deleteLabel: deleteLabel,
        facts: facts,
      );

      expect(prompt.title, title);
      expect(prompt.explanation, explanation);
      expect(prompt.keepLabel, keepLabel);
      expect(prompt.deleteLabel, deleteLabel);
      expect(prompt.facts, same(facts));
    }
  });

  test('test_deletion_prompt_constructor_property_has_no_facts_by_'
      'default', () {
    final Random random = seededRandom(111502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeletionPrompt prompt = DeletionPrompt(
        title: randomText(random),
        explanation: randomText(random),
        keepLabel: randomText(random),
        deleteLabel: randomText(random),
      );

      expect(prompt.facts, isEmpty);
    }
  });

  test('test_deletion_prompt_constructor_property_only_skills_list_'
      'facts', () {
    for (final _DeletionCase deletionCase in _deletionCases) {
      for (final _NamedPrompt named in deletionCase.describeEvery()) {
        final bool isSkill = deletionCase.kind == 'skill';

        expect(named.prompt.facts, hasLength(isSkill ? 1 : 0));
        expect(
          named.prompt.keepLabel,
          isNot(named.prompt.deleteLabel),
          reason: deletionCase.kind,
        );
      }
    }
  });
}
