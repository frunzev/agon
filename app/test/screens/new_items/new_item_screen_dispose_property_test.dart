import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';

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

void main() {
  testWidgets('test_dispose_property_late_progress_never_reaches_the_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10810);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RefusableScene scene = await _openRefusableDraft(tester, random);
      final ScriptedItemDraftRepository drafts = scene.refusable.drafts;
      final RecordedNewItemPage page = scene.page;
      scene.refusable.stopRefusal = PeopleFacingRefusal('Cannot stop $i');
      await tester.pumpWidget(const SizedBox());

      if (random.nextBool()) {
        drafts.reportProgress(
          DraftFinished(randomItemDraft(random, page.kind, i)),
        );
      } else {
        drafts.failLatestDraft(PeopleFacingRefusal('late $i'));
      }
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(page.review.builtItems, isEmpty);
    }
  });

  testWidgets('test_dispose_property_a_stop_ending_after_leaving_is_quiet', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10811);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RefusableScene scene = await _openRefusableDraft(tester, random);
      final Completer<void> pendingStop = Completer<void>();
      scene.refusable.pendingStop = pendingStop;
      if (random.nextBool()) {
        scene.refusable.stopRefusal = PeopleFacingRefusal('Cannot stop $i');
      }
      await tapPageText(tester, stopDraftingLabel);
      await tester.pumpWidget(const SizedBox());

      pendingStop.complete();
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'round $i');
    }
  });

  testWidgets('test_dispose_property_every_phase_disposes_quietly', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10812);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      switch (random.nextInt(3)) {
        case 0:
          await failDraft(tester, drafts: drafts, problem: StateError('x'));
        case 1:
          await reportDraftProgress(
            tester,
            drafts: drafts,
            progress: DraftFinished(randomItemDraft(random, page.kind, i)),
          );
        default:
          await tapPageText(tester, stopDraftingLabel);
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'round $i');
    }
  });
}
