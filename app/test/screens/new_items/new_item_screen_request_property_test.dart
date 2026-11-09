import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';
import 'package:agent_orchestration/screens/new_items/item_request_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';
import 'new_item_screen_flow.dart';

const List<String> _whiteSpacePads = <String>[
  '',
  ' ',
  '\t',
  '\n',
  '\u00A0',
  '\u2003',
  '\u3000',
  '\u2028',
];

String _pad(Random random, String words) {
  return '${pickOne(random, _whiteSpacePads)}$words'
      '${pickOne(random, _whiteSpacePads)}';
}

Future<RecordedNewItemPage> _openRequest(
  WidgetTester tester, {
  required Random random,
  required ScriptedItemDraftRepository drafts,
  required String? startedFrom,
}) {
  return openRecordedNewItemPage(
    tester,
    kind: pickOne(random, DraftKind.values),
    startedFrom: startedFrom,
    dependencies: buildNewItemDependencies(drafts),
    size: randomScreenSize(random),
  );
}

void main() {
  testWidgets('test_describe_request_property_first_requests_carry_context', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11001);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final String? startedFrom = randomOptionalHostileText(random);
      final RecordedNewItemPage page = await _openRequest(
        tester,
        random: random,
        drafts: drafts,
        startedFrom: startedFrom,
      );
      final String words = 'Wish $i ${randomHostileText(random)}';

      await draftWish(tester, page: page, wish: words);

      final ItemDraftRequest request = drafts.requests.single;
      expect(request.kind, page.kind);
      expect(request.wish, trimUnicodeWhiteSpace(words));
      expect(request.startedFrom, startedFrom);
      expect(request.change, isNull);
    }
  });

  testWidgets('test_describe_request_property_change_requests_keep_context', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11002);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final String? startedFrom = randomOptionalHostileText(random);
      final RecordedNewItemPage page = await _openRequest(
        tester,
        random: random,
        drafts: drafts,
        startedFrom: startedFrom,
      );
      await draftWish(tester, page: page, wish: 'Wish $i');

      await reachChangeDrafting(
        tester,
        random: random,
        page: page,
        drafts: drafts,
      );

      expect(drafts.requests, hasLength(2));
      expect(drafts.latestRequest.kind, page.kind);
      expect(drafts.latestRequest.wish, 'Wish $i');
      expect(drafts.latestRequest.startedFrom, startedFrom);
      expect(drafts.latestRequest.change, isNotNull);
    }
  });

  testWidgets('test_describe_request_property_wish_is_trimmed_like_the_node', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11003);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await _openRequest(
        tester,
        random: random,
        drafts: drafts,
        startedFrom: null,
      );
      final String words = 'Ship ${randomWordPhrase(random)} $i';

      await draftWish(tester, page: page, wish: _pad(random, words));

      expect(drafts.latestRequest.wish, words);
    }
  });

  testWidgets('test_start_first_draft_property_blank_wishes_send_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11004);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await _openRequest(
        tester,
        random: random,
        drafts: drafts,
        startedFrom: null,
      );
      final String blank = _pad(random, pickOne(random, _whiteSpacePads));

      await draftWish(tester, page: page, wish: blank);

      expect(drafts.requests, isEmpty);
      expect(find.text(emptyWishProblem), findsOneWidget);
      expect(find.byType(ItemRequestView), findsOneWidget);
    }
  });

  testWidgets('test_start_first_draft_property_each_tap_sends_one_request', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11005);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await _openRequest(
        tester,
        random: random,
        drafts: drafts,
        startedFrom: null,
      );
      final int draftCount = 1 + random.nextInt(3);

      for (int round = 0; round < draftCount; round += 1) {
        await draftWish(tester, page: page, wish: 'Wish $round');
        await tapPageText(tester, stopDraftingLabel);
      }

      expect(drafts.requests, hasLength(draftCount));
      expect(drafts.requests.toSet(), hasLength(draftCount));
    }
  });

  testWidgets('test_start_first_draft_property_problem_clears_on_typing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11006);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await _openRequest(
        tester,
        random: random,
        drafts: drafts,
        startedFrom: null,
      );
      await draftWish(tester, page: page, wish: ' ');

      await tester.enterText(
        find.byType(TextField).first,
        'Wish ${randomHostileText(random)}',
      );
      await tester.pump();

      expect(find.text(emptyWishProblem), findsNothing);
      expect(drafts.requests, isEmpty);
    }
  });

  testWidgets('test_open_form_above_request_property_add_manually_stacks', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11007);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await _openRequest(
        tester,
        random: random,
        drafts: drafts,
        startedFrom: null,
      );
      final List<AppRoute> routesBefore = page.navigation.routes;
      final String words = randomHostileText(random);
      await tester.enterText(find.byType(TextField).first, words);

      await tapPageText(tester, addManuallyLabel);

      expect(page.navigation.routes, <AppRoute>[
        ...routesBefore,
        NewItemFormRoute(page.kind),
      ]);
      expect(drafts.requests, isEmpty);
      final TextField field = tester.widget(find.byType(TextField).first);
      expect(field.controller!.text, words);
    }
  });

  testWidgets('test_build_request_property_back_link_closes_only_the_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11008);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await _openRequest(
        tester,
        random: random,
        drafts: drafts,
        startedFrom: null,
      );
      final AppRoute below = page.navigation.routes.first;

      await tapPageText(tester, page.texts.sectionLabel);

      expect(page.navigation.routes, <AppRoute>[below]);
      expect(drafts.requests, isEmpty);
    }
  });

  testWidgets('test_new_item_screen_constructor_property_kind_sets_texts', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11009);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildNewItemDependencies(
        ScriptedItemDraftRepository(),
      );
      final DraftKind kind = pickOne(random, DraftKind.values);
      final NewItemTexts texts = describeNewItem(kind);

      await openRecordedNewItemPage(
        tester,
        kind: kind,
        startedFrom: randomOptionalHostileText(random),
        dependencies: dependencies,
        size: randomScreenSize(random),
      );

      expect(find.text(texts.pageTitle), findsOneWidget);
      expect(find.text(texts.question), findsOneWidget);
      expect(find.text(texts.draftLabel), findsOneWidget);
      expect(find.text(texts.sectionLabel), findsOneWidget);
      expect(find.text(newItemHint), findsOneWidget);
    }
  });
}
