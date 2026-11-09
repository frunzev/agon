import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/screens/task_run/earlier_rounds_block.dart';
import 'package:agent_orchestration/screens/task_run/run_steps_section.dart';

import '../../support/random_inputs.dart';
import 'support/run_steps_section_scenes.dart';

void main() {
  testWidgets(
    'test_run_steps_section_create_state_property_starts_with_rounds_hidden',
    (WidgetTester tester) async {
      final Random random = seededRandom(115201);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SectionInputs inputs = randomSectionInputs(random);
        await pumpSection(
          tester,
          random: random,
          section: buildSection(inputs, key: UniqueKey()),
        );

        expect(readShownRoundStates(tester).values, everyElement(isFalse));
      }
    },
  );

  testWidgets(
    'test_run_steps_section_create_state_property_each_section_owns_state',
    (WidgetTester tester) async {
      final Random random = seededRandom(115202);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SectionInputs inputs = randomSectionInputsWithRounds(random);
        final String tapped = pickOne(
          random,
          listStepsWithRounds(inputs.run),
        ).name;
        await pumpSection(
          tester,
          random: random,
          section: Column(
            children: <Widget>[
              buildSection(inputs, key: UniqueKey()),
              const SizedBox(height: 1),
              buildSection(inputs, key: UniqueKey()),
            ],
          ),
        );

        await tapEarlierRoundsToggle(tester, tapped);

        final List<bool> states = <bool>[
          for (final EarlierRoundsBlock block in tester.widgetList(
            findEarlierRoundsBlock(tapped),
          ))
            block.isShown,
        ];
        expect(states, <bool>[true, false]);
      }
    },
  );

  testWidgets('test_run_steps_section_create_state_property_new_key_resets', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(115203);

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
      await tapEarlierRoundsToggle(tester, tapped);

      await pumpSection(
        tester,
        random: random,
        section: RunStepsSection(
          key: UniqueKey(),
          run: inputs.run,
          task: inputs.task,
          workflow: inputs.workflow,
          deviceNames: galleryDeviceNames,
          now: galleryNow,
        ),
      );

      expect(readShownRoundStates(tester).values, everyElement(isFalse));
    }
  });
}
