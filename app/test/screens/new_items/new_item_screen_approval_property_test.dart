import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';
import 'new_item_screen_flow.dart';

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
  testWidgets('test_approve_property_refusals_are_shown_and_kept_on_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10910);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      final String message = 'Refused ${randomHostileText(random)}';
      final List<AppRoute> routesBefore = scene.page.navigation.routes;
      scene.page.review.approvalProblem = PeopleFacingRefusal(message);

      await _approveShown(tester, scene);

      expect(scene.page.review.approvedItems, <DraftedItem>[scene.draft.item]);
      expect(find.text(approvalFailedTitle), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(scene.page.navigation.routes, routesBefore);
    }
  });

  testWidgets('test_approve_property_success_shows_no_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10911);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      if (random.nextBool()) {
        scene.page.review.approvalProblem = PeopleFacingRefusal('No $i');
        await _approveShown(tester, scene);
        scene.page.review.approvalProblem = null;
      }

      await _approveShown(tester, scene);

      expect(scene.page.review.approvedItems.last, same(scene.draft.item));
      expect(find.text(approvalFailedTitle), findsNothing);
      expect(find.text('No $i'), findsNothing);
    }
  });

  testWidgets('test_approve_property_unexplained_failures_are_rethrown', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10912);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      scene.page.review.approvalProblem = pickOne<Error>(random, <Error>[
        StateError('broken $i'),
        ArgumentError('bad $i'),
        PeopleFacingRefusal(' '),
      ]);

      await expectLater(
        scene.page.review.latestCallbacks.onApproved(scene.draft.item),
        throwsA(same(scene.page.review.approvalProblem)),
      );
      await pumpFrames(tester);

      expect(find.text(approvalFailedTitle), findsNothing);
    }
  });
}
