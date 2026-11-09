import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/screens/new_items/item_drafting_view.dart';
import 'package:agent_orchestration/screens/new_items/item_request_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_screen.dart';
import 'package:agent_orchestration/screens/new_items/new_item_sources.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import '../../support/widget_harness.dart';
import 'new_item_harness.dart';
import 'new_item_screen_flow.dart';

NewItemScreen _buildScreen({
  required Key key,
  required DraftKind kind,
  required String? startedFrom,
  required AppDependencies dependencies,
  required AppNavigation navigation,
}) {
  return NewItemScreen(
    key: key,
    kind: kind,
    startedFrom: startedFrom,
    sources: NewItemSources(
      itemDraftRepository: dependencies.itemDraftRepository,
      runnerRepository: dependencies.runnerRepository,
      deviceRepository: dependencies.deviceRepository,
    ),
    review: RecordingDraftReview(),
    formRoute: NewItemFormRoute(kind),
    navigation: navigation,
  );
}

Future<void> _pumpKeyedScreen(WidgetTester tester, NewItemScreen screen) {
  return tester.pumpWidget(wrapInApp(screen, platform: desktopPlatform));
}

void _expectFreshRequest(WidgetTester tester) {
  final TextField wishField = tester.widget(find.byType(TextField).first);
  expect(find.byType(ItemRequestView), findsOneWidget);
  expect(wishField.controller!.text, isEmpty);
  expect(find.text(emptyWishProblem), findsNothing);
}

void main() {
  test('test_new_item_screen_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(11301);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, DraftKind.values);
      final String? startedFrom = randomOptionalHostileText(random);
      final AppDependencies dependencies = buildNewItemDependencies(
        ScriptedItemDraftRepository(),
      );
      final AppNavigation navigation = openNewItemNavigation(kind);
      final Key key = ValueKey<int>(i);

      final NewItemScreen screen = _buildScreen(
        key: key,
        kind: kind,
        startedFrom: startedFrom,
        dependencies: dependencies,
        navigation: navigation,
      );

      expect(screen.key, key);
      expect(screen.kind, kind);
      expect(screen.startedFrom, startedFrom);
      expect(screen.formRoute, NewItemFormRoute(kind));
      expect(identical(screen.navigation, navigation), isTrue);
      expect(
        identical(
          screen.sources.itemDraftRepository,
          dependencies.itemDraftRepository,
        ),
        isTrue,
      );
    }
  });

  testWidgets('test_new_item_screen_constructor_property_start_reaches_all', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11302);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final String? startedFrom = randomOptionalHostileText(random);
      final RecordedNewItemPage page = await openRecordedNewItemPage(
        tester,
        kind: pickOne(random, DraftKind.values),
        startedFrom: startedFrom,
        dependencies: buildNewItemDependencies(drafts),
        size: randomScreenSize(random),
      );
      await draftWish(tester, page: page, wish: 'Wish $i');
      for (int round = 0; round < random.nextInt(3); round += 1) {
        await reachChangeDrafting(
          tester,
          random: random,
          page: page,
          drafts: drafts,
        );
      }

      for (final ItemDraftRequest request in drafts.requests) {
        expect(request.startedFrom, startedFrom);
      }
    }
  });

  testWidgets('test_create_state_property_every_screen_starts_fresh', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11303);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRecordedNewItemPage(
        tester,
        kind: pickOne(random, DraftKind.values),
        startedFrom: randomOptionalHostileText(random),
        dependencies: buildNewItemDependencies(ScriptedItemDraftRepository()),
        size: randomScreenSize(random),
      );

      _expectFreshRequest(tester);
    }
  });

  testWidgets('test_create_state_property_same_key_keeps_the_phase', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11304);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, DraftKind.values);
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final AppDependencies dependencies = buildNewItemDependencies(drafts);
      final AppNavigation navigation = openNewItemNavigation(kind);
      final Key key = UniqueKey();
      useViewSize(tester, desktopSize);
      await _pumpKeyedScreen(
        tester,
        _buildScreen(
          key: key,
          kind: kind,
          startedFrom: null,
          dependencies: dependencies,
          navigation: navigation,
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'Wish $i');
      await tapPageText(tester, describeNewItem(kind).draftLabel);

      await _pumpKeyedScreen(
        tester,
        _buildScreen(
          key: key,
          kind: kind,
          startedFrom: null,
          dependencies: dependencies,
          navigation: navigation,
        ),
      );

      expect(find.byType(ItemDraftingView), findsOneWidget);
      expect(drafts.requests, hasLength(1));
    }
  });

  testWidgets('test_create_state_property_new_screens_forget_old_drafts', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11305);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final AppDependencies dependencies = buildNewItemDependencies(drafts);
      final DraftKind kind = pickOne(random, DraftKind.values);
      final RecordedNewItemPage first = await openRecordedNewItemPage(
        tester,
        kind: kind,
        startedFrom: null,
        dependencies: dependencies,
        size: randomScreenSize(random),
      );
      await draftWish(tester, page: first, wish: 'Wish $i');

      await openRecordedNewItemPage(
        tester,
        kind: kind,
        startedFrom: null,
        dependencies: dependencies,
        size: randomScreenSize(random),
      );

      _expectFreshRequest(tester);
      expect(drafts.requests, hasLength(1));
    }
  });

  testWidgets('test_texts_property_every_phase_names_the_kind', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11306);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      expect(find.text(page.texts.pageTitle), findsOneWidget);
      expect(find.text(page.texts.sectionLabel), findsOneWidget);

      await reportDraftProgress(
        tester,
        drafts: drafts,
        progress: DraftFinished(randomItemDraft(random, page.kind, i)),
      );

      expect(find.text(page.texts.pageTitle), findsOneWidget);
      expect(find.text(page.texts.sectionLabel), findsOneWidget);
    }
  });

  testWidgets('test_texts_property_review_hints_with_the_kind_example', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11307);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );

      await reportDraftProgress(
        tester,
        drafts: drafts,
        progress: DraftFinished(randomItemDraft(random, page.kind, i)),
      );

      expect(find.text(page.texts.changeExample), findsOneWidget);
      for (final DraftKind other in DraftKind.values) {
        if (other != page.kind) {
          expect(
            find.text(describeNewItem(other).changeExample),
            findsNothing,
          );
        }
      }
    }
  });

  testWidgets('test_texts_property_no_page_shows_another_kind', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11308);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(ScriptedItemDraftRepository()),
      );

      expect(find.text(draftingSummary), findsOneWidget);
      for (final DraftKind other in DraftKind.values) {
        if (other != page.kind) {
          expect(find.text(describeNewItem(other).pageTitle), findsNothing);
          expect(find.text(describeNewItem(other).draftLabel), findsNothing);
        }
      }
    }
  });
}
