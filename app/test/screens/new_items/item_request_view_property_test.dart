import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/screens/new_items/item_request_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';

const String _noticeText = 'A notice above the form';

final class _RequestTaps {
  final TapCounter drafts = TapCounter();
  final TapCounter manualAdds = TapCounter();
  final TapCounter backs = TapCounter();
  final List<String> typedWishes = <String>[];
}

ItemRequestView _buildView({
  required NewItemTexts texts,
  required TextEditingController controller,
  required String? wishProblem,
  required Widget? notice,
  required _RequestTaps taps,
}) {
  return ItemRequestView(
    texts: texts,
    wishController: controller,
    wishProblem: wishProblem,
    onWishChanged: taps.typedWishes.add,
    notice: notice,
    onDraft: taps.drafts.countTap,
    onAddManually: taps.manualAdds.countTap,
    onBack: taps.backs.countTap,
  );
}

int _countTaps(List<String> tappedLabels, String label) {
  int count = 0;
  for (final String tapped in tappedLabels) {
    if (tapped == label) {
      count += 1;
    }
  }
  return count;
}

NewItemTexts _randomTexts(Random random) {
  return describeNewItem(pickOne(random, DraftKind.values));
}

void main() {
  test('test_item_request_view_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(1020501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NewItemTexts texts = _randomTexts(random);
      final TextEditingController controller = TextEditingController();
      final String? problem = randomOptionalHostileText(random);
      final _RequestTaps taps = _RequestTaps();

      final ItemRequestView view = _buildView(
        texts: texts,
        controller: controller,
        wishProblem: problem,
        notice: null,
        taps: taps,
      );

      expect(view.texts, same(texts));
      expect(view.wishController, same(controller));
      expect(view.wishProblem, problem);
      expect(view.notice, isNull);
      expect(view.onDraft, taps.drafts.countTap);
      expect(view.onAddManually, taps.manualAdds.countTap);
      expect(view.onBack, taps.backs.countTap);
      controller.dispose();
    }
  });

  test('test_item_request_view_constructor_property_keeps_the_notice', () {
    const Widget notice = Text(_noticeText);
    final TextEditingController controller = TextEditingController();

    final ItemRequestView view = _buildView(
      texts: describeNewItem(DraftKind.task),
      controller: controller,
      wishProblem: null,
      notice: notice,
      taps: _RequestTaps(),
    );

    expect(view.notice, same(notice));
    expect(view.key, isNull);
    controller.dispose();
  });

  test('test_item_request_view_constructor_property_add_manually_wording', () {
    expect(addManuallyLabel, 'Add manually');
    for (final DraftKind kind in DraftKind.values) {
      expect(describeNewItem(kind).draftLabel, isNot(addManuallyLabel));
    }
  });

  testWidgets('test_item_request_view_build_property_shows_texts_notice_and_'
      'problem', (WidgetTester tester) async {
    final Random random = seededRandom(1020502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewItemTexts texts = _randomTexts(random);
      final bool hasNotice = random.nextBool();
      final String? problem = random.nextBool()
          ? 'Problem ${randomWordPhrase(random)}'
          : null;
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildView(
          texts: texts,
          controller: controller,
          wishProblem: problem,
          notice: hasNotice ? const Text(_noticeText) : null,
          taps: _RequestTaps(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(texts.pageTitle), findsOneWidget);
      expect(find.text(texts.sectionLabel), findsOneWidget);
      expect(find.text(texts.question), findsOneWidget);
      expect(find.text(newItemHint), findsOneWidget);
      expect(find.text(texts.draftLabel), findsOneWidget);
      expect(find.text(addManuallyLabel), findsOneWidget);
      expect(
        find.text(_noticeText),
        hasNotice ? findsOneWidget : findsNothing,
      );
      if (problem != null) {
        expect(find.text(problem), findsOneWidget);
      }
    }
  });

  testWidgets('test_item_request_view_build_property_buttons_reach_their_'
      'callbacks', (WidgetTester tester) async {
    final Random random = seededRandom(1020503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewItemTexts texts = _randomTexts(random);
      final _RequestTaps taps = _RequestTaps();
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      final List<String> labels = <String>[
        for (int tap = 0; tap < random.nextInt(6); tap += 1)
          pickOne(random, <String>[
            texts.draftLabel,
            addManuallyLabel,
            texts.sectionLabel,
          ]),
      ];
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildView(
          texts: texts,
          controller: controller,
          wishProblem: null,
          notice: null,
          taps: taps,
        ),
      );

      for (final String label in labels) {
        await tapShownText(tester, label);
      }

      expect(taps.drafts.count, _countTaps(labels, texts.draftLabel));
      expect(taps.manualAdds.count, _countTaps(labels, addManuallyLabel));
      expect(taps.backs.count, _countTaps(labels, texts.sectionLabel));
    }
  });

  testWidgets('test_item_request_view_build_property_typing_fills_the_'
      'given_controller', (WidgetTester tester) async {
    final Random random = seededRandom(1020504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String wish = 'wish ${randomHostileText(random)}';
      final _RequestTaps taps = _RequestTaps();
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildView(
          texts: _randomTexts(random),
          controller: controller,
          wishProblem: null,
          notice: null,
          taps: taps,
        ),
      );

      await tester.enterText(find.byType(TextField), wish);
      await tester.pump();

      expect(controller.text, wish);
      expect(taps.typedWishes.last, wish);
      expect(taps.drafts.count, 0);
    }
  });
}
