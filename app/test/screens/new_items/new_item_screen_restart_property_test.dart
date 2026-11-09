import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/new_items/item_review_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';
import 'new_item_screen_flow.dart';

void main() {
  testWidgets('test_start_drafting_property_each_start_waits_for_drafter', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11206);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final Device device = pickOne(
        random,
        page.dependencies.deviceRepository.listDevices(),
      );
      await reportDraftProgress(
        tester,
        drafts: drafts,
        progress: DraftRunning(
          drafterKind: AgentKind.codex,
          drafterDeviceId: device.id,
        ),
      );
      expect(find.text(startingDraftText), findsNothing);

      if (random.nextBool()) {
        await tapPageText(tester, stopDraftingLabel);
        await draftWish(tester, page: page, wish: 'Again $i');
      } else {
        await reachChangeDrafting(
          tester,
          random: random,
          page: page,
          drafts: drafts,
        );
      }

      expect(find.text(startingDraftText), findsOneWidget);
      expect(find.text('Codex is drafting on ${device.name}'), findsNothing);
    }
  });

  testWidgets('test_start_drafting_property_new_drafts_drop_old_problems', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11207);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openRecordedNewItemPage(
        tester,
        kind: pickOne(random, DraftKind.values),
        startedFrom: null,
        dependencies: buildNewItemDependencies(drafts),
        size: randomScreenSize(random),
      );
      await draftWish(tester, page: page, wish: ' ');
      final String message = 'Refused $i';
      if (random.nextBool()) {
        await draftWish(tester, page: page, wish: 'First $i');
        await failDraft(
          tester,
          drafts: drafts,
          problem: PeopleFacingRefusal(message),
        );
        await tapPageText(tester, backToWordsLabel);
      }

      await draftWish(tester, page: page, wish: 'Wish $i');

      expect(find.text(emptyWishProblem), findsNothing);
      expect(find.text(message), findsNothing);
      expect(find.text(stopDraftingLabel), findsOneWidget);
    }
  });

  testWidgets('test_start_drafting_property_only_the_latest_draft_is_heard', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11208);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      await tapPageText(tester, stopDraftingLabel);
      await draftWish(tester, page: page, wish: 'Second $i');
      final ItemDraft draft = randomItemDraft(random, page.kind, i);

      await reportDraftProgress(
        tester,
        drafts: drafts,
        progress: DraftFinished(draft),
      );

      expect(drafts.requests, hasLength(2));
      expect(page.review.builtItems, <DraftedItem>[draft.item]);
      expect(find.byType(ItemReviewView), findsOneWidget);
    }
  });

  testWidgets('test_start_drafting_property_repeated_quick_taps_draft_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11209);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openRecordedNewItemPage(
        tester,
        kind: pickOne(random, DraftKind.values),
        startedFrom: null,
        dependencies: buildNewItemDependencies(drafts),
        size: randomScreenSize(random),
      );
      await tester.enterText(find.byType(TextField).first, 'Wish $i');
      final Finder draftButton = find.text(page.texts.draftLabel);
      await tester.ensureVisible(draftButton);
      await tester.pump();

      for (int tap = 0; tap < 2 + random.nextInt(2); tap += 1) {
        await tester.tap(draftButton);
      }
      await pumpFrames(tester);

      expect(drafts.requests, hasLength(1), reason: 'round $i');
      await reportDraftProgress(
        tester,
        drafts: drafts,
        progress: DraftFinished(randomItemDraft(random, page.kind, i)),
      );
      expect(find.byType(ItemReviewView), findsOneWidget);
    }
  });
}
