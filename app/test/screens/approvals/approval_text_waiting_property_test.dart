import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';

import '../../support/random_inputs.dart';

const int _largestCount = 30000;

int _randomPositiveCount(Random random) {
  return 1 + random.nextInt(_largestCount);
}

void main() {
  test('test_describe_waiting_approvals_property_counts_like_the_app', () {
    final Random random = seededRandom(616301);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = 2 + random.nextInt(_largestCount);

      final String waiting = describeWaitingApprovals(count);

      final String countSentence = describeCount(
        count,
        singular: 'waiting.',
        plural: 'waiting.',
      );
      expect(waiting, '$countSentence Each one needs your approval.');
    }
  });

  test('test_describe_waiting_work_property_questions_only', () {
    final Random random = seededRandom(616302);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int questionCount = _randomPositiveCount(random);

      final String waiting = describeWaitingWork(
        approvalCount: 0,
        questionCount: questionCount,
      );

      final String questions = describeCount(
        questionCount,
        singular: 'question',
        plural: 'questions',
      );
      expect(waiting, '$questions waiting for your answer');
    }
  });

  test('test_describe_waiting_work_property_names_both_counts', () {
    final Random random = seededRandom(616303);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int questionCount = _randomPositiveCount(random);
      final int approvalCount = _randomPositiveCount(random);

      final String waiting = describeWaitingWork(
        approvalCount: approvalCount,
        questionCount: questionCount,
      );

      final String questions = describeCount(
        questionCount,
        singular: 'question',
        plural: 'questions',
      );
      final String approvals = describeCount(
        approvalCount,
        singular: 'approval',
        plural: 'approvals',
      );
      expect(waiting, '$questions and $approvals waiting');
    }
  });

  test('test_describe_waiting_work_property_approvals_only_match_the_'
      'approvals_summary', () {
    final Random random = seededRandom(616304);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int approvalCount = _randomPositiveCount(random);

      expect(
        describeWaitingWork(approvalCount: approvalCount, questionCount: 0),
        describeWaitingApprovals(approvalCount),
      );
    }
  });

  test('test_describe_waiting_work_property_refuses_negative_counts', () {
    final Random random = seededRandom(616305);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int negativeCount = -1 - random.nextInt(_largestCount);
      final bool isQuestionCountNegative = random.nextBool();

      expect(
        () => describeWaitingWork(
          approvalCount: isQuestionCountNegative
              ? _randomPositiveCount(random)
              : negativeCount,
          questionCount: isQuestionCountNegative
              ? negativeCount
              : _randomPositiveCount(random),
        ),
        throwsArgumentError,
      );
    }
  });

  test('test_describe_waiting_work_property_one_is_singular', () {
    final Random random = seededRandom(616306);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int otherCount = _randomPositiveCount(random);
      final bool isQuestionSingle = random.nextBool();

      final String waiting = describeWaitingWork(
        approvalCount: isQuestionSingle ? otherCount : 1,
        questionCount: isQuestionSingle ? 1 : otherCount,
      );

      expect(
        waiting,
        contains(isQuestionSingle ? '1 question' : '1 approval'),
      );
      expect(waiting, isNot(contains(RegExp(r'\b1 (questions|approvals)'))));
    }
  });

  test('test_describe_waiting_work_property_counts_read_back', () {
    final Random random = seededRandom(616307);
    final RegExp countsPattern = RegExp(
      r'^([\d,]+) questions? and ([\d,]+) approvals? waiting$',
    );
    for (int i = 0; i < propertyIterations; i += 1) {
      final int questionCount = _randomPositiveCount(random);
      final int approvalCount = _randomPositiveCount(random);

      final RegExpMatch? counts = countsPattern.firstMatch(
        describeWaitingWork(
          approvalCount: approvalCount,
          questionCount: questionCount,
        ),
      );

      expect(int.parse(counts!.group(1)!.replaceAll(',', '')), questionCount);
      expect(int.parse(counts.group(2)!.replaceAll(',', '')), approvalCount);
    }
  });

  test('test_describe_waiting_work_property_large_counts_are_grouped', () {
    final Random random = seededRandom(616308);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int questionCount = 1000 + random.nextInt(_largestCount);

      final String waiting = describeWaitingWork(
        approvalCount: 0,
        questionCount: questionCount,
      );

      expect(waiting, matches(RegExp(r'^\d{1,2},\d{3} questions waiting')));
    }
  });
}
