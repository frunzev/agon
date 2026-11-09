import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/task_form/submit_refusal.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_app_server_refusals.dart';
import '../../support/random_inputs.dart';
import 'task_form_scene.dart';

const String _failureSuffix = ' did not work';

SubmitRefusal _randomRefusal(Random random) {
  return SubmitRefusal(
    actionLabel: randomHostileText(random),
    explanation: randomRefusalReason(random),
  );
}

List<String> _readBannerTexts(WidgetTester tester) {
  final Iterable<Text> texts = tester.widgetList<Text>(
    find.descendant(
      of: find.byType(NoticeBanner),
      matching: find.byType(Text),
    ),
  );
  return <String>[for (final Text text in texts) text.data ?? ''];
}

void main() {
  test('test_submit_refusal_constructor_property_keeps_both_texts', () {
    final Random random = seededRandom(1132801);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String actionLabel = randomHostileText(random);
      final String explanation = randomHostileText(random);

      final SubmitRefusal refusal = SubmitRefusal(
        actionLabel: actionLabel,
        explanation: explanation,
      );

      expect(refusal.actionLabel, actionLabel);
      expect(refusal.explanation, explanation);
    }
  });

  test('test_submit_refusal_constructor_property_texts_never_mix', () {
    final Random random = seededRandom(1132802);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String shared = randomHostileText(random);

      final SubmitRefusal refusal = SubmitRefusal(
        actionLabel: 'label $shared',
        explanation: 'explanation $shared',
      );

      expect(refusal.actionLabel, startsWith('label '));
      expect(refusal.explanation, startsWith('explanation '));
    }
  });

  test(
    'test_submit_refusal_constructor_property_carries_caught_reasons',
    () async {
      final Random random = seededRandom(1132803);
      for (int i = 0; i < propertyIterations; i += 1) {
        final String actionLabel = randomHostileText(random);
        final String reason = randomRefusalReason(random);

        final SubmitRefusal? caught = await catchRefusal(
          actionLabel: actionLabel,
          action: () async => throw PeopleFacingRefusal(reason),
        );

        expect(caught?.actionLabel, actionLabel);
        expect(caught?.explanation, reason);
      }
    },
  );

  test('test_submit_refusal_banner_constructor_property_keeps_refusal', () {
    final Random random = seededRandom(1132804);
    for (int i = 0; i < propertyIterations; i += 1) {
      final SubmitRefusal refusal = _randomRefusal(random);

      final SubmitRefusalBanner banner = SubmitRefusalBanner(refusal: refusal);

      expect(banner.refusal, same(refusal));
    }
  });

  test(
    'test_submit_refusal_banner_constructor_property_no_key_unless_given',
    () {
      final Random random = seededRandom(1132805);
      for (int i = 0; i < propertyIterations; i += 1) {
        final SubmitRefusal refusal = _randomRefusal(random);

        expect(SubmitRefusalBanner(refusal: refusal).key, isNull);
      }
    },
  );

  test('test_submit_refusal_banner_constructor_property_keeps_the_key', () {
    final Random random = seededRandom(1132806);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(1000));

      final SubmitRefusalBanner banner = SubmitRefusalBanner(
        refusal: _randomRefusal(random),
        key: key,
      );

      expect(banner.key, key);
    }
  });

  testWidgets('test_submit_refusal_banner_build_property_shows_both_texts', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1132807);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SubmitRefusal refusal = _randomRefusal(random);

      await pumpScrollingPage(
        tester,
        random: random,
        page: SubmitRefusalBanner(refusal: refusal),
      );

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(_readBannerTexts(tester), <String>[
        '${refusal.actionLabel}$_failureSuffix',
        refusal.explanation,
      ]);
    }
  });

  testWidgets('test_submit_refusal_banner_build_property_is_a_danger_alert', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1132808);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScrollingPage(
        tester,
        random: random,
        page: SubmitRefusalBanner(refusal: _randomRefusal(random)),
      );

      final NoticeBanner banner = tester.widget(find.byType(NoticeBanner));
      expect(banner.tone, BannerTone.danger);
      expect(banner.icon, AppIconKind.alert);
      expect(banner.actions, isEmpty);
    }
  });

  testWidgets('test_submit_refusal_banner_build_property_shows_the_reason', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1132809);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String actionLabel = 'Action ${randomText(random)}';
      final String reason = randomRefusalReason(random);
      final SubmitRefusal? refusal = await catchRefusal(
        actionLabel: actionLabel,
        action: () async => throw PeopleFacingRefusal(reason),
      );

      await pumpScrollingPage(
        tester,
        random: random,
        page: SubmitRefusalBanner(refusal: refusal!),
      );

      expect(find.text('$actionLabel$_failureSuffix'), findsOneWidget);
      expect(_readBannerTexts(tester).last, reason);
    }
  });
}
