import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/new_items/item_drafting_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';
import 'new_item_screen_flow.dart';

void main() {
  testWidgets('test_close_stopped_page_property_closes_one_page_after_stop', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54301);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final List<AppRoute> routesBefore = page.navigation.routes;

      await tapPageText(tester, page.texts.sectionLabel);

      expect(
        page.navigation.routes,
        routesBefore.sublist(0, routesBefore.length - 1),
      );
      expect(drafts.stoppedRequests, <ItemDraftRequest>[drafts.latestRequest]);
    }
  });

  testWidgets('test_close_stopped_page_property_leaves_no_drafting_behind', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54302);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );

      await tapPageText(tester, page.texts.sectionLabel);

      expect(find.byType(ItemDraftingView), findsNothing);
      expect(find.text(stopDraftingLabel), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_close_stopped_page_property_refused_stop_keeps_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54303);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RefusableItemDraftRepository refusable =
          RefusableItemDraftRepository(ScriptedItemDraftRepository());
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildRefusableDependencies(refusable),
      );
      final List<AppRoute> routesBefore = page.navigation.routes;
      refusable.stopRefusal = PeopleFacingRefusal('Cannot stop $i');

      await tapPageText(tester, page.texts.sectionLabel);

      expect(page.navigation.routes, routesBefore);
      expect(find.byType(ItemDraftingView), findsOneWidget);
      expect(refusable.drafts.stoppedRequests, isEmpty);
    }
  });
}
