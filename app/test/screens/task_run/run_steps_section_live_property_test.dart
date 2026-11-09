import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/random_shown_runs.dart';
import 'support/run_steps_section_scenes.dart';

double _randomWidth(Random random) {
  return randomWidth(random, least: narrowestWidth, most: widestWidth);
}

Set<String> _namesWithRounds(Run run) {
  return <String>{
    for (final RunStep step in listStepsWithRounds(run)) step.name,
  };
}

SectionInputs _receiveLiveUpdate(Random random, SectionInputs shown) {
  final Workflow workflow = shown.workflow!;
  final Run updated = buildShownRun(
    random,
    runId: shown.run.id,
    taskId: shown.task.id,
    steps: randomStepsOfWorkflow(random, workflow: workflow, now: galleryNow),
    now: galleryNow,
  );
  return (run: updated, task: shown.task, workflow: workflow);
}

void main() {
  testWidgets(
    'test_run_steps_section_is_showing_earlier_rounds_property_hidden_first',
    (WidgetTester tester) async {
      final Random random = seededRandom(115301);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SectionInputs inputs = randomSectionInputs(random);
        await pumpSection(
          tester,
          random: random,
          section: buildSection(inputs, key: UniqueKey()),
        );

        for (final String stepName in _namesWithRounds(inputs.run)) {
          expect(isShowingEarlierRounds(tester, stepName), isFalse);
        }
        expect(find.textContaining(RegExp(r'^Round \d+ · ')), findsNothing);
      }
    },
  );

  testWidgets(
    'test_run_steps_section_is_showing_earlier_rounds_property_kept_live',
    (WidgetTester tester) async {
      final Random random = seededRandom(115302);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final Key sectionKey = UniqueKey();
        final double width = _randomWidth(random);
        final SectionInputs first = randomSectionInputs(random);
        await pumpScrollableAtWidth(
          tester,
          width: width,
          child: buildSection(first, key: sectionKey),
        );
        final Set<String> toggled = <String>{
          for (final String stepName in _namesWithRounds(first.run))
            if (random.nextBool()) stepName,
        };
        for (final String stepName in toggled) {
          await tapEarlierRoundsToggle(tester, stepName);
        }

        final SectionInputs updated = _receiveLiveUpdate(random, first);
        await pumpScrollableAtWidth(
          tester,
          width: width,
          child: buildSection(updated, key: sectionKey),
        );

        for (final String stepName in _namesWithRounds(updated.run)) {
          expect(
            isShowingEarlierRounds(tester, stepName),
            toggled.contains(stepName),
          );
        }
      }
    },
  );

  testWidgets(
    'test_run_steps_section_is_showing_earlier_rounds_property_new_hidden',
    (WidgetTester tester) async {
      final Random random = seededRandom(115303);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final Key sectionKey = UniqueKey();
        final double width = _randomWidth(random);
        final SectionInputs first = randomSectionInputs(random);
        await pumpScrollableAtWidth(
          tester,
          width: width,
          child: buildSection(first, key: sectionKey),
        );
        for (final String stepName in _namesWithRounds(first.run)) {
          await tapEarlierRoundsToggle(tester, stepName);
        }

        final SectionInputs updated = _receiveLiveUpdate(random, first);
        await pumpScrollableAtWidth(
          tester,
          width: width,
          child: buildSection(updated, key: sectionKey),
        );

        final Set<String> gainedRounds = _namesWithRounds(updated.run)
            .difference(_namesWithRounds(first.run));
        for (final String stepName in gainedRounds) {
          expect(isShowingEarlierRounds(tester, stepName), isFalse);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}
