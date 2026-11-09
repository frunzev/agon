import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/screens/new_items/item_drafting_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/shared/agent_login_pointer.dart';
import 'package:agent_orchestration/screens/workflows/workflow_drafting_screen.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';

const String _designFailedTitle = 'The draft did not finish';

final class _DraftingTaps {
  final TapCounter stops = TapCounter();
  final TapCounter returns = TapCounter();
  final TapCounter leaves = TapCounter();
  final TapCounter formFills = TapCounter();
}

DraftingState _randomState(Random random) {
  final String? draftProblem = random.nextBool()
      ? 'Failed ${randomHostileText(random)}'
      : null;
  final AgentLoginPointer? pointer = draftProblem != null && random.nextBool()
      ? AgentLoginPointer(hint: 'Hint ${randomText(random)}', onConnect: null)
      : null;
  return DraftingState(
    drafterText: 'Drafter ${randomHostileText(random)}',
    draftProblem: draftProblem,
    stopProblem: random.nextBool() ? 'Stop ${randomText(random)}' : null,
    returnLabel: pickOne(random, <String>[backToWordsLabel, backToDraftLabel]),
    loginPointer: pointer,
  );
}

ItemDraftingView _buildView({
  required NewItemTexts texts,
  required String wish,
  required DraftingState state,
  required _DraftingTaps taps,
}) {
  return ItemDraftingView(
    texts: texts,
    wish: wish,
    state: state,
    onStop: taps.stops.countTap,
    onReturn: taps.returns.countTap,
    onLeave: taps.leaves.countTap,
    onFillForm: taps.formFills.countTap,
  );
}

NewItemTexts _randomTexts(Random random) {
  return describeNewItem(pickOne(random, DraftKind.values));
}

void main() {
  test('test_item_drafting_view_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(1020701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NewItemTexts texts = _randomTexts(random);
      final String wish = randomHostileText(random);
      final DraftingState state = _randomState(random);
      final _DraftingTaps taps = _DraftingTaps();

      final ItemDraftingView view = _buildView(
        texts: texts,
        wish: wish,
        state: state,
        taps: taps,
      );

      expect(view.texts, same(texts));
      expect(view.wish, wish);
      expect(view.state, same(state));
      expect(view.onStop, taps.stops.countTap);
      expect(view.onReturn, taps.returns.countTap);
      expect(view.onLeave, taps.leaves.countTap);
      expect(view.onFillForm, taps.formFills.countTap);
    }
  });

  test('test_item_drafting_view_constructor_property_no_key_unless_given', () {
    final Random random = seededRandom(1020702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ItemDraftingView view = _buildView(
        texts: _randomTexts(random),
        wish: randomHostileText(random),
        state: _randomState(random),
        taps: _DraftingTaps(),
      );

      expect(view.key, isNull);
    }
  });

  test('test_item_drafting_view_constructor_property_wording_matches_'
      'design', () {
    expect(draftFailedTitle, _designFailedTitle);
    expect(draftingSummary, 'Drafting from your words');
    expect(stopDraftingLabel, 'Stop drafting');
    expect(askedSectionTitle, 'You asked');
    expect(backToWordsLabel, 'Back to your words');
  });

  testWidgets('test_item_drafting_view_build_property_problem_swaps_stop_'
      'for_return', (WidgetTester tester) async {
    final Random random = seededRandom(1020703);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final DraftingState state = _randomState(random);
      final NewItemTexts texts = _randomTexts(random);
      final String wish = 'Wish ${randomHostileText(random)}';
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildView(
          texts: texts,
          wish: wish,
          state: state,
          taps: _DraftingTaps(),
        ),
      );

      final String? problem = state.draftProblem;
      final bool failed = problem != null;
      expect(tester.takeException(), isNull);
      expect(find.text(texts.pageTitle), findsOneWidget);
      expect(find.text(wish), findsOneWidget);
      expect(find.text(askedSectionTitle), findsOneWidget);
      expect(find.text(stopDraftingLabel), failed ? findsNothing : findsOne);
      expect(find.text(state.returnLabel), failed ? findsOne : findsNothing);
      expect(find.text(_designFailedTitle), failed ? findsOne : findsNothing);
      expect(find.text(fillInFormLabel), failed ? findsOne : findsNothing);
      expect(find.text(state.drafterText), failed ? findsNothing : findsOne);
      if (problem != null) {
        expect(find.text(problem), findsOneWidget);
      }
    }
  });

  testWidgets('test_item_drafting_view_build_property_stop_problem_only_'
      'while_drafting', (WidgetTester tester) async {
    final Random random = seededRandom(1020704);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final DraftingState state = _randomState(random);
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildView(
          texts: _randomTexts(random),
          wish: 'Wish',
          state: state,
          taps: _DraftingTaps(),
        ),
      );

      final String? stopProblem = state.stopProblem;
      final bool showsStopProblem =
          stopProblem != null && state.draftProblem == null;
      expect(
        find.text(stopFailedTitle),
        showsStopProblem ? findsOneWidget : findsNothing,
      );
      if (stopProblem != null) {
        expect(
          find.text(stopProblem),
          showsStopProblem ? findsOneWidget : findsNothing,
        );
      }
      final AgentLoginPointer? pointer = state.loginPointer;
      if (pointer != null) {
        expect(find.text(pointer.hint), findsOneWidget);
      }
    }
  });

  testWidgets('test_item_drafting_view_build_property_buttons_reach_their_'
      'callbacks', (WidgetTester tester) async {
    final Random random = seededRandom(1020705);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingState state = _randomState(random);
      final NewItemTexts texts = _randomTexts(random);
      final _DraftingTaps taps = _DraftingTaps();
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildView(texts: texts, wish: 'Wish', state: state, taps: taps),
      );

      await tapShownText(tester, texts.sectionLabel);
      if (state.draftProblem == null) {
        await tapShownText(tester, stopDraftingLabel);
      } else {
        await tapShownText(tester, state.returnLabel);
        await tapShownText(tester, fillInFormLabel);
      }

      final bool failed = state.draftProblem != null;
      expect(taps.leaves.count, 1);
      expect(taps.stops.count, failed ? 0 : 1);
      expect(taps.returns.count, failed ? 1 : 0);
      expect(taps.formFills.count, failed ? 1 : 0);
    }
  });
}
