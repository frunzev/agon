import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/random_inputs.dart';
import 'random_runner_matches.dart';

void main() {
  test('test_build_offline_label_property_no_match_draws_attention', () {
    final Random random = seededRandom(12338);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = randomMatchTarget(random);
      final List<Runner> runners = randomMatchRunners(random);
      final bool isOffline = countOnlineMatches(target, runners) == 0;

      final StatusLabel label = buildRunnerMatchLabel(target, runners);

      expect(label.icon == AppIconKind.offline, isOffline);
      expect(label.tone == StatusTone.attention, isOffline);
    }
  });

  test('test_build_offline_label_property_offline_text_has_no_count', () {
    final Random random = seededRandom(12339);
    final RegExp digit = RegExp('[0-9]');

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = randomMatchTarget(random);
      final List<Runner> runners = randomMatchRunners(random);
      if (countOnlineMatches(target, runners) > 0) {
        continue;
      }

      final String text = buildRunnerMatchLabel(target, runners).text;

      expect(text, isNot(contains(digit)));
      expect(text.trim(), isNotEmpty);
    }
  });

  test('test_build_offline_label_property_no_runners_is_offline', () {
    final Random random = seededRandom(12340);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = randomMatchTarget(random);

      final StatusLabel label = buildRunnerMatchLabel(
        target,
        const <Runner>[],
      );

      expect(label.icon, AppIconKind.offline);
      expect(label.tone, StatusTone.attention);
    }
  });
}
