import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/presentation/step_round_text.dart';
import 'package:agent_orchestration/screens/shared/status_labels.dart';
import 'package:agent_orchestration/screens/task_run/earlier_rounds_block.dart';
import 'package:agent_orchestration/widgets/clickable.dart';

import '../../support/random_inputs.dart';
import '../../support/random_step_rounds.dart';
import '../support/random_page_windows.dart';

const int _mostRounds = 6;
const int _resultMaximumLines = 6;
const String _longWord = 'reran-the-review-loop ';
final RegExp _toggleWording = RegExp(
  r'^(Show|Hide) ([1-9][0-9]*) earlier rounds?$',
);

EarlierRound _withLongResult(Random random, EarlierRound round) {
  if (random.nextInt(3) != 0) {
    return round;
  }
  return EarlierRound(
    status: round.status,
    startedAt: round.startedAt,
    finishedAt: round.finishedAt,
    result: _longWord * (50 + random.nextInt(400)),
    outcome: round.outcome,
  );
}

RunStep _randomLoopedStep(Random random) {
  final int count = 1 + random.nextInt(_mostRounds);
  return RunStep(
    name: 'implement',
    agentId: null,
    runner: null,
    status: pickOne(random, StepStatus.values),
    startedAt: null,
    finishedAt: null,
    result: null,
    outcome: null,
    loopSource: 'review',
    earlierRounds: <EarlierRound>[
      for (final EarlierRound round in randomEarlierRounds(random, count))
        _withLongResult(random, round),
    ],
  );
}

Future<TapCounter> _pumpBlock(
  WidgetTester tester, {
  required Random random,
  required RunStep step,
  required bool isShown,
}) async {
  final TapCounter toggles = TapCounter();
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SingleChildScrollView(
      child: EarlierRoundsBlock(
        step: step,
        isShown: isShown,
        onToggled: toggles.countTap,
      ),
    ),
  );
  return toggles;
}

String _describeRoundLine(EarlierRound round, int roundNumber) {
  return describeEarlierRound(
    round: round,
    roundNumber: roundNumber,
    statusText: buildStepStatusLabel(round.status).text,
  );
}

void main() {
  testWidgets('test_earlier_rounds_block_build_property_toggle_names_the_'
      'count', (WidgetTester tester) async {
    final Random random = seededRandom(1140801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunStep step = _randomLoopedStep(random);
      final bool isShown = random.nextBool();

      await _pumpBlock(tester, random: random, step: step, isShown: isShown);

      final int count = step.earlierRounds.length;
      final String expected = isShown
          ? describeHideEarlierRounds(count)
          : describeShowEarlierRounds(count);
      final RegExpMatch match = _toggleWording.firstMatch(expected)!;
      expect(find.text(expected), findsOneWidget);
      expect(match.group(1), isShown ? 'Hide' : 'Show');
      expect(int.parse(match.group(2)!), count);
      expect(expected.endsWith('rounds'), count != 1);
    }
  });

  testWidgets('test_earlier_rounds_block_build_property_rounds_only_when_'
      'shown', (WidgetTester tester) async {
    final Random random = seededRandom(1140802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunStep step = _randomLoopedStep(random);
      final bool isShown = random.nextBool();

      await _pumpBlock(tester, random: random, step: step, isShown: isShown);

      expect(tester.takeException(), isNull);
      final int roundLines = find
          .textContaining(RegExp(r'^Round [0-9]+ · '))
          .evaluate()
          .length;
      expect(roundLines, isShown ? step.earlierRounds.length : 0);
    }
  });

  testWidgets('test_earlier_rounds_block_build_property_a_tap_toggles_'
      'once', (WidgetTester tester) async {
    final Random random = seededRandom(1140803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunStep step = _randomLoopedStep(random);
      final TapCounter toggles = await _pumpBlock(
        tester,
        random: random,
        step: step,
        isShown: random.nextBool(),
      );

      await tester.ensureVisible(find.byType(Clickable));
      await tester.tap(find.byType(Clickable));
      await tester.pump();

      expect(toggles.count, 1);
      final Semantics semantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byType(Clickable),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.properties.button, isTrue);
    }
  });

  testWidgets('test_build_round_property_numbers_rounds_in_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1140804);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunStep step = _randomLoopedStep(random);

      await _pumpBlock(tester, random: random, step: step, isShown: true);

      double previousTop = double.negativeInfinity;
      for (int index = 0; index < step.earlierRounds.length; index += 1) {
        final String line = _describeRoundLine(
          step.earlierRounds[index],
          index + 1,
        );
        final Finder shown = find.text(line);
        expect(shown, findsOneWidget, reason: line);
        final double top = tester.getTopLeft(shown).dy;
        expect(top, greaterThan(previousTop));
        previousTop = top;
      }
    }
  });

  testWidgets('test_build_round_property_long_results_stay_six_lines', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1140805);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunStep step = _randomLoopedStep(random);

      await _pumpBlock(tester, random: random, step: step, isShown: true);

      expect(tester.takeException(), isNull);
      for (final EarlierRound round in step.earlierRounds) {
        final String? result = round.result;
        if (result == null) {
          continue;
        }
        final Text shown = tester.widget<Text>(find.text(result).first);
        expect(shown.maxLines, _resultMaximumLines);
        expect(shown.overflow, TextOverflow.ellipsis);
      }
    }
  });

  testWidgets('test_build_round_property_results_shown_only_when_present', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1140806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunStep step = _randomLoopedStep(random);

      await _pumpBlock(tester, random: random, step: step, isShown: true);

      final Iterable<Text> resultTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((Text text) => text.maxLines == _resultMaximumLines);
      final int roundsWithResult = step.earlierRounds
          .where((EarlierRound round) => round.result != null)
          .length;
      expect(resultTexts.length, roundsWithResult);
    }
  });
}
