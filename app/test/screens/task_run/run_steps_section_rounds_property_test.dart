import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';

import '../../support/random_inputs.dart';
import 'support/run_steps_section_scenes.dart';

const int _mostTapsInASequence = 8;

String _describeToggle(int count, {required String verb}) {
  final String unit = count == 1 ? 'earlier round' : 'earlier rounds';
  return '$verb $count $unit';
}

void main() {
  testWidgets(
    'test_run_steps_section_build_step_main_property_toggle_only_with_rounds',
    (WidgetTester tester) async {
      final Random random = seededRandom(115204);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SectionInputs inputs = randomSectionInputs(random);
        await pumpSection(
          tester,
          random: random,
          section: buildSection(inputs, key: UniqueKey()),
        );

        for (final RunStep step in inputs.run.steps) {
          final int blocks = step.earlierRounds.isEmpty ? 0 : 1;
          expect(findEarlierRoundsBlock(step.name), findsNWidgets(blocks));
        }
      }
    },
  );

  testWidgets(
    'test_run_steps_section_build_step_main_property_toggle_counts_the_rounds',
    (WidgetTester tester) async {
      final Random random = seededRandom(115205);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SectionInputs inputs = randomSectionInputsWithRounds(random);
        await pumpSection(
          tester,
          random: random,
          section: buildSection(inputs, key: UniqueKey()),
        );

        for (final RunStep step in listStepsWithRounds(inputs.run)) {
          final String label = _describeToggle(
            step.earlierRounds.length,
            verb: 'Show',
          );
          expect(
            find.descendant(
              of: findEarlierRoundsBlock(step.name),
              matching: find.text(label),
            ),
            findsOneWidget,
          );
        }
      }
    },
  );

  testWidgets(
    'test_run_steps_section_build_step_main_property_rounds_in_order',
    (WidgetTester tester) async {
      final Random random = seededRandom(115206);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SectionInputs inputs = randomSectionInputsWithRounds(random);
        final RunStep step = pickOne(random, listStepsWithRounds(inputs.run));
        await pumpSection(
          tester,
          random: random,
          section: buildSection(inputs, key: UniqueKey()),
        );

        await tapEarlierRoundsToggle(tester, step.name);

        double previousTop = double.negativeInfinity;
        for (int round = 1; round <= step.earlierRounds.length; round += 1) {
          final Finder line = find.descendant(
            of: findEarlierRoundsBlock(step.name),
            matching: find.textContaining(RegExp('^Round $round · ')),
          );
          expect(line, findsOneWidget, reason: 'round $round');
          final double top = tester.getTopLeft(line).dy;
          expect(top, greaterThan(previousTop));
          previousTop = top;
        }
        final String hide = _describeToggle(
          step.earlierRounds.length,
          verb: 'Hide',
        );
        expect(find.text(hide), findsWidgets);
      }
    },
  );

  testWidgets(
    'test_run_steps_section_toggle_earlier_rounds_property_two_taps_restore',
    (WidgetTester tester) async {
      final Random random = seededRandom(115207);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SectionInputs inputs = randomSectionInputsWithRounds(random);
        final String tapped = pickOne(
          random,
          listStepsWithRounds(inputs.run),
        ).name;
        await pumpSection(
          tester,
          random: random,
          section: buildSection(inputs, key: UniqueKey()),
        );
        final Map<String, bool> before = readShownRoundStates(tester);

        await tapEarlierRoundsToggle(tester, tapped);
        await tapEarlierRoundsToggle(tester, tapped);

        expect(readShownRoundStates(tester), before);
      }
    },
  );

  testWidgets(
    'test_run_steps_section_toggle_earlier_rounds_property_only_that_step',
    (WidgetTester tester) async {
      final Random random = seededRandom(115208);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SectionInputs inputs = randomSectionInputsWithRounds(random);
        final String tapped = pickOne(
          random,
          listStepsWithRounds(inputs.run),
        ).name;
        await pumpSection(
          tester,
          random: random,
          section: buildSection(inputs, key: UniqueKey()),
        );
        final Map<String, bool> before = readShownRoundStates(tester);

        await tapEarlierRoundsToggle(tester, tapped);

        final Map<String, bool> expected = <String, bool>{
          ...before,
          tapped: !before[tapped]!,
        };
        expect(readShownRoundStates(tester), expected);
      }
    },
  );

  testWidgets(
    'test_run_steps_section_toggle_earlier_rounds_property_matches_set_model',
    (WidgetTester tester) async {
      final Random random = seededRandom(115209);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SectionInputs inputs = randomSectionInputsWithRounds(random);
        await pumpSection(
          tester,
          random: random,
          section: buildSection(inputs, key: UniqueKey()),
        );
        final Set<String> shownModel = <String>{};

        final int taps = random.nextInt(_mostTapsInASequence + 1);
        for (int tap = 0; tap < taps; tap += 1) {
          final String tapped = pickOne(
            random,
            listStepsWithRounds(inputs.run),
          ).name;
          await tapEarlierRoundsToggle(tester, tapped);
          if (!shownModel.remove(tapped)) {
            shownModel.add(tapped);
          }

          final Map<String, bool> states = readShownRoundStates(tester);
          for (final String stepName in states.keys) {
            expect(states[stepName], shownModel.contains(stepName));
          }
        }
      }
    },
  );
}
