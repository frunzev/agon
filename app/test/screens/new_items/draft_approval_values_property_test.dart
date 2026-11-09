import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/new_items/draft_approval.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

const List<String> _approvalTitles = <String>[
  approvalFailedTitle,
  approvalUnfinishedTitle,
];

void main() {
  test('test_approval_problem_new_property_keeps_title_and_explanation', () {
    final Random random = seededRandom(54501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = pickOne(random, _approvalTitles);
      final String explanation = randomHostileText(random);

      final ApprovalProblem problem = ApprovalProblem(
        title: title,
        explanation: explanation,
      );

      expect(problem.title, same(title));
      expect(problem.explanation, same(explanation));
    }
  });

  test('test_approval_problem_new_property_const_values_are_canonical', () {
    const ApprovalProblem first = ApprovalProblem(
      title: approvalUnfinishedTitle,
      explanation: 'x',
    );
    const ApprovalProblem second = ApprovalProblem(
      title: approvalUnfinishedTitle,
      explanation: 'x',
    );

    expect(identical(first, second), isTrue);
  });

  test('test_approval_problem_new_property_titles_never_contradict', () {
    expect(_approvalTitles.toSet(), hasLength(_approvalTitles.length));
    expect(approvalUnfinishedTitle, isNot(contains('not created')));
    expect(approvalFailedTitle, contains('not created'));
    for (final String title in _approvalTitles) {
      expect(title.trim(), title);
      expect(title, isNotEmpty);
    }
  });
}
