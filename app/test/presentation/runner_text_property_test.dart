import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';

import '../support/random_inputs.dart';
import '../support/sample_runners.dart';

final RegExp _fleetPattern = RegExp(
  r'^(\d+) of (\d+) online · (\d+) free (slot|slots)$',
);
final RegExp _reachablePattern = RegExp(r'^(\d+) of (\d+) reachable$');
final RegExp _wireNamePattern = RegExp(r'[a-z][A-Z]|_');

Runner _withSlots(Runner runner, {required int total, required int busy}) {
  return Runner(
    deviceId: runner.deviceId,
    labels: runner.labels,
    slotsTotal: total,
    slotsBusy: busy,
    link: runner.link,
    online: true,
    acceptingNewRuns: true,
    offers: runner.offers,
    allowedHosts: runner.allowedHosts,
  );
}

List<Runner> _shuffled(Random random, List<Runner> runners) {
  final List<Runner> shuffled = <Runner>[...runners];
  shuffled.shuffle(random);
  return shuffled;
}

void main() {
  test('test_find_runner_reach_property_server_up_reaches_every_online', () {
    final Random random = seededRandom(930901);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = randomRunner(random);

      final RunnerReach reach = findRunnerReach(runner, AppServerState.online);

      final RunnerReach expected = runner.online
          ? RunnerReach.reachable
          : RunnerReach.offline;
      expect(reach, expected);
    }
  });

  test('test_find_runner_reach_property_only_relay_waits_for_server', () {
    final Random random = seededRandom(930902);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = randomRunner(random);
      final AppServerState state = pickOne(random, AppServerState.values);

      final RunnerReach reach = findRunnerReach(runner, state);

      final bool waits = reach == RunnerReach.needsServer;
      expect(
        waits,
        runner.online &&
            runner.link == RunnerLink.relay &&
            state == AppServerState.unreachable,
      );
    }
  });

  test('test_describe_runner_fleet_property_one_free_slot_is_singular', () {
    final Random random = seededRandom(930903);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int total = 1 + random.nextInt(5);
      final Runner single = _withSlots(
        randomRunner(random),
        total: total,
        busy: total - 1,
      );

      final String fleet = describeRunnerFleet(<Runner>[single]);

      expect(fleet, '1 of 1 online · 1 free slot');
    }
    expect(
      describeRunnerFleet(const <Runner>[]),
      '0 of 0 online · 0 free slots',
    );
  });

  test('test_describe_runner_fleet_property_counts_stay_within_bounds', () {
    final Random random = seededRandom(930904);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);

      final RegExpMatch match = _fleetPattern.firstMatch(
        describeRunnerFleet(runners),
      )!;

      final int online = int.parse(match.group(1)!);
      final int freeSlots = int.parse(match.group(3)!);
      expect(online, inInclusiveRange(0, runners.length));
      expect(int.parse(match.group(2)!), runners.length);
      expect(freeSlots, countFreeSlots(runners));
      expect(match.group(4), freeSlots == 1 ? 'slot' : 'slots');
    }
  });

  test('test_describe_runner_fleet_property_order_does_not_matter', () {
    final Random random = seededRandom(930905);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);

      expect(
        describeRunnerFleet(_shuffled(random, runners)),
        describeRunnerFleet(runners),
      );
    }
  });

  test('test_describe_reachable_runners_property_counts_direct_online', () {
    final Random random = seededRandom(930906);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);
      int expected = 0;
      for (final Runner runner in runners) {
        if (runner.online && runner.link != RunnerLink.relay) {
          expected += 1;
        }
      }

      final RegExpMatch match = _reachablePattern.firstMatch(
        describeReachableRunners(runners),
      )!;

      expect(int.parse(match.group(1)!), expected);
      expect(int.parse(match.group(2)!), runners.length);
    }
  });

  test('test_describe_reachable_runners_property_order_does_not_matter', () {
    final Random random = seededRandom(930907);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);

      expect(
        describeReachableRunners(_shuffled(random, runners)),
        describeReachableRunners(runners),
      );
    }
  });

  test('test_describe_runner_link_property_labels_are_plain_words', () {
    for (final RunnerLink link in RunnerLink.values) {
      for (final AppServerState state in AppServerState.values) {
        final String label = describeRunnerLink(link, state);

        expect(label, isNotEmpty);
        expect(label[0], label[0].toUpperCase());
        expect(_wireNamePattern.hasMatch(label), isFalse, reason: label);
        expect(label, isNot(contains(link.name)));
      }
    }
  });

  test('test_describe_runner_link_property_server_up_labels_are_distinct', () {
    final Set<String> labels = <String>{
      for (final RunnerLink link in RunnerLink.values)
        describeRunnerLink(link, AppServerState.online),
    };

    expect(labels.length, RunnerLink.values.length);
    expect(
      describeRunnerLink(RunnerLink.unreachable, AppServerState.unreachable),
      describeRunnerLink(RunnerLink.unreachable, AppServerState.online),
    );
  });
}
