import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/new_items/drafting_notices.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';

const String _designTitle = 'No runner is taking new runs';
const String _designText =
    'An agent drafts on a runner. The draft waits until one takes new runs, '
    'or you can fill in the form yourself.';
const String _designButton = 'Fill in the form';

void _ignoreTap() {}

void main() {
  test('test_no_runner_notice_constructor_property_keeps_the_callback', () {
    final TapCounter counter = TapCounter();

    final NoRunnerNotice notice = NoRunnerNotice(onFillForm: counter.countTap);
    notice.onFillForm();

    expect(notice.onFillForm, counter.countTap);
    expect(counter.count, 1);
  });

  test('test_no_runner_notice_constructor_property_no_key_unless_given', () {
    final Random random = seededRandom(1020401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(1000));

      expect(const NoRunnerNotice(onFillForm: _ignoreTap).key, isNull);
      expect(NoRunnerNotice(onFillForm: _ignoreTap, key: key).key, key);
    }
  });

  test('test_no_runner_notice_constructor_property_wording_matches_'
      'design', () {
    expect(noRunnerTitle, _designTitle);
    expect(noRunnerText, _designText);
    expect(fillInFormLabel, _designButton);
  });

  testWidgets('test_no_runner_notice_build_property_shows_title_text_and_'
      'button', (WidgetTester tester) async {
    final Random random = seededRandom(1020402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: const SingleChildScrollView(
          child: NoRunnerNotice(onFillForm: _ignoreTap),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(_designTitle), findsOneWidget);
      expect(find.text(_designText), findsOneWidget);
      expect(find.text(_designButton), findsOneWidget);
    }
  });

  testWidgets('test_no_runner_notice_build_property_each_tap_fills_the_'
      'form_once', (WidgetTester tester) async {
    final Random random = seededRandom(1020403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TapCounter counter = TapCounter();
      final int tapCount = random.nextInt(4);
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: SingleChildScrollView(
          child: NoRunnerNotice(onFillForm: counter.countTap),
        ),
      );

      for (int tap = 0; tap < tapCount; tap += 1) {
        await tapShownText(tester, _designButton);
      }

      expect(counter.count, tapCount);
    }
  });

  testWidgets('test_no_runner_notice_build_property_is_an_attention_'
      'banner', (WidgetTester tester) async {
    final Random random = seededRandom(1020404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: const SingleChildScrollView(
          child: NoRunnerNotice(onFillForm: _ignoreTap),
        ),
      );

      final NoticeBanner banner = tester.widget(find.byType(NoticeBanner));
      expect(banner.tone, BannerTone.attention);
      expect(banner.title, _designTitle);
      expect(banner.actions, hasLength(1));
    }
  });
}
