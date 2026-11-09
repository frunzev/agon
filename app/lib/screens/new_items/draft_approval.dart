import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';

final class ApprovalProblem {
  const ApprovalProblem({required this.title, required this.explanation});

  final String title;
  final String explanation;
}

final class DraftApproval {
  UnfinishedApproval? _unfinished;

  Future<ApprovalProblem?> approve({
    required DraftReview review,
    required DraftedItem item,
  }) async {
    final UnfinishedApproval? unfinished = _unfinished;
    try {
      if (unfinished == null) {
        await review.approve(item);
      } else {
        await unfinished.finishApproval();
      }
    } on Object catch (problem) {
      if (problem is UnfinishedApproval) {
        _unfinished = problem;
        return ApprovalProblem(
          title: approvalUnfinishedTitle,
          explanation: problem.message,
        );
      }
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      return ApprovalProblem(
        title: approvalFailedTitle,
        explanation: explanation,
      );
    }

    return null;
  }
}
