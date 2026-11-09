import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/label_chip.dart';

import '../../support/random_inputs.dart';
import '../../support/runner_pages.dart';
import '../support/runner_detail_harness.dart';
import '../support/runner_settings_screen_checks.dart';

const String _labelsTerm = 'Labels';

Runner _withoutLabels(Runner runner) {
  return Runner(
    deviceId: runner.deviceId,
    labels: const <String>[],
    slotsTotal: runner.slotsTotal,
    slotsBusy: runner.slotsBusy,
    link: runner.link,
    online: runner.online,
    acceptingNewRuns: runner.acceptingNewRuns,
    offers: runner.offers,
    allowedHosts: runner.allowedHosts,
  );
}

Future<void> _openRunnerWithoutLabels(
  WidgetTester tester,
  Random random,
) async {
  final DeviceId runnerId = pickOne(random, runnerPageDeviceIds);
  final FakeRunnerRepository runners = buildOfferingRunners(
    runners: <Runner>[
      for (final DeviceId deviceId in runnerPageDeviceIds)
        _withoutLabels(randomRunnerOn(random, deviceId)),
    ],
    offers: randomPlaceOffers(random),
    problem: null,
  );
  await openRunnerPage(tester, runnerId: runnerId, runners: runners);
}

bool _showsLabelsFact(WidgetTester tester) {
  return readShownTexts(tester, find.byType(FactList)).contains(_labelsTerm);
}

bool _isEmptyFact(Fact fact) {
  return fact.description.isEmpty &&
      fact.chips.isEmpty &&
      fact.content == null;
}

void main() {
  testWidgets('test_runner_detail_screen_build_facts_property_'
      'no_labels_hides_the_labels_fact', (WidgetTester tester) async {
    final Random random = seededRandom(112201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openRunnerWithoutLabels(tester, random);

      expect(_showsLabelsFact(tester), isFalse);
      expect(
        find.descendant(
          of: find.byType(FactList),
          matching: find.byType(LabelChip),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_runner_detail_screen_build_facts_property_'
      'labels_fact_only_with_labels', (WidgetTester tester) async {
    final Random random = seededRandom(112202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunnerDetailPage page = await openAnyRunnerPage(tester, random);

      expect(_showsLabelsFact(tester), page.findRunner().labels.isNotEmpty);
    }
  });

  testWidgets(
    'test_runner_detail_screen_build_facts_property_every_fact_shows_something',
    (WidgetTester tester) async {
      final Random random = seededRandom(112203);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        if (random.nextBool()) {
          await _openRunnerWithoutLabels(tester, random);
        } else {
          await openAnyRunnerPage(tester, random);
        }

        final FactList factList = tester.widget<FactList>(
          find.byType(FactList),
        );
        for (final Fact fact in factList.facts) {
          expect(_isEmptyFact(fact), isFalse, reason: fact.term);
        }
      }
    },
  );
}
