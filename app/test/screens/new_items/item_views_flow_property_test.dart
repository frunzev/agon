import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/new_items/item_drafting_view.dart';
import 'package:agent_orchestration/screens/new_items/item_request_view.dart';
import 'package:agent_orchestration/screens/new_items/item_review_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import '../support/random_page_windows.dart';
import 'new_item_harness.dart';

enum _Phase { request, drafting, failed, review }

const int _mostFlowSteps = 9;

final class _FlowModel {
  _Phase phase = _Phase.request;
  bool hasDraft = false;
  bool isDraftingChange = false;
  int startedDrafts = 0;
  int stoppedDrafts = 0;
  String? shownProblem;

  void leaveDrafting() {
    phase = hasDraft ? _Phase.review : _Phase.request;
  }
}

Future<AppNavigation> _openNewItemInRandomWindow(
  WidgetTester tester,
  Random random,
  DraftKind kind,
  ScriptedItemDraftRepository drafts,
) async {
  final AppRoute route = newItemRoutes[kind]!;
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: randomPageWindowSize(random),
    route: SectionRoute(route.section),
    dependencies: buildNewItemDependencies(drafts),
  );
  navigation.openRoute(route);
  await pumpFrames(tester);
  return navigation;
}

Finder _findComposerField(NewItemTexts texts) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is TextField &&
        widget.decoration?.hintText == texts.changeExample,
  );
}

Future<void> _tapAndSettle(WidgetTester tester, String label) async {
  await tapShownText(tester, label);
  await pumpFrames(tester);
}

Future<void> _stepFromRequest(
  WidgetTester tester,
  Random random,
  NewItemTexts texts,
  _FlowModel model,
) async {
  final bool isBlank = random.nextInt(4) == 0;
  final String wish = isBlank ? '  ' : 'Wish ${randomWordPhrase(random)}';
  await tester.enterText(find.byType(TextField).first, wish);
  await _tapAndSettle(tester, texts.draftLabel);
  if (isBlank) {
    model.shownProblem = emptyWishProblem;
    return;
  }
  model.phase = _Phase.drafting;
  model.isDraftingChange = false;
  model.startedDrafts += 1;
  model.shownProblem = null;
}

Future<void> _stepFromDrafting(
  WidgetTester tester,
  Random random,
  DraftKind kind,
  ScriptedItemDraftRepository drafts,
  _FlowModel model,
) async {
  switch (random.nextInt(4)) {
    case 0:
      drafts.reportProgress(
        DraftRunning(
          drafterKind: pickOne(random, AgentKind.values),
          drafterDeviceId: GalleryDeviceIds.officeServer,
        ),
      );
      await pumpFrames(tester);
    case 1:
      final ItemDraft gallery = findGalleryItemDraft(kind);
      final List<String> problems = <String>[
        for (int index = 0; index < random.nextInt(3); index += 1)
          'Problem $index ${randomWordPhrase(random)}',
      ];
      await finishNewItemDraft(
        tester,
        drafts,
        ItemDraft(item: gallery.item, problems: problems),
      );
      model.phase = _Phase.review;
      model.hasDraft = true;
    case 2:
      final String problem = 'Refused ${randomWordPhrase(random)}';
      drafts.failLatestDraft(PeopleFacingRefusal(problem));
      await pumpFrames(tester);
      model.phase = _Phase.failed;
      model.shownProblem = problem;
    default:
      await _tapAndSettle(tester, stopDraftingLabel);
      model.stoppedDrafts += 1;
      model.leaveDrafting();
  }
}

Future<void> _stepFromReview(
  WidgetTester tester,
  Random random,
  NewItemTexts texts,
  _FlowModel model,
) async {
  final Finder composer = _findComposerField(texts);
  await tester.ensureVisible(composer);
  await tester.enterText(composer, 'Note ${randomWordPhrase(random)}');
  await _tapAndSettle(tester, sendChangeLabel);
  model.phase = _Phase.drafting;
  model.isDraftingChange = true;
  model.startedDrafts += 1;
}

void _expectPhaseShown(WidgetTester tester, _FlowModel model) {
  final _Phase phase = model.phase;
  final bool isDrafting = phase == _Phase.drafting || phase == _Phase.failed;
  final String returnLabel = model.isDraftingChange
      ? backToDraftLabel
      : backToWordsLabel;
  expect(tester.takeException(), isNull);
  expect(
    find.byType(ItemRequestView),
    phase == _Phase.request ? findsOne : findsNothing,
  );
  expect(find.byType(ItemDraftingView), isDrafting ? findsOne : findsNothing);
  expect(
    find.byType(ItemReviewView),
    phase == _Phase.review ? findsOne : findsNothing,
  );
  expect(
    find.text(stopDraftingLabel),
    phase == _Phase.drafting ? findsOne : findsNothing,
  );
  expect(
    find.text(returnLabel),
    phase == _Phase.failed ? findsOne : findsNothing,
  );
  final String? problem = model.shownProblem;
  if (problem != null && phase != _Phase.review) {
    expect(find.text(problem), findsOneWidget);
  }
}

void main() {
  testWidgets('test_item_drafting_view_build_property_random_flows_show_'
      'exactly_one_phase', (WidgetTester tester) async {
    final Random random = seededRandom(1022001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, DraftKind.values);
      final NewItemTexts texts = describeNewItem(kind);
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final _FlowModel model = _FlowModel();
      await _openNewItemInRandomWindow(tester, random, kind, drafts);

      final int stepCount = random.nextInt(_mostFlowSteps);
      for (int step = 0; step < stepCount; step += 1) {
        switch (model.phase) {
          case _Phase.request:
            await _stepFromRequest(tester, random, texts, model);
          case _Phase.drafting:
            await _stepFromDrafting(tester, random, kind, drafts, model);
          case _Phase.failed:
            await _tapAndSettle(
              tester,
              model.isDraftingChange ? backToDraftLabel : backToWordsLabel,
            );
            model.shownProblem = null;
            model.leaveDrafting();
          case _Phase.review:
            await _stepFromReview(tester, random, texts, model);
        }

        _expectPhaseShown(tester, model);
        expect(drafts.requests, hasLength(model.startedDrafts));
        expect(drafts.stoppedRequests, hasLength(model.stoppedDrafts));
      }
    }
  });

  testWidgets('test_item_review_view_build_property_change_requests_carry_'
      'note_and_draft', (WidgetTester tester) async {
    final Random random = seededRandom(1022002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, DraftKind.values);
      final NewItemTexts texts = describeNewItem(kind);
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final String note = ' Note ${randomWordPhrase(random)} ';
      await _openNewItemInRandomWindow(tester, random, kind, drafts);
      await startNewItemDraft(tester, texts.draftLabel);
      final ItemDraft draft = findGalleryItemDraft(kind);
      await finishNewItemDraft(tester, drafts, draft);

      final Finder composer = _findComposerField(texts);
      await tester.ensureVisible(composer);
      await tester.enterText(composer, note);
      await _tapAndSettle(tester, sendChangeLabel);

      final ItemDraftChange change = drafts.latestRequest.change!;
      expect(change.note, note.trim());
      expect(change.draft, isA<DraftedItem>());
      expect(drafts.latestRequest.wish, newItemWish);
      expect(drafts.latestRequest.kind, kind);
      expect(find.text(newItemWish), findsOneWidget);
    }
  });
}
