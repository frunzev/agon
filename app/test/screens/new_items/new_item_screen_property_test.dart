import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';
import 'package:agent_orchestration/screens/new_items/item_drafting_view.dart';
import 'package:agent_orchestration/screens/new_items/item_request_view.dart';
import 'package:agent_orchestration/screens/new_items/item_review_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';
import 'new_item_screen_flow.dart';

const int _stepsPerFlow = 9;
const List<String> _blankWishes = <String>[
  '',
  ' ',
  '\t\n',
  '\u00A0',
  '\u2003 \u3000',
];

enum _Phase { request, drafting, failed, review }

final class _Flow {
  _Flow({required this.page, required this.drafts});

  final RecordedNewItemPage page;
  final ScriptedItemDraftRepository drafts;
  _Phase phase = _Phase.request;
  bool isChange = false;
  bool isWishRefused = false;
  int requestCount = 0;
  int stopCount = 0;
  String typedWish = '';
  String sentWish = '';
  DraftedItem? reviewedItem;
}

String _randomWish(Random random) {
  if (random.nextInt(3) == 0) {
    return pickOne(random, _blankWishes);
  }
  return randomHostileText(random);
}

Future<void> _stepOnRequest(
  WidgetTester tester,
  Random random,
  _Flow flow,
) async {
  final String wish = _randomWish(random);
  flow.typedWish = wish;
  flow.isWishRefused = trimUnicodeWhiteSpace(wish).isEmpty;
  await draftWish(tester, page: flow.page, wish: wish);
  if (flow.isWishRefused) {
    return;
  }

  flow.sentWish = trimUnicodeWhiteSpace(wish);
  flow.phase = _Phase.drafting;
  flow.isChange = false;
  flow.requestCount += 1;
  expect(flow.drafts.latestRequest.wish, flow.sentWish);
  expect(flow.drafts.latestRequest.change, isNull);
}

Future<void> _stepOnDrafting(
  WidgetTester tester,
  Random random,
  _Flow flow,
  int round,
) async {
  switch (random.nextInt(5)) {
    case 0:
      final Device device = pickOne(
        random,
        flow.page.dependencies.deviceRepository.listDevices(),
      );
      final AgentKind agent = pickOne(random, AgentKind.values);
      await reportDraftProgress(
        tester,
        drafts: flow.drafts,
        progress: DraftRunning(drafterKind: agent, drafterDeviceId: device.id),
      );
      expect(
        find.text('${agent.label} is drafting on ${device.name}'),
        findsOneWidget,
      );
    case 1:
      final ItemDraft draft = randomItemDraft(random, flow.page.kind, round);
      flow.reviewedItem = draft.item;
      flow.phase = _Phase.review;
      await reportDraftProgress(
        tester,
        drafts: flow.drafts,
        progress: DraftFinished(draft),
      );
      expect(identical(flow.page.review.builtItems.last, draft.item), isTrue);
      for (final String problem in draft.problems) {
        expect(find.text(problem), findsOneWidget);
      }
    case 2:
      final String message = 'Refused ${randomHostileText(random)}';
      flow.phase = _Phase.failed;
      await failDraft(
        tester,
        drafts: flow.drafts,
        problem: PeopleFacingRefusal(message),
      );
      expect(find.text(message), findsOneWidget);
    case 3:
      flow.phase = _Phase.failed;
      await failDraft(tester, drafts: flow.drafts, problem: StateError('x'));
      expect(find.text(unexplainedDraftProblem), findsOneWidget);
    default:
      flow.stopCount += 1;
      flow.phase = flow.isChange ? _Phase.review : _Phase.request;
      final ItemDraftRequest running = flow.drafts.latestRequest;
      await tapPageText(tester, stopDraftingLabel);
      expect(flow.drafts.stoppedRequests.last, same(running));
  }
}

Future<void> _stepOnFailed(WidgetTester tester, _Flow flow) {
  final String label = flow.isChange ? backToDraftLabel : backToWordsLabel;
  flow.phase = flow.isChange ? _Phase.review : _Phase.request;
  return tapPageText(tester, label);
}

Future<void> _stepOnReview(
  WidgetTester tester,
  Random random,
  _Flow flow,
) async {
  final String note = 'Change ${randomHostileText(random)}';
  final DraftedItem shown = flow.reviewedItem!;
  flow.phase = _Phase.drafting;
  flow.isChange = true;
  flow.requestCount += 1;
  await sendChangeNote(tester, note);
  final ItemDraftChange change = flow.drafts.latestRequest.change!;
  expect(flow.drafts.latestRequest.wish, flow.sentWish);
  expect(change.note, trimUnicodeWhiteSpace(note));
  expect(identical(change.draft, shown), isTrue);
}

Future<void> _takeStep(
  WidgetTester tester,
  Random random,
  _Flow flow,
  int round,
) {
  return switch (flow.phase) {
    _Phase.request => _stepOnRequest(tester, random, flow),
    _Phase.drafting => _stepOnDrafting(tester, random, flow, round),
    _Phase.failed => _stepOnFailed(tester, flow),
    _Phase.review => _stepOnReview(tester, random, flow),
  };
}

void _expectPhaseShown(WidgetTester tester, _Flow flow) {
  final NewItemTexts texts = flow.page.texts;
  final bool isDrafting =
      flow.phase == _Phase.drafting || flow.phase == _Phase.failed;
  final String returnLabel = flow.isChange
      ? backToDraftLabel
      : backToWordsLabel;

  expect(find.text(texts.pageTitle), findsOneWidget);
  expect(
    find.byType(ItemRequestView),
    _countWhen(flow.phase == _Phase.request),
  );
  expect(find.byType(ItemDraftingView), _countWhen(isDrafting));
  expect(find.byType(ItemReviewView), _countWhen(flow.phase == _Phase.review));
  expect(
    find.text(stopDraftingLabel),
    _countWhen(flow.phase == _Phase.drafting),
  );
  expect(find.text(returnLabel), _countWhen(flow.phase == _Phase.failed));
  expect(
    find.text(emptyWishProblem),
    _countWhen(flow.phase == _Phase.request && flow.isWishRefused),
  );
  if (flow.phase == _Phase.request) {
    final TextField wishField = tester.widget(find.byType(TextField).first);
    expect(wishField.controller!.text, flow.typedWish);
  }
  if (isDrafting) {
    final ItemDraftingView view = tester.widget(find.byType(ItemDraftingView));
    expect(view.wish, flow.sentWish);
  }
  if (flow.phase == _Phase.review) {
    expect(
      find.text(describeReviewedItem(flow.reviewedItem!)),
      findsOneWidget,
    );
  }
  expect(flow.drafts.stoppedRequests, hasLength(flow.stopCount));
  expect(flow.drafts.requests, hasLength(flow.requestCount));
  expect(tester.takeException(), isNull);
}

Matcher _countWhen(bool isShown) {
  return isShown ? findsOneWidget : findsNothing;
}

void main() {
  testWidgets('test_build_phase_property_random_flows_follow_the_model', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10601);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, DraftKind.values);
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final String? startedFrom = randomOptionalHostileText(random);
      final RecordedNewItemPage page = await openRecordedNewItemPage(
        tester,
        kind: kind,
        startedFrom: startedFrom,
        dependencies: buildNewItemDependencies(drafts),
        size: randomScreenSize(random),
      );
      final _Flow flow = _Flow(page: page, drafts: drafts);

      for (int step = 0; step < _stepsPerFlow; step += 1) {
        await _takeStep(tester, random, flow, step);
        _expectPhaseShown(tester, flow);
      }

      for (final ItemDraftRequest request in drafts.requests) {
        expect(request.kind, kind);
        expect(request.startedFrom, startedFrom);
        expect(request.wish, isNotEmpty);
      }
    }
  });
}
