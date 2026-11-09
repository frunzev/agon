import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';

import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'random_drafts.dart';

final class _CallbackRecords {
  final List<DraftedItem> changes = <DraftedItem>[];
  final List<DraftedItem> approvals = <DraftedItem>[];
  final TapCounter cancels = TapCounter();

  Future<void> approve(DraftedItem item) async {
    approvals.add(item);
  }
}

final class _ApprovalRecords<V> {
  final List<V> approvedValues = <V>[];
  StateError? refusal;

  Future<void> approve(V values) async {
    approvedValues.add(values);
    final StateError? plannedRefusal = refusal;
    if (plannedRefusal != null) {
      throw plannedRefusal;
    }
  }
}

DraftedItem _randomItem(Random random, int round) {
  return randomDraftedItem(random, pickOne(random, DraftKind.values), round);
}

void main() {
  test('test_draft_form_callbacks_constructor_property_keeps_every_'
      'callback', () async {
    final Random random = seededRandom(1021101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _CallbackRecords records = _CallbackRecords();
      final DraftedItem item = _randomItem(random, i);

      final DraftFormCallbacks callbacks = DraftFormCallbacks(
        onChanged: records.changes.add,
        onApproved: records.approve,
        onCancelled: records.cancels.countTap,
      );
      callbacks.onChanged(item);
      await callbacks.onApproved(item);
      callbacks.onCancelled();

      expect(records.changes.single, same(item));
      expect(records.approvals.single, same(item));
      expect(records.cancels.count, 1);
    }
  });

  test('test_draft_form_callbacks_constructor_property_callbacks_stay_'
      'apart', () async {
    final Random random = seededRandom(1021102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _CallbackRecords records = _CallbackRecords();
      final DraftFormCallbacks callbacks = DraftFormCallbacks(
        onChanged: records.changes.add,
        onApproved: records.approve,
        onCancelled: records.cancels.countTap,
      );
      final int changeCount = random.nextInt(5);

      for (int change = 0; change < changeCount; change += 1) {
        callbacks.onChanged(_randomItem(random, change));
      }

      expect(records.changes, hasLength(changeCount));
      expect(records.approvals, isEmpty);
      expect(records.cancels.count, 0);
    }
  });

  test('test_draft_form_callbacks_constructor_property_const_with_the_'
      'same_callbacks_is_canonical', () {
    const DraftFormCallbacks first = DraftFormCallbacks(
      onChanged: _ignoreChange,
      onApproved: _approveNothing,
      onCancelled: _cancelNothing,
    );
    const DraftFormCallbacks second = DraftFormCallbacks(
      onChanged: _ignoreChange,
      onApproved: _approveNothing,
      onCancelled: _cancelNothing,
    );

    expect(identical(first, second), isTrue);
  });

  test('test_build_review_actions_property_two_actions_cancel_then_'
      'approve', () {
    final _ApprovalRecords<int> records = _ApprovalRecords<int>();

    final List<FormAction<int>> actions = buildReviewActions<int>(
      onCancelled: TapCounter().countTap,
      onApproved: records.approve,
    );

    expect(actions, hasLength(2));
    expect(actions.first, isA<LeaveFormAction<int>>());
    expect(actions.last, isA<SubmitFormAction<int>>());
    expect(actions.first.icon, isNull);
    expect(actions.last.icon, AppIconKind.check);
    expect(actions.first.label, cancelReviewLabel);
    expect(actions.last.label, approveLabel);
    expect(cancelReviewLabel, isNot(approveLabel));
  });

  test('test_build_review_actions_property_cancel_never_approves', () {
    final Random random = seededRandom(1021104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TapCounter cancels = TapCounter();
      final _ApprovalRecords<String> records = _ApprovalRecords<String>();
      final List<FormAction<String>> actions = buildReviewActions<String>(
        onCancelled: cancels.countTap,
        onApproved: records.approve,
      );
      final int tapCount = random.nextInt(5);

      final LeaveFormAction<String> cancel =
          actions.first as LeaveFormAction<String>;
      for (int tap = 0; tap < tapCount; tap += 1) {
        cancel.onPressed();
      }

      expect(cancels.count, tapCount);
      expect(records.approvedValues, isEmpty);
    }
  });

  test('test_build_review_actions_property_approval_refusals_reach_the_'
      'form', () async {
    final Random random = seededRandom(1021105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ApprovalRecords<String> records = _ApprovalRecords<String>();
      final String values = randomText(random);
      final bool refuses = random.nextBool();
      records.refusal = refuses ? StateError(values) : null;
      final List<FormAction<String>> actions = buildReviewActions<String>(
        onCancelled: TapCounter().countTap,
        onApproved: records.approve,
      );

      final SubmitFormAction<String> approve =
          actions.last as SubmitFormAction<String>;
      final Future<void> submitted = approve.onSubmitted(values);

      if (refuses) {
        await expectLater(submitted, throwsStateError);
      } else {
        await submitted;
      }
      expect(records.approvedValues, <String>[values]);
    }
  });
}

void _ignoreChange(DraftedItem item) {}

Future<void> _approveNothing(DraftedItem item) async {}

void _cancelNothing() {}
