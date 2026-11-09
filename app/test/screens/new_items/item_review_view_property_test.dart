import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/screens/new_items/change_request_composer.dart';
import 'package:agent_orchestration/screens/new_items/draft_approval.dart';
import 'package:agent_orchestration/screens/new_items/item_review_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'change_request_composer_steps.dart';

const String _formText = 'The drafted form';
const String _designProblemsTitle = 'The agent could not fill in everything';
const String _designApprovalTitle = 'It was not created';

final class _ReviewTaps {
  final TapCounter cancels = TapCounter();
  final List<String> askedChanges = <String>[];
}

List<String> _randomProblems(Random random) {
  final int count = random.nextInt(4);
  return <String>[
    for (int index = 0; index < count; index += 1)
      'Field $index: ${randomHostileText(random)}',
  ];
}

ItemReviewView _buildView({
  required NewItemTexts texts,
  required List<String> problems,
  required ApprovalProblem? approvalProblem,
  required _ReviewTaps taps,
}) {
  return ItemReviewView(
    texts: texts,
    problems: problems,
    approvalProblem: approvalProblem,
    form: const Text(_formText),
    onCancel: taps.cancels.countTap,
    onAskForChanges: taps.askedChanges.add,
  );
}

NewItemTexts _randomTexts(Random random) {
  return describeNewItem(pickOne(random, DraftKind.values));
}

ApprovalProblem? _randomApprovalProblem(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return ApprovalProblem(
    title: approvalFailedTitle,
    explanation: 'Refused ${randomHostileText(random)}',
  );
}

void main() {
  test('test_item_review_view_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(1021001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NewItemTexts texts = _randomTexts(random);
      final List<String> problems = _randomProblems(random);
      final ApprovalProblem? approvalProblem = _randomApprovalProblem(random);
      final _ReviewTaps taps = _ReviewTaps();

      final ItemReviewView view = _buildView(
        texts: texts,
        problems: problems,
        approvalProblem: approvalProblem,
        taps: taps,
      );

      expect(view.texts, same(texts));
      expect(view.problems, same(problems));
      expect(view.approvalProblem, approvalProblem);
      expect(view.onCancel, taps.cancels.countTap);
      expect(view.key, isNull);
    }
  });

  test('test_item_review_view_constructor_property_keeps_the_form', () {
    const Widget form = Text(_formText);

    final ItemReviewView view = ItemReviewView(
      texts: describeNewItem(DraftKind.rule),
      problems: const <String>[],
      approvalProblem: null,
      form: form,
      onCancel: TapCounter().countTap,
      onAskForChanges: <String>[].add,
    );

    expect(view.form, same(form));
    expect(view.problems, isEmpty);
  });

  test('test_item_review_view_constructor_property_wording_matches_'
      'design', () {
    expect(draftProblemsTitle, _designProblemsTitle);
    expect(approvalFailedTitle, _designApprovalTitle);
    expect(
      reviewSummary,
      'Check what the agent filled in. Change it here or ask the agent.',
    );
    expect(
      changeHint,
      'The agent drafts it again from what is on screen and your note.',
    );
  });

  testWidgets('test_item_review_view_build_property_banners_follow_the_'
      'problems', (WidgetTester tester) async {
    final Random random = seededRandom(1021002);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final NewItemTexts texts = _randomTexts(random);
      final List<String> problems = _randomProblems(random);
      final ApprovalProblem? approvalProblem = _randomApprovalProblem(random);
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildView(
          texts: texts,
          problems: problems,
          approvalProblem: approvalProblem,
          taps: _ReviewTaps(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(texts.pageTitle), findsOneWidget);
      expect(find.text(_formText), findsOneWidget);
      expect(
        find.text(_designProblemsTitle),
        problems.isEmpty ? findsNothing : findsOneWidget,
      );
      expect(
        find.text(draftProblemsNote),
        problems.isEmpty ? findsNothing : findsOneWidget,
      );
      for (final String problem in problems) {
        expect(find.text(problem), findsOneWidget);
      }
      expect(
        find.text(_designApprovalTitle),
        approvalProblem == null ? findsNothing : findsOneWidget,
      );
    }
  });

  testWidgets('test_item_review_view_build_property_form_sits_between_'
      'banners_and_composer', (WidgetTester tester) async {
    final Random random = seededRandom(1021003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewItemTexts texts = _randomTexts(random);
      final List<String> problems = <String>[
        'Field: ${randomWordPhrase(random)}',
      ];
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildView(
          texts: texts,
          problems: problems,
          approvalProblem: const ApprovalProblem(
            title: approvalFailedTitle,
            explanation: 'Refused',
          ),
          taps: _ReviewTaps(),
        ),
      );

      final TextField composerField = tester.widget(find.byType(TextField));
      final double problemsTop = tester
          .getTopLeft(find.text(_designProblemsTitle))
          .dy;
      final double formTop = tester.getTopLeft(find.text(_formText)).dy;
      final double composerTop = tester
          .getTopLeft(find.byType(ChangeRequestComposer))
          .dy;
      final double hintTop = tester.getTopLeft(find.text(changeHint)).dy;
      expect(problemsTop, lessThan(formTop));
      expect(formTop, lessThan(composerTop));
      expect(composerTop, lessThan(hintTop));
      expect(composerField.decoration!.hintText, texts.changeExample);
    }
  });

  testWidgets('test_item_review_view_build_property_back_cancels_and_notes_'
      'ask_for_changes', (WidgetTester tester) async {
    final Random random = seededRandom(1021004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewItemTexts texts = _randomTexts(random);
      final _ReviewTaps taps = _ReviewTaps();
      final String note = randomChangeNote(random);
      final bool goesBack = random.nextBool();
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildView(
          texts: texts,
          problems: const <String>[],
          approvalProblem: null,
          taps: taps,
        ),
      );

      await typeChangeNote(tester, note);
      await tapShownText(tester, sendChangeLabel);
      if (goesBack) {
        await tapShownText(tester, texts.sectionLabel);
      }

      expect(taps.askedChanges, <String>[note.trim()]);
      expect(taps.cancels.count, goesBack ? 1 : 0);
    }
  });
}
