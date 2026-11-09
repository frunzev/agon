import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/random_approval_requests.dart';

const int _largestCommitCount = 3000;
const String _runlessSubject = 'An agent';

String _randomRunLabel(Random random) {
  return pickOne(random, <String>[
    'release #${random.nextInt(1000)}',
    '${randomHostileText(random)} #${random.nextInt(99)}',
  ]);
}

String? _randomOptionalRunLabel(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return _randomRunLabel(random);
}

String _subjectFor(String? runLabel) {
  if (runLabel == null) {
    return _runlessSubject;
  }
  return 'The agent in $runLabel';
}

String _describeCommits(int count) {
  return describeCount(count, singular: 'commit', plural: 'commits');
}

PushCommitsAction _pushWithCommitCount(Random random, int commitCount) {
  final PushCommitsAction base = randomPushAction(random);
  return PushCommitsAction(
    repository: base.repository,
    branch: base.branch,
    commits: <String>[for (int i = 0; i < commitCount; i += 1) 'c$i'],
  );
}

List<String> _describeEveryRequest(String? runLabel, Random random) {
  return <String>[
    describePushRequest(runLabel: runLabel, commitCount: random.nextInt(9)),
    describeActionRequest(runLabel: runLabel),
    describeSkillChangeRequest(runLabel: runLabel),
    describeToolUseRequest(runLabel: runLabel, tool: randomText(random)),
  ];
}

void main() {
  test('test_describe_asking_agent_property_every_request_shares_the_'
      'subject', () {
    final Random random = seededRandom(616101);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String? runLabel = _randomOptionalRunLabel(random);

      for (final String request in _describeEveryRequest(runLabel, random)) {
        expect(request, startsWith('${_subjectFor(runLabel)} '));
        expect(request, endsWith('.'));
      }
    }
  });

  test('test_describe_asking_agent_property_runless_reads_an_agent', () {
    final Random random = seededRandom(616102);
    for (int i = 0; i < propertyIterations; i += 1) {
      for (final String request in _describeEveryRequest(null, random)) {
        expect(request, startsWith('$_runlessSubject '));
        expect(request, isNot(contains('null')));
      }
    }
  });

  test('test_describe_asking_agent_property_run_label_kept_verbatim', () {
    final Random random = seededRandom(616103);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String runLabel = _randomRunLabel(random);

      for (final String request in _describeEveryRequest(runLabel, random)) {
        expect(request.substring(0, 'The agent in '.length), 'The agent in ');
        expect(request, contains(runLabel));
      }
    }
  });

  test('test_describe_push_request_property_names_who_asks', () {
    final Random random = seededRandom(616104);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String? runLabel = _randomOptionalRunLabel(random);
      final int commitCount = random.nextInt(_largestCommitCount);

      final String request = describePushRequest(
        runLabel: runLabel,
        commitCount: commitCount,
      );

      expect(
        request,
        '${_subjectFor(runLabel)} wants to push '
        '${_describeCommits(commitCount)}.',
      );
    }
  });

  test('test_describe_push_request_property_refuses_negative_counts', () {
    final Random random = seededRandom(616105);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int negativeCount = -1 - random.nextInt(_largestCommitCount);

      expect(
        () => describePushRequest(
          runLabel: _randomOptionalRunLabel(random),
          commitCount: negativeCount,
        ),
        throwsArgumentError,
      );
    }
  });

  test('test_describe_action_request_property_one_plain_sentence', () {
    final Random random = seededRandom(616106);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String? runLabel = _randomOptionalRunLabel(random);

      expect(
        describeActionRequest(runLabel: runLabel),
        '${_subjectFor(runLabel)} asks before it does this.',
      );
    }
  });

  test('test_describe_action_request_property_differs_only_by_run', () {
    final Random random = seededRandom(616107);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String runLabel = _randomRunLabel(random);

      final String withRun = describeActionRequest(runLabel: runLabel);
      final String withoutRun = describeActionRequest(runLabel: null);

      expect(
        withRun.replaceFirst(_subjectFor(runLabel), ''),
        withoutRun.replaceFirst(_runlessSubject, ''),
      );
    }
  });

  test('test_describe_skill_change_request_property_one_plain_sentence', () {
    final Random random = seededRandom(616108);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String? runLabel = _randomOptionalRunLabel(random);

      expect(
        describeSkillChangeRequest(runLabel: runLabel),
        '${_subjectFor(runLabel)} wants to change these instructions.',
      );
    }
  });

  test('test_describe_skill_change_request_property_differs_only_by_run', () {
    final Random random = seededRandom(616109);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String runLabel = _randomRunLabel(random);

      final String withRun = describeSkillChangeRequest(runLabel: runLabel);
      final String withoutRun = describeSkillChangeRequest(runLabel: null);

      expect(
        withRun.replaceFirst(_subjectFor(runLabel), ''),
        withoutRun.replaceFirst(_runlessSubject, ''),
      );
    }
  });

  test('test_describe_tool_use_request_property_bash_reads_as_a_'
      'command', () {
    final Random random = seededRandom(616110);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String? runLabel = _randomOptionalRunLabel(random);

      final String request = describeToolUseRequest(
        runLabel: runLabel,
        tool: commandToolName,
      );

      expect(request, '${_subjectFor(runLabel)} wants to run a command.');
      expect(request, isNot(contains(commandToolName)));
    }
  });

  test('test_describe_tool_use_request_property_other_tools_named', () {
    final Random random = seededRandom(616111);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String? runLabel = _randomOptionalRunLabel(random);
      final String tool = 'Tool${randomText(random)}';

      expect(
        describeToolUseRequest(runLabel: runLabel, tool: tool),
        '${_subjectFor(runLabel)} wants to use $tool.',
      );
    }
  });

  test('test_describe_push_title_property_names_count_and_branch', () {
    final Random random = seededRandom(616112);
    for (int i = 0; i < propertyIterations; i += 1) {
      final PushCommitsAction action = randomPushAction(random);

      expect(
        describePushTitle(action),
        'Push ${_describeCommits(action.commits.length)} to ${action.branch}',
      );
    }
  });

  test('test_describe_push_title_property_matches_the_approval_title', () {
    final Random random = seededRandom(616113);
    for (int i = 0; i < propertyIterations; i += 1) {
      final PushCommitsAction action = randomPushAction(random);

      expect(
        describeApprovalTitle(action, const <Workflow>[]),
        describePushTitle(action),
      );
    }
  });

  test('test_describe_push_title_property_one_commit_is_singular', () {
    final Random random = seededRandom(616114);
    for (int i = 0; i < propertyIterations; i += 1) {
      final PushCommitsAction action = _pushWithCommitCount(random, 1);

      final String title = describePushTitle(action);

      expect(title, startsWith('Push 1 commit to '));
      expect(title, isNot(startsWith('Push 1 commits')));
    }
  });

  test('test_describe_commit_count_property_title_and_request_agree', () {
    final Random random = seededRandom(616115);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int commitCount = random.nextInt(_largestCommitCount);
      final PushCommitsAction action = _pushWithCommitCount(
        random,
        commitCount,
      );

      final String commits = _describeCommits(commitCount);

      expect(describePushTitle(action), contains('Push $commits to '));
      expect(
        describePushRequest(runLabel: null, commitCount: commitCount),
        endsWith('push $commits.'),
      );
    }
  });

  test('test_describe_commit_count_property_large_counts_are_grouped', () {
    final Random random = seededRandom(616116);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int commitCount = 1000 + random.nextInt(_largestCommitCount);
      final String request = describePushRequest(
        runLabel: null,
        commitCount: commitCount,
      );

      final String digits = commitCount.toString();
      final String grouped =
          '${digits.substring(0, digits.length - 3)},'
          '${digits.substring(digits.length - 3)}';
      expect(request, contains('push $grouped commits.'));
    }
  });

  test('test_describe_commit_count_property_zero_is_plural', () {
    final Random random = seededRandom(616117);
    for (int i = 0; i < propertyIterations; i += 1) {
      final PushCommitsAction action = _pushWithCommitCount(random, 0);

      expect(describePushTitle(action), startsWith('Push 0 commits to '));
    }
  });
}
