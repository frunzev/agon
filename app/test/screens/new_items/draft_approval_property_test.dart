import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/new_items/draft_approval.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import 'random_drafts.dart';

final class _PlannedReview implements DraftReview {
  final List<DraftedItem> approvedItems = <DraftedItem>[];
  final List<Object?> plannedProblems = <Object?>[];

  @override
  Widget buildForm(DraftedItem item, DraftFormCallbacks callbacks) {
    return const SizedBox();
  }

  @override
  Future<void> approve(DraftedItem item) async {
    approvedItems.add(item);
    final Object? problem = plannedProblems.isEmpty
        ? null
        : plannedProblems.removeAt(0);
    if (problem != null) {
      await Future<void>.error(problem);
    }
  }
}

final class _Finisher {
  int finishCount = 0;
  final List<Object?> plannedProblems = <Object?>[];

  Future<void> finish() async {
    finishCount += 1;
    final Object? problem = plannedProblems.isEmpty
        ? null
        : plannedProblems.removeAt(0);
    if (problem != null) {
      await Future<void>.error(problem);
    }
  }
}

DraftedItem _randomItem(Random random, int round) {
  return randomDraftedItem(random, pickOne(random, DraftKind.values), round);
}

void main() {
  test('test_unfinished_approval_new_property_keeps_message_and_finish', () {
    final Random random = seededRandom(53501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = 'Not started ${randomHostileText(random)} $i';
      final _Finisher finisher = _Finisher();

      final UnfinishedApproval unfinished = UnfinishedApproval(
        message,
        finishApproval: finisher.finish,
      );

      expect(unfinished.message, message);
      expect(unfinished.finishApproval, finisher.finish);
      expect(finisher.finishCount, 0);
    }
  });

  test('test_unfinished_approval_new_property_is_explained_to_people', () {
    final Random random = seededRandom(53502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = 'Not started $i ${randomWordPhrase(random)}';

      final UnfinishedApproval unfinished = UnfinishedApproval(
        message,
        finishApproval: _Finisher().finish,
      );

      expect(unfinished, isA<PeopleFacingRefusal>());
      expect(describeProblemForPeople(unfinished), message);
    }
  });

  test(
    'test_unfinished_approval_new_property_finish_runs_what_was_given',
    () async {
      final Random random = seededRandom(53503);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _Finisher finisher = _Finisher();
        final UnfinishedApproval unfinished = UnfinishedApproval(
          'Not started $i',
          finishApproval: finisher.finish,
        );
        final int finishCount = 1 + random.nextInt(4);

        for (int finish = 0; finish < finishCount; finish += 1) {
          await unfinished.finishApproval();
        }

        expect(finisher.finishCount, finishCount);
      }
    },
  );

  test(
    'test_draft_approval_approve_property_success_shows_no_problem',
    () async {
      final Random random = seededRandom(53504);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _PlannedReview review = _PlannedReview();
        final DraftedItem item = _randomItem(random, i);

        final ApprovalProblem? problem = await DraftApproval().approve(
          review: review,
          item: item,
        );

        expect(problem, isNull);
        expect(review.approvedItems, <DraftedItem>[item]);
      }
    },
  );

  test(
    'test_draft_approval_approve_property_refusal_is_not_created',
    () async {
      final Random random = seededRandom(53505);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _PlannedReview review = _PlannedReview();
        final ExplainedRefusal refusal = randomExplainedRefusal(random);
        review.plannedProblems.add(refusal.problem);
        final DraftApproval approval = DraftApproval();
        final DraftedItem item = _randomItem(random, i);

        final ApprovalProblem? problem = await approval.approve(
          review: review,
          item: item,
        );
        final ApprovalProblem? retried = await approval.approve(
          review: review,
          item: item,
        );

        expect(problem?.title, approvalFailedTitle);
        expect(problem?.explanation, refusal.explanation);
        expect(retried, isNull);
        expect(review.approvedItems, <DraftedItem>[item, item]);
      }
    },
  );

  test(
    'test_draft_approval_approve_property_unfinished_is_only_finished',
    () async {
      final Random random = seededRandom(53506);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _PlannedReview review = _PlannedReview();
        final _Finisher finisher = _Finisher();
        final String message = 'Created, not started $i';
        review.plannedProblems.add(
          UnfinishedApproval(message, finishApproval: finisher.finish),
        );
        final int failedFinishCount = random.nextInt(3);
        for (int failed = 0; failed < failedFinishCount; failed += 1) {
          finisher.plannedProblems.add(
            UnfinishedApproval(message, finishApproval: finisher.finish),
          );
        }
        final DraftApproval approval = DraftApproval();
        final DraftedItem item = _randomItem(random, i);

        final ApprovalProblem? first = await approval.approve(
          review: review,
          item: item,
        );
        for (int failed = 0; failed < failedFinishCount; failed += 1) {
          final ApprovalProblem? again = await approval.approve(
            review: review,
            item: item,
          );
          expect(again?.title, approvalUnfinishedTitle);
        }
        final ApprovalProblem? finished = await approval.approve(
          review: review,
          item: item,
        );

        expect(first?.title, approvalUnfinishedTitle);
        expect(first?.explanation, message);
        expect(finished, isNull);
        expect(review.approvedItems, <DraftedItem>[item]);
        expect(finisher.finishCount, failedFinishCount + 1);
      }
    },
  );

  test(
    'test_draft_approval_approve_property_unexplained_is_rethrown',
    () async {
      final Random random = seededRandom(53507);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _PlannedReview review = _PlannedReview();
        final FormatException problem = randomUnexplainedProblem(random);
        review.plannedProblems.add(problem);

        final Future<ApprovalProblem?> approving = DraftApproval().approve(
          review: review,
          item: _randomItem(random, i),
        );

        await expectLater(approving, throwsA(same(problem)));
      }
    },
  );
}
