import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';
import 'package:agent_orchestration/screens/new_items/item_review_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';
import 'new_item_screen_flow.dart';
import 'random_drafts.dart';

typedef _ReviewScene = ({
  ScriptedItemDraftRepository drafts,
  RecordedNewItemPage page,
  ItemDraft draft,
});

Future<_ReviewScene> _openReview(WidgetTester tester, Random random) async {
  final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
  final RecordedNewItemPage page = await openDraftingPage(
    tester,
    random: random,
    dependencies: buildNewItemDependencies(drafts),
  );
  final ItemDraft draft = randomItemDraft(random, page.kind, 0);
  await reportDraftProgress(
    tester,
    drafts: drafts,
    progress: DraftFinished(draft),
  );
  return (drafts: drafts, page: page, draft: draft);
}

Future<void> _approveShown(WidgetTester tester, _ReviewScene scene) async {
  await scene.page.review.latestCallbacks.onApproved(scene.draft.item);
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_build_review_property_form_shows_the_latest_draft', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10901);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      expect(
        identical(scene.page.review.builtItems.last, scene.draft.item),
        isTrue,
      );

      await sendChangeNote(tester, 'Change $i');
      final ItemDraft second = randomItemDraft(random, scene.page.kind, i);
      await reportDraftProgress(
        tester,
        drafts: scene.drafts,
        progress: DraftFinished(second),
      );

      expect(
        identical(scene.page.review.builtItems.last, second.item),
        isTrue,
      );
      expect(find.text(reviewSummary), findsOneWidget);
      expect(find.text(describeReviewedItem(second.item)), findsOneWidget);
    }
  });

  testWidgets('test_build_review_property_cancel_closes_only_the_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10902);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      final AppRoute below = scene.page.navigation.routes.first;

      if (random.nextBool()) {
        await tapPageText(tester, scene.page.texts.sectionLabel);
      } else {
        scene.page.review.latestCallbacks.onCancelled();
        await pumpFrames(tester);
      }

      expect(scene.page.navigation.routes, <AppRoute>[below]);
      expect(scene.page.review.approvedItems, isEmpty);
      expect(scene.drafts.requests, hasLength(1));
    }
  });

  testWidgets('test_build_review_property_problems_belong_to_their_draft', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10903);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      for (final String problem in scene.draft.problems) {
        expect(find.text(problem), findsOneWidget);
      }

      await sendChangeNote(tester, 'Change $i');
      final ItemDraft second = randomItemDraft(random, scene.page.kind, i);
      await reportDraftProgress(
        tester,
        drafts: scene.drafts,
        progress: DraftFinished(second),
      );

      final ItemReviewView view = tester.widget(find.byType(ItemReviewView));
      expect(view.problems, second.problems);
      expect(
        find.text(draftProblemsTitle),
        second.problems.isEmpty ? findsNothing : findsOneWidget,
      );
    }
  });

  testWidgets('test_keep_hand_edit_property_next_change_starts_from_edit', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10904);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      final DraftedItem edited = randomDraftedItem(random, scene.page.kind, i);

      scene.page.review.latestCallbacks.onChanged(edited);
      await sendChangeNote(tester, 'Change $i');

      expect(
        identical(scene.drafts.latestRequest.change!.draft, edited),
        isTrue,
      );
    }
  });

  testWidgets('test_keep_hand_edit_property_problems_survive_hand_edits', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10905);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      final DraftedItem edited = randomDraftedItem(random, scene.page.kind, i);
      scene.page.review.latestCallbacks.onChanged(edited);
      scene.page.review.approvalProblem = PeopleFacingRefusal('No $i');

      await _approveShown(tester, scene);

      final ItemReviewView view = tester.widget(find.byType(ItemReviewView));
      expect(view.problems, scene.draft.problems);
      expect(identical(scene.page.review.builtItems.last, edited), isTrue);
    }
  });

  testWidgets('test_keep_hand_edit_property_back_to_draft_shows_the_edit', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10906);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      final DraftedItem edited = randomDraftedItem(random, scene.page.kind, i);
      scene.page.review.latestCallbacks.onChanged(edited);
      await sendChangeNote(tester, 'Change $i');

      await failDraft(tester, drafts: scene.drafts, problem: StateError('x'));
      await tapPageText(tester, backToDraftLabel);

      expect(identical(scene.page.review.builtItems.last, edited), isTrue);
      expect(find.text(describeReviewedItem(edited)), findsOneWidget);
    }
  });

  testWidgets('test_ask_for_changes_property_sends_note_wish_and_draft', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10907);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      final ItemDraftRequest first = scene.drafts.latestRequest;
      final String note = 'Change ${randomHostileText(random)}';

      await sendChangeNote(tester, note);

      final ItemDraftRequest changed = scene.drafts.latestRequest;
      expect(changed.kind, first.kind);
      expect(changed.wish, first.wish);
      expect(changed.startedFrom, first.startedFrom);
      expect(changed.change!.note, trimUnicodeWhiteSpace(note));
      expect(identical(changed.change!.draft, scene.draft.item), isTrue);
    }
  });

  testWidgets('test_ask_for_changes_property_rounds_chain_latest_drafts', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10908);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      DraftedItem shown = scene.draft.item;

      for (int round = 0; round < 1 + random.nextInt(3); round += 1) {
        await sendChangeNote(tester, 'Round $round');
        expect(
          identical(scene.drafts.latestRequest.change!.draft, shown),
          isTrue,
        );
        final ItemDraft next = randomItemDraft(random, scene.page.kind, round);
        shown = next.item;
        await reportDraftProgress(
          tester,
          drafts: scene.drafts,
          progress: DraftFinished(next),
        );
      }

      expect(identical(scene.page.review.builtItems.last, shown), isTrue);
    }
  });

  testWidgets('test_ask_for_changes_property_clears_approval_problems', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10909);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      scene.page.review.approvalProblem = PeopleFacingRefusal('No $i');
      await _approveShown(tester, scene);
      expect(find.text(approvalFailedTitle), findsOneWidget);

      await sendChangeNote(tester, 'Change $i');
      await failDraft(tester, drafts: scene.drafts, problem: StateError('x'));
      await tapPageText(tester, backToDraftLabel);

      expect(find.text(approvalFailedTitle), findsNothing);
      expect(find.text('No $i'), findsNothing);
    }
  });
}
