import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import '../support/runner_detail_harness.dart';

const String _pauseLabel = 'Pause new runs';
const String _resumeLabel = 'Resume new runs';

void main() {
  testWidgets('test_build_pause_button_property_label_follows_the_runner', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108808);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);

      final bool isAccepting = page.findRunner().acceptingNewRuns;
      expect(find.text(_pauseLabel), isAccepting ? findsOne : findsNothing);
      expect(find.text(_resumeLabel), isAccepting ? findsNothing : findsOne);
    }
  });

  testWidgets('test_build_pause_button_property_two_taps_round_trip', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108809);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);
      final bool wasAccepting = page.findRunner().acceptingNewRuns;

      await tapButtonLabelled(
        tester,
        wasAccepting ? _pauseLabel : _resumeLabel,
      );
      expect(page.findRunner().acceptingNewRuns, !wasAccepting);
      await tapButtonLabelled(
        tester,
        wasAccepting ? _resumeLabel : _pauseLabel,
      );

      expect(page.findRunner().acceptingNewRuns, wasAccepting);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_build_pause_button_property_only_resume_has_play', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108810);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);

      final bool isAccepting = page.findRunner().acceptingNewRuns;
      final String label = isAccepting ? _pauseLabel : _resumeLabel;
      final AppButton button = tester.widget(
        find.widgetWithText(AppButton, label),
      );
      expect(button.icon, isAccepting ? isNull : AppIconKind.play);
      expect(button.onPressed, isNotNull);
    }
  });
}
