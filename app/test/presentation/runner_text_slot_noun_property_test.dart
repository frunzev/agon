import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';

import '../support/random_inputs.dart';

const int _largestSlotTotal = 40;

Runner _randomRunner(Random random, {required int slotsTotal}) {
  final Runner base = pickOne(random, galleryRunners);
  return Runner(
    deviceId: base.deviceId,
    labels: base.labels,
    slotsTotal: slotsTotal,
    slotsBusy: random.nextInt(slotsTotal + 1),
    link: base.link,
    online: true,
    acceptingNewRuns: random.nextBool(),
    offers: base.offers,
    allowedHosts: base.allowedHosts,
  );
}

String _describeReachable(Runner runner) {
  return describeRunnerSummary(
    runner: runner,
    reach: RunnerReach.reachable,
    lastSeen: 'Just now',
  );
}

void main() {
  test('test_describe_runner_summary_property_one_slot_is_singular', () {
    final Random random = seededRandom(615601);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = _randomRunner(random, slotsTotal: 1);

      final String summary = _describeReachable(runner);

      expect(summary, endsWith('${runner.slotsBusy} of 1 slot busy'));
    }
  });

  test('test_describe_runner_summary_property_noun_agrees_with_total', () {
    final Random random = seededRandom(615602);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int slotsTotal = random.nextInt(_largestSlotTotal);
      final Runner runner = _randomRunner(random, slotsTotal: slotsTotal);

      final String summary = _describeReachable(runner);

      final String noun = slotsTotal == 1 ? 'slot' : 'slots';
      expect(summary, endsWith(' $noun busy'));
      expect(summary, isNot(contains(' of 1 slots')));
    }
  });

  test('test_describe_runner_summary_property_counts_read_back', () {
    final Random random = seededRandom(615603);
    final RegExp countsPattern = RegExp(r'(\d+) of (\d+) slots? busy$');
    for (int i = 0; i < propertyIterations; i += 1) {
      final int slotsTotal = random.nextInt(_largestSlotTotal);
      final Runner runner = _randomRunner(random, slotsTotal: slotsTotal);

      final RegExpMatch? counts = countsPattern.firstMatch(
        _describeReachable(runner),
      );

      expect(int.parse(counts!.group(1)!), runner.slotsBusy);
      expect(int.parse(counts.group(2)!), runner.slotsTotal);
    }
  });
}
