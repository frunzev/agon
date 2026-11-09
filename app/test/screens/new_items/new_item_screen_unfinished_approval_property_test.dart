import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/app_route.dart';

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

final class _Finisher {
  int finishCount = 0;
  int refusalsLeft = 0;

  Future<void> finish() async {
    finishCount += 1;
    if (refusalsLeft > 0) {
      refusalsLeft -= 1;
      throw UnfinishedApproval('Still not started', finishApproval: finish);
    }
  }
}

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
  final DraftedItem shown = scene.page.review.builtItems.last;
  await scene.page.review.latestCallbacks.onApproved(shown);
  await pumpFrames(tester);
}

Future<_Finisher> _leaveUnfinished(
  WidgetTester tester,
  _ReviewScene scene,
  String message,
) async {
  final _Finisher finisher = _Finisher();
  scene.page.review.approvalProblem = UnfinishedApproval(
    message,
    finishApproval: finisher.finish,
  );
  await _approveShown(tester, scene);
  scene.page.review.approvalProblem = null;
  return finisher;
}

void main() {
  testWidgets('test_approve_property_unfinished_says_it_did_not_start', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53701);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      final List<AppRoute> routesBefore = scene.page.navigation.routes;
      final String message = 'Created, not started $i';

      await _leaveUnfinished(tester, scene, message);

      expect(find.text(approvalUnfinishedTitle), findsOneWidget);
      expect(find.text(approvalFailedTitle), findsNothing);
      expect(find.text(message), findsOneWidget);
      expect(scene.page.navigation.routes, routesBefore);
    }
  });

  testWidgets('test_approve_property_approving_again_only_finishes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53702);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      final _Finisher finisher = await _leaveUnfinished(tester, scene, 'x$i');
      finisher.refusalsLeft = random.nextInt(3);
      final int approvalCount = finisher.refusalsLeft + 1;

      for (int approval = 0; approval < approvalCount; approval += 1) {
        await _approveShown(tester, scene);
      }

      expect(scene.page.review.approvedItems, <DraftedItem>[scene.draft.item]);
      expect(finisher.finishCount, approvalCount);
      expect(find.text(approvalUnfinishedTitle), findsNothing);
    }
  });

  testWidgets('test_approve_property_a_new_draft_approves_afresh', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53703);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      final _Finisher finisher = await _leaveUnfinished(tester, scene, 'y$i');
      await sendChangeNote(tester, 'Change $i');
      final ItemDraft changed = randomItemDraft(random, scene.page.kind, 1);
      await reportDraftProgress(
        tester,
        drafts: scene.drafts,
        progress: DraftFinished(changed),
      );

      await _approveShown(tester, scene);

      expect(scene.page.review.approvedItems, <DraftedItem>[
        scene.draft.item,
        changed.item,
      ]);
      expect(finisher.finishCount, 0);
    }
  });

  testWidgets('test_build_review_property_plain_refusal_says_not_created', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53704);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      scene.page.review.approvalProblem = PeopleFacingRefusal('No $i');

      await _approveShown(tester, scene);

      expect(find.text(approvalFailedTitle), findsOneWidget);
      expect(find.text(approvalUnfinishedTitle), findsNothing);
      expect(find.text('No $i'), findsOneWidget);
    }
  });

  testWidgets('test_build_review_property_banner_clears_once_finished', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53705);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      await _leaveUnfinished(tester, scene, 'z$i');

      await _approveShown(tester, scene);

      expect(find.text(approvalUnfinishedTitle), findsNothing);
      expect(find.text(approvalFailedTitle), findsNothing);
      expect(find.text('z$i'), findsNothing);
    }
  });

  testWidgets('test_build_review_property_unfinished_title_survives_rebuild', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53706);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(tester, random);
      await _leaveUnfinished(tester, scene, 'w$i');
      final Runner runner = pickOne(
        random,
        scene.page.dependencies.runnerRepository.listRunners(),
      );

      await scene.page.dependencies.runnerRepository.pauseRunner(
        runner.deviceId,
      );
      await tester.pump();

      expect(find.text(approvalUnfinishedTitle), findsOneWidget);
      expect(find.text('w$i'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
