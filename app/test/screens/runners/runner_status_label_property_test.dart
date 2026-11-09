import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';
import 'package:agent_orchestration/screens/runners/runner_status_label.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_runners.dart';

const Set<String> _knownStatusTexts = <String>{
  'Online',
  'Paused',
  'Offline',
  'Unreachable',
};
const String _summarySeparator = ' · ';

void main() {
  test('test_build_runner_status_label_property_every_reach_has_a_label', () {
    final Random random = seededRandom(108101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = randomRunner(random);
      final Set<String> shownTexts = <String>{};

      for (final RunnerReach reach in RunnerReach.values) {
        final StatusLabel label = buildRunnerStatusLabel(
          runner: runner,
          reach: reach,
        );
        expect(_knownStatusTexts, contains(label.text));
        expect(label.icon, isNotNull);
        shownTexts.add(label.text);
      }

      expect(shownTexts, hasLength(RunnerReach.values.length));
    }
  });

  test('test_build_runner_status_label_property_agrees_with_the_summary', () {
    final Random random = seededRandom(108102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = randomRunner(random);
      final RunnerReach reach = pickOne(random, RunnerReach.values);
      final String summary = describeRunnerSummary(
        runner: runner,
        reach: reach,
        lastSeen: randomText(random),
      );
      final String summaryState = summary.split(_summarySeparator).first;

      final StatusLabel label = buildRunnerStatusLabel(
        runner: runner,
        reach: reach,
      );

      expect(label.text, summaryState, reason: summary);
    }
  });

  test('test_build_runner_status_label_property_pausing_shows_only_if_up', () {
    final Random random = seededRandom(108103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = randomRunner(random);
      final RunnerReach reach = pickOne(random, RunnerReach.values);
      final StatusLabel accepting = buildRunnerStatusLabel(
        runner: runner.asAcceptingNewRuns(),
        reach: reach,
      );
      final StatusLabel paused = buildRunnerStatusLabel(
        runner: runner.asPaused(),
        reach: reach,
      );

      final bool isReachable = reach == RunnerReach.reachable;
      expect(accepting.text == paused.text, !isReachable);
      expect(accepting.tone == StatusTone.normal, isReachable);
      expect(accepting.icon == AppIconKind.online, isReachable);
      expect(paused.tone, StatusTone.muted);
      expect(paused.icon, isNot(AppIconKind.online));
    }
  });
}
