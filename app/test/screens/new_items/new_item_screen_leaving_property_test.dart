import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/new_items/item_drafting_view.dart';
import 'package:agent_orchestration/screens/new_items/item_request_view.dart';
import 'package:agent_orchestration/screens/new_items/item_review_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/workflows/workflow_drafting_screen.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';
import 'new_item_screen_flow.dart';

typedef _RefusableScene = ({
  RefusableItemDraftRepository refusable,
  RecordedNewItemPage page,
});

Future<_RefusableScene> _openRefusableDraft(
  WidgetTester tester,
  Random random,
) async {
  final RefusableItemDraftRepository refusable = RefusableItemDraftRepository(
    ScriptedItemDraftRepository(),
  );
  final RecordedNewItemPage page = await openDraftingPage(
    tester,
    random: random,
    dependencies: buildRefusableDependencies(refusable),
  );
  return (refusable: refusable, page: page);
}

void _expectBackWhereDraftingStarted(WidgetTester tester, bool isChange) {
  expect(find.byType(ItemDraftingView), findsNothing);
  expect(
    find.byType(ItemReviewView),
    isChange ? findsOneWidget : findsNothing,
  );
  expect(
    find.byType(ItemRequestView),
    isChange ? findsNothing : findsOneWidget,
  );
}

void main() {
  testWidgets('test_leave_drafting_property_return_never_stops_anything', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10801);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final bool isChange = random.nextBool();
      if (isChange) {
        await reachChangeDrafting(
          tester,
          random: random,
          page: page,
          drafts: drafts,
        );
      }
      await failDraft(tester, drafts: drafts, problem: StateError('x'));

      await tapPageText(
        tester,
        isChange ? backToDraftLabel : backToWordsLabel,
      );

      expect(drafts.stoppedRequests, isEmpty);
      _expectBackWhereDraftingStarted(tester, isChange);
    }
  });

  testWidgets('test_leave_drafting_property_a_fresh_draft_starts_clean', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10802);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final String message = 'Refused round $i';
      await failDraft(
        tester,
        drafts: drafts,
        problem: PeopleFacingRefusal(message),
      );
      await tapPageText(tester, backToWordsLabel);

      await draftWish(tester, page: page, wish: 'Again $i');

      expect(drafts.requests, hasLength(2));
      expect(drafts.latestRequest.wish, 'Again $i');
      expect(find.text(message), findsNothing);
      expect(find.text(draftFailedTitle), findsNothing);
      expect(find.text(stopDraftingLabel), findsOneWidget);
    }
  });

  testWidgets('test_leave_drafting_property_stop_lands_where_return_does', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10803);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final bool isChange = random.nextBool();
      if (isChange) {
        await reachChangeDrafting(
          tester,
          random: random,
          page: page,
          drafts: drafts,
        );
      }

      await tapPageText(tester, stopDraftingLabel);

      _expectBackWhereDraftingStarted(tester, isChange);
      expect(page.navigation.routes, hasLength(2));
    }
  });

  testWidgets('test_leave_page_while_drafting_property_stops_then_leaves', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10804);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final AppRoute below = page.navigation.routes.first;

      await tapPageText(tester, page.texts.sectionLabel);

      expect(drafts.stoppedRequests, <ItemDraftRequest>[drafts.latestRequest]);
      expect(page.navigation.routes, <AppRoute>[below]);
    }
  });

  testWidgets('test_leave_page_while_drafting_property_failed_draft_leaves', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10805);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final AppRoute below = page.navigation.routes.first;
      await failDraft(tester, drafts: drafts, problem: StateError('x'));

      await tapPageText(tester, page.texts.sectionLabel);

      expect(drafts.stoppedRequests, isEmpty);
      expect(page.navigation.routes, <AppRoute>[below]);
    }
  });

  testWidgets('test_leave_page_while_drafting_property_refused_stop_stays', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10806);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RefusableScene scene = await _openRefusableDraft(tester, random);
      final String message = 'Cannot stop $i ${randomWordPhrase(random)}';
      final List<AppRoute> routesBefore = scene.page.navigation.routes;
      scene.refusable.stopRefusal = PeopleFacingRefusal(message);

      await tapPageText(tester, scene.page.texts.sectionLabel);

      expect(scene.page.navigation.routes, routesBefore);
      expect(find.text(stopFailedTitle), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.text(stopDraftingLabel), findsOneWidget);
    }
  });

  testWidgets('test_stop_drafting_property_refused_stop_can_be_retried', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10807);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RefusableScene scene = await _openRefusableDraft(tester, random);
      final String message = 'Cannot stop $i';
      scene.refusable.stopRefusal = PeopleFacingRefusal(message);
      await tapPageText(tester, stopDraftingLabel);
      expect(find.text(message), findsOneWidget);
      expect(find.byType(ItemDraftingView), findsOneWidget);

      scene.refusable.stopRefusal = null;
      await tapPageText(tester, stopDraftingLabel);

      expect(scene.refusable.drafts.stoppedRequests, hasLength(1));
      expect(find.text(message), findsNothing);
      expect(find.byType(ItemRequestView), findsOneWidget);
    }
  });

  testWidgets('test_stop_drafting_property_stops_exactly_the_running_draft', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10808);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      for (int round = 0; round < 1 + random.nextInt(3); round += 1) {
        await tapPageText(tester, stopDraftingLabel);
        await draftWish(tester, page: page, wish: 'Wish $round');
      }

      await tapPageText(tester, stopDraftingLabel);

      expect(drafts.stoppedRequests, drafts.requests);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_stop_drafting_property_stop_problem_ends_with_draft', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10809);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RefusableScene scene = await _openRefusableDraft(tester, random);
      final String message = 'Cannot stop $i';
      scene.refusable.stopRefusal = PeopleFacingRefusal(message);
      await tapPageText(tester, stopDraftingLabel);

      await failDraft(
        tester,
        drafts: scene.refusable.drafts,
        problem: StateError('x'),
      );
      await tapPageText(tester, backToWordsLabel);
      await draftWish(tester, page: scene.page, wish: 'Again $i');

      expect(find.text(message), findsNothing);
      expect(find.text(stopFailedTitle), findsNothing);
    }
  });
}
