import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/random_inputs.dart';
import 'random_runner_matches.dart';

const List<int> _boundaryCounts = <int>[0, 1, 2, 999, 1000, 1001, 1234];
const String _sharedLabel = 'gpu';

typedef _LabelPair = ({StatusLabel first, StatusLabel second});

void _expectSameLabel(_LabelPair pair) {
  expect(pair.first.text, pair.second.text);
  expect(pair.first.tone, pair.second.tone);
  expect(pair.first.icon, pair.second.icon);
}

List<Runner> _buildSharedLabelRunners(int onlineCount) {
  return <Runner>[
    for (int index = 0; index < onlineCount; index += 1)
      buildMatchRunner(
        deviceId: runnerDeviceAt(index),
        labels: const <String>[_sharedLabel],
        online: true,
      ),
  ];
}

void main() {
  test('test_build_runner_match_label_property_counts_read_like_counts', () {
    for (final int onlineCount in _boundaryCounts) {
      final List<Runner> runners = _buildSharedLabelRunners(onlineCount);

      final String labelled = buildRunnerMatchLabel(
        RunnerWithLabels(const <String>[_sharedLabel]),
        runners,
      ).text;
      final String anyRunner = buildRunnerMatchLabel(
        const AnyFreeRunner(),
        runners,
      ).text;

      if (onlineCount == 0) {
        expect(labelled, 'No match online');
        expect(anyRunner, 'No runner online');
        continue;
      }
      final String matches = describeCount(
        onlineCount,
        singular: 'match',
        plural: 'matches',
      );
      final String runnerCount = describeCount(
        onlineCount,
        singular: 'runner',
        plural: 'runners',
      );
      expect(labelled, '$matches online');
      expect(anyRunner, '$runnerCount online');
    }
  });

  test(
    'test_build_runner_match_label_property_offline_runners_dont_count',
    () {
      final Random random = seededRandom(12331);

      for (int i = 0; i < propertyIterations; i += 1) {
        final RunnerTarget target = randomMatchTarget(random);
        final List<Runner> runners = randomMatchRunners(random);
        final List<Runner> withOffline = <Runner>[
          ...runners,
          for (final Runner runner in randomMatchRunners(random))
            if (!runner.online) runner,
        ];

        _expectSameLabel((
          first: buildRunnerMatchLabel(target, runners),
          second: buildRunnerMatchLabel(target, withOffline),
        ));
      }
    },
  );

  test('test_count_online_property_counts_online_runners_that_match', () {
    final Random random = seededRandom(12332);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = RunnerWithLabels(randomRunnerLabels(random));
      final List<Runner> runners = randomMatchRunners(random);
      final int count = countOnlineMatches(target, runners);

      final String text = buildRunnerMatchLabel(target, runners).text;

      if (count == 0) {
        expect(text, 'No match online');
      } else {
        expect(text, startsWith('$count '));
      }
    }
  });

  test('test_count_online_property_runner_order_is_irrelevant', () {
    final Random random = seededRandom(12333);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = randomMatchTarget(random);
      final List<Runner> runners = randomMatchRunners(random);
      final List<Runner> shuffled = List<Runner>.of(runners);
      shuffled.shuffle(random);

      _expectSameLabel((
        first: buildRunnerMatchLabel(target, runners),
        second: buildRunnerMatchLabel(target, shuffled),
      ));
    }
  });

  test('test_count_online_property_one_more_match_counts_one_more', () {
    final Random random = seededRandom(12334);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> wanted = randomRunnerLabels(random);
      final RunnerTarget target = pickOne<RunnerTarget>(random, <RunnerTarget>[
        const AnyFreeRunner(),
        RunnerWithLabels(wanted),
      ]);
      final List<Runner> runners = randomMatchRunners(random);
      final int countBefore = countOnlineMatches(target, runners);
      final Runner extraMatch = buildMatchRunner(
        deviceId: runnerDeviceAt(runnerDeviceCount),
        labels: runnerLabelPool,
        online: true,
      );

      final String text = buildRunnerMatchLabel(target, <Runner>[
        ...runners,
        extraMatch,
      ]).text;

      expect(text, startsWith('${countBefore + 1} '));
    }
  });

  test('test_build_online_label_property_online_is_normal_with_icon', () {
    final Random random = seededRandom(12335);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = randomMatchTarget(random);
      final List<Runner> runners = randomMatchRunners(random);
      final bool isOnline = countOnlineMatches(target, runners) > 0;

      final StatusLabel label = buildRunnerMatchLabel(target, runners);

      expect(label.icon == AppIconKind.online, isOnline);
      expect(label.tone == StatusTone.normal, isOnline);
    }
  });

  test('test_build_online_label_property_online_text_ends_in_online', () {
    final Random random = seededRandom(12336);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = randomMatchTarget(random);
      final List<Runner> runners = randomMatchRunners(random);
      if (countOnlineMatches(target, runners) == 0) {
        continue;
      }

      final String text = buildRunnerMatchLabel(target, runners).text;

      expect(text.toLowerCase(), endsWith('online'));
      expect(text, isNot(startsWith('No ')));
    }
  });

  test('test_build_online_label_property_specific_follows_its_device', () {
    final Random random = seededRandom(12337);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceId deviceId = runnerDeviceAt(
        random.nextInt(runnerDeviceCount),
      );
      final List<Runner> runners = randomMatchRunners(random);
      bool isDeviceOnline = false;
      for (final Runner runner in runners) {
        if (runner.deviceId == deviceId && runner.online) {
          isDeviceOnline = true;
        }
      }

      final String text = buildRunnerMatchLabel(
        SpecificRunner(deviceId),
        runners,
      ).text;

      expect(text, isDeviceOnline ? 'Online' : 'Offline');
    }
  });
}
