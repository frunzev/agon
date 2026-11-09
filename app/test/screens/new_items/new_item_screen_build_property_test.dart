import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/new_items/item_drafting_view.dart';
import 'package:agent_orchestration/screens/new_items/item_request_view.dart';
import 'package:agent_orchestration/screens/new_items/item_review_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/new_item_route_screens.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';
import 'new_item_screen_flow.dart';

typedef _WiredScene = ({
  DraftKind kind,
  NewItemTexts texts,
  ScriptedItemDraftRepository drafts,
  AppDependencies dependencies,
});

Future<_WiredScene> _openWiredDraft(WidgetTester tester, Random random) async {
  final DraftKind kind = pickOne(random, DraftKind.values);
  final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
  final AppDependencies dependencies = buildNewItemDependencies(drafts);
  final AppNavigation navigation = openNewItemNavigation(kind);
  await pumpNewItemPage(
    tester,
    page: buildNewItemScreen(
      formRoute: NewItemFormRoute(kind),
      startedFrom: randomOptionalHostileText(random),
      dependencies: dependencies,
      navigation: navigation,
    ),
    size: randomScreenSize(random),
  );
  final NewItemTexts texts = describeNewItem(kind);
  expect(tester.takeException(), isNull);
  await tester.enterText(find.byType(TextField).first, 'Wish $kind');
  await tapPageText(tester, texts.draftLabel);
  return (
    kind: kind,
    texts: texts,
    drafts: drafts,
    dependencies: dependencies,
  );
}

String _describeShownName(DraftedItem item) {
  return switch (item) {
    DraftedWork(:final String title) => title,
    DraftedSkill(:final SkillDraft skill) => skill.name,
    DraftedRule(:final RuleDraft rule) => rule.title,
  };
}

int _countPhaseViews() {
  final List<Type> phaseViews = <Type>[
    ItemRequestView,
    ItemDraftingView,
    ItemReviewView,
  ];
  int shown = 0;
  for (final Type view in phaseViews) {
    shown += find.byType(view).evaluate().length;
  }
  return shown;
}

void main() {
  testWidgets(
    'test_new_item_screen_build_property_real_pages_never_overflow',
    (WidgetTester tester) async {
      final Random random = seededRandom(11201);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _WiredScene scene = await _openWiredDraft(tester, random);
        expect(tester.takeException(), isNull, reason: 'drafting $i');
        final Device device = pickOne(
          random,
          scene.dependencies.deviceRepository.listDevices(),
        );
        await reportDraftProgress(
          tester,
          drafts: scene.drafts,
          progress: DraftRunning(
            drafterKind: pickOne(random, AgentKind.values),
            drafterDeviceId: device.id,
          ),
        );
        expect(tester.takeException(), isNull, reason: 'running $i');

        await reportDraftProgress(
          tester,
          drafts: scene.drafts,
          progress: DraftFinished(randomItemDraft(random, scene.kind, i)),
        );

        expect(tester.takeException(), isNull, reason: 'review $i');
        expect(find.text(scene.texts.pageTitle), findsOneWidget);
        expect(find.text(approveLabel), findsOneWidget);
      }
    },
  );

  testWidgets('test_new_item_screen_build_property_real_review_shows_draft', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11202);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _WiredScene scene = await _openWiredDraft(tester, random);
      final ItemDraft draft = randomItemDraft(random, scene.kind, i);

      await reportDraftProgress(
        tester,
        drafts: scene.drafts,
        progress: DraftFinished(draft),
      );

      expect(find.text(_describeShownName(draft.item)), findsWidgets);
      expect(find.text(reviewSummary), findsOneWidget);
      expect(find.text(scene.texts.changeExample), findsOneWidget);
    }
  });

  testWidgets('test_new_item_screen_build_property_failures_render_cleanly', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11203);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _WiredScene scene = await _openWiredDraft(tester, random);
      final String message = 'Refused ${randomHostileText(random)} $i';

      await failDraft(
        tester,
        drafts: scene.drafts,
        problem: PeopleFacingRefusal(message),
      );

      expect(tester.takeException(), isNull, reason: 'failure $i');
      expect(find.text(message), findsOneWidget);
      expect(find.text(scene.texts.pageTitle), findsOneWidget);
    }
  });

  testWidgets('test_build_phase_property_change_drafting_hides_the_draft', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11204);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final ItemDraft draft = await reachChangeDrafting(
        tester,
        random: random,
        page: page,
        drafts: drafts,
      );

      expect(find.byType(ItemDraftingView), findsOneWidget);
      expect(find.byType(ItemReviewView), findsNothing);
      expect(find.text(describeReviewedItem(draft.item)), findsNothing);
    }
  });

  testWidgets('test_build_phase_property_one_phase_view_after_any_progress', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11205);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final List<Device> devices = page.dependencies.deviceRepository
          .listDevices();

      for (int report = 0; report < random.nextInt(3); report += 1) {
        await reportDraftProgress(
          tester,
          drafts: drafts,
          progress: DraftRunning(
            drafterKind: pickOne(random, AgentKind.values),
            drafterDeviceId: pickOne(random, devices).id,
          ),
        );
        expect(_countPhaseViews(), 1);
      }
      if (random.nextBool()) {
        await reportDraftProgress(
          tester,
          drafts: drafts,
          progress: DraftFinished(randomItemDraft(random, page.kind, i)),
        );
      } else {
        await failDraft(tester, drafts: drafts, problem: StateError('x'));
      }

      expect(_countPhaseViews(), 1);
    }
  });
}
