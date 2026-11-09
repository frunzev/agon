import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/screens/runners/runner_problem_banner.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../support/runner_settings_screen_checks.dart';

void main() {
  test('test_runner_problem_banner_constructor_property_keeps_fields', () {
    final Random random = seededRandom(108201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String problem = randomHostileText(random);
      final VoidCallback? onRunLocally = random.nextBool() ? () {} : null;
      final Key key = ValueKey<int>(i);

      final RunnerProblemBanner banner = RunnerProblemBanner(
        problem: problem,
        onRunLocally: onRunLocally,
        key: key,
      );

      expect(banner.problem, problem);
      expect(banner.onRunLocally, same(onRunLocally));
      expect(banner.key, key);
    }
  });

  test(
    'test_runner_problem_banner_constructor_property_keeps_hostile_text',
    () {
      for (final String hostile in <String>[
        '',
        ' ',
        '\n',
        '\u200b',
        'e\u0301',
      ]) {
        final RunnerProblemBanner banner = RunnerProblemBanner(
          problem: hostile,
          onRunLocally: null,
        );

        expect(banner.problem.codeUnits, hostile.codeUnits);
      }
    },
  );

  test('test_runner_problem_banner_constructor_property_no_handler_stays', () {
    final Random random = seededRandom(108204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerProblemBanner banner = RunnerProblemBanner(
        problem: randomHostileText(random),
        onRunLocally: null,
      );

      expect(banner.onRunLocally, isNull);
      expect(banner.key, isNull);
    }
  });

  testWidgets('test_runner_problem_banner_build_property_title_is_above', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = 'Docker problem $i ${randomWordPhrase(random)}';
      await pumpAtRandomWidth(
        tester,
        random,
        RunnerProblemBanner(problem: problem, onRunLocally: () {}),
      );

      final Rect title = tester.getRect(find.text(runnerProblemTitle));
      final Rect shownProblem = tester.getRect(find.text(problem));
      final Rect button = tester.getRect(find.text(runLocallyLabel));
      expect(title.bottom, lessThanOrEqualTo(shownProblem.top));
      expect(shownProblem.bottom, lessThanOrEqualTo(button.top));
    }
  });

  testWidgets('test_runner_problem_banner_build_property_shows_the_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = '${randomHostileText(random)} $i';
      await pumpAtRandomWidth(
        tester,
        random,
        RunnerProblemBanner(problem: problem, onRunLocally: null),
      );

      final List<String> shownTexts = readShownTexts(
        tester,
        find.byType(RunnerProblemBanner),
      );
      expect(shownTexts.first, runnerProblemTitle);
      expect(shownTexts, contains(problem));
      final NoticeBanner notice = tester.widget(find.byType(NoticeBanner));
      expect(notice.tone, BannerTone.attention);
    }
  });

  testWidgets('test_runner_problem_banner_build_property_button_runs_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool hasHandler = random.nextBool();
      int runLocallyCount = 0;
      await pumpAtRandomWidth(
        tester,
        random,
        RunnerProblemBanner(
          problem: randomHostileText(random),
          onRunLocally: hasHandler ? () => runLocallyCount += 1 : null,
        ),
      );

      final Finder button = find.widgetWithText(AppButton, runLocallyLabel);
      expect(button, hasHandler ? findsOneWidget : findsNothing);
      if (hasHandler) {
        await tester.tap(button);
        await tester.pump();
      }
      expect(runLocallyCount, hasHandler ? 1 : 0);
    }
  });
}
