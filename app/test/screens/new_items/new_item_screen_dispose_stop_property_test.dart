import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/item_draft_repository.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/workflows/workflow_drafting_screen.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';
import 'new_item_screen_flow.dart';

typedef _DraftingScene = ({
  ScriptedItemDraftRepository drafts,
  RecordedNewItemPage page,
});

Future<_DraftingScene> _openRandomDrafting(
  WidgetTester tester,
  Random random,
) async {
  final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
  final RecordedNewItemPage page = await openDraftingPage(
    tester,
    random: random,
    dependencies: buildNewItemDependencies(drafts),
  );
  if (random.nextBool()) {
    await reachChangeDrafting(
      tester,
      random: random,
      page: page,
      drafts: drafts,
    );
  }
  if (random.nextBool()) {
    await reportDraftProgress(
      tester,
      drafts: drafts,
      progress: const DraftRunning(
        drafterKind: AgentKind.claudeCode,
        drafterDeviceId: GalleryDeviceIds.macStudio,
      ),
    );
  }
  return (drafts: drafts, page: page);
}

Future<void> _leaveByAnyOtherRoute(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> _endDraftRandomly(
  WidgetTester tester, {
  required Random random,
  required _DraftingScene scene,
  required int round,
}) async {
  switch (random.nextInt(4)) {
    case 0:
      await reportDraftProgress(
        tester,
        drafts: scene.drafts,
        progress: DraftFinished(
          randomItemDraft(random, scene.page.kind, round),
        ),
      );
    case 1:
      await failDraft(
        tester,
        drafts: scene.drafts,
        problem: PeopleFacingRefusal('Failed $round'),
      );
    case 2:
      final bool isChange = scene.drafts.latestRequest.change != null;
      await failDraft(tester, drafts: scene.drafts, problem: StateError('x'));
      await tapPageText(
        tester,
        isChange ? backToDraftLabel : backToWordsLabel,
      );
    default:
      await tapPageText(tester, stopDraftingLabel);
  }
}

void main() {
  testWidgets(
    'test_new_item_screen_dispose_property_leaving_stops_the_draft',
    (WidgetTester tester) async {
      final Random random = seededRandom(52801);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _DraftingScene scene = await _openRandomDrafting(tester, random);
        final ItemDraftRequest running = scene.drafts.latestRequest;

        await _leaveByAnyOtherRoute(tester);

        expect(scene.drafts.stoppedRequests, <ItemDraftRequest>[running]);
        expect(tester.takeException(), isNull, reason: 'round $i');
      }
    },
  );

  testWidgets(
    'test_new_item_screen_dispose_property_ended_drafts_stay_alone',
    (WidgetTester tester) async {
      final Random random = seededRandom(52802);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _DraftingScene scene = await _openRandomDrafting(tester, random);
        await _endDraftRandomly(
          tester,
          random: random,
          scene: scene,
          round: i,
        );
        final List<ItemDraftRequest> stoppedBeforeLeaving =
            List<ItemDraftRequest>.of(scene.drafts.stoppedRequests);

        await _leaveByAnyOtherRoute(tester);

        expect(scene.drafts.stoppedRequests, stoppedBeforeLeaving);
        expect(scene.drafts.stoppedRequests.length, lessThanOrEqualTo(1));
        expect(tester.takeException(), isNull, reason: 'round $i');
      }
    },
  );

  testWidgets('test_new_item_screen_dispose_property_refused_stop_is_quiet', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52803);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RefusableItemDraftRepository refusable =
          RefusableItemDraftRepository(ScriptedItemDraftRepository());
      await openDraftingPage(
        tester,
        random: random,
        dependencies: buildRefusableDependencies(refusable),
      );
      refusable.stopRefusal = random.nextBool()
          ? PeopleFacingRefusal('Cannot stop $i')
          : StateError('node is gone $i');

      await _leaveByAnyOtherRoute(tester);

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(refusable.drafts.stoppedRequests, isEmpty);
    }
  });

  testWidgets('test_new_item_screen_dispose_property_unknown_task_is_quiet', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52804);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _NotFoundStopRepository notFound = _NotFoundStopRepository(
        ScriptedItemDraftRepository(),
      );
      await openDraftingPage(
        tester,
        random: random,
        dependencies: replaceRepositories(
          buildGalleryDependencies(),
          itemDraftRepository: notFound,
        ),
      );

      await _leaveByAnyOtherRoute(tester);

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(notFound.stopAttempts, 1);
    }
  });

  testWidgets('test_new_item_screen_stop_drafting_property_back_link_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52805);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DraftingScene scene = await _openRandomDrafting(tester, random);
      final ItemDraftRequest running = scene.drafts.latestRequest;

      await tapPageText(tester, scene.page.texts.sectionLabel);
      await _leaveByAnyOtherRoute(tester);

      expect(scene.drafts.stoppedRequests, <ItemDraftRequest>[running]);
      expect(scene.page.navigation.routes, hasLength(1));
      expect(tester.takeException(), isNull, reason: 'round $i');
    }
  });

  testWidgets('test_new_item_screen_stop_drafting_property_refusal_retried', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52806);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RefusableItemDraftRepository refusable =
          RefusableItemDraftRepository(ScriptedItemDraftRepository());
      await openDraftingPage(
        tester,
        random: random,
        dependencies: buildRefusableDependencies(refusable),
      );
      final ItemDraftRequest running = refusable.drafts.latestRequest;
      refusable.stopRefusal = PeopleFacingRefusal('Cannot stop $i');
      await tapPageText(tester, stopDraftingLabel);
      expect(find.text(stopFailedTitle), findsOneWidget);
      refusable.stopRefusal = null;

      await _leaveByAnyOtherRoute(tester);

      expect(refusable.drafts.stoppedRequests, <ItemDraftRequest>[running]);
      expect(tester.takeException(), isNull, reason: 'round $i');
    }
  });

  testWidgets(
    'test_new_item_screen_stop_drafting_property_button_stops_once',
    (WidgetTester tester) async {
      final Random random = seededRandom(52807);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _DraftingScene scene = await _openRandomDrafting(tester, random);
        final ItemDraftRequest running = scene.drafts.latestRequest;

        await tapPageText(tester, stopDraftingLabel);
        await _leaveByAnyOtherRoute(tester);

        expect(scene.drafts.stoppedRequests, <ItemDraftRequest>[running]);
        expect(tester.takeException(), isNull, reason: 'round $i');
      }
    },
  );
}

final class _NotFoundStopRepository implements ItemDraftRepository {
  _NotFoundStopRepository(this.drafts);

  final ScriptedItemDraftRepository drafts;
  int stopAttempts = 0;

  @override
  Stream<ItemDraftProgress> draftItem(ItemDraftRequest request) {
    return drafts.draftItem(request);
  }

  @override
  Future<void> stopDrafting(ItemDraftRequest request) async {
    stopAttempts += 1;
    throw const RecordNotFound(kind: 'task', identifier: 'drafting');
  }
}
