import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/random_inputs.dart';
import '../support/sample_runners.dart';

const String _serverDownLead = 'Runners on this network still work.';
const String _waitTail = ' wait until the server is back.';
const String _lastSeenMarker = 'zq-last-seen-marker';
final RegExp _busyPattern = RegExp(
  r'^(Online|Paused) · (\d+) of (\d+) slots?',
);

List<String> _runnerNames(int count) {
  return <String>[for (int i = 0; i < count; i += 1) 'runner-$i'];
}

AppServerStatus _statusRetrying(Duration retryInterval) {
  return AppServerStatus(
    address: 'relay.acme.dev',
    state: AppServerState.unreachable,
    lastConnectedAt: null,
    retryInterval: retryInterval,
  );
}

void main() {
  test('test_describe_runner_summary_property_busy_never_exceeds_total', () {
    final Random random = seededRandom(931001);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = randomRunner(random);

      final String summary = describeRunnerSummary(
        runner: runner,
        reach: RunnerReach.reachable,
        lastSeen: randomHostileText(random),
      );

      final RegExpMatch match = _busyPattern.firstMatch(summary)!;
      final int busy = int.parse(match.group(2)!);
      final int total = int.parse(match.group(3)!);
      expect(busy, inInclusiveRange(0, total));
      expect(match.group(1), runner.acceptingNewRuns ? 'Online' : 'Paused');
    }
  });

  test('test_describe_runner_summary_property_offline_keeps_last_seen', () {
    final Random random = seededRandom(931002);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String lastSeen = randomHostileText(random);

      final String summary = describeRunnerSummary(
        runner: randomRunner(random),
        reach: RunnerReach.offline,
        lastSeen: lastSeen,
      );

      expect(summary, 'Offline · last seen $lastSeen');
    }
  });

  test('test_describe_runner_summary_property_last_seen_only_offline', () {
    final Random random = seededRandom(931003);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerReach reach = pickOne(random, RunnerReach.values);

      final String summary = describeRunnerSummary(
        runner: randomRunner(random),
        reach: reach,
        lastSeen: _lastSeenMarker,
      );

      expect(summary.contains(_lastSeenMarker), reach == RunnerReach.offline);
      expect(summary, isNotEmpty);
    }
  });

  test('test_join_names_property_last_two_are_joined_with_and', () {
    final Random random = seededRandom(931004);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = 2 + random.nextInt(6);
      final List<String> names = _runnerNames(count);

      final String notice = describeServerDownNotice(names);

      final String lastTwo = '${names[count - 2]} and ${names[count - 1]}';
      expect(notice, contains('$lastTwo$_waitTail'));
      expect(' and '.allMatches(notice).length, 1);
    }
  });

  test('test_join_names_property_single_name_stands_alone', () {
    final Random random = seededRandom(931005);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = 'gpu${randomHostileText(random)}';

      final String notice = describeServerDownNotice(<String>[name]);

      expect(notice, '$_serverDownLead Runs for $name$_waitTail');
    }
  });

  test('test_join_names_property_names_keep_their_order', () {
    final Random random = seededRandom(931006);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> names = _runnerNames(1 + random.nextInt(7));

      final String notice = describeServerDownNotice(names);

      int previousIndex = -1;
      for (final String name in names) {
        final int index = notice.indexOf(name);
        expect(index, greaterThan(previousIndex));
        previousIndex = index;
      }
    }
  });

  test('test_describe_server_down_notice_property_no_waiters_lead_only', () {
    expect(describeServerDownNotice(const <String>[]), _serverDownLead);
  });

  test('test_describe_server_down_notice_property_waiters_add_a_sentence', () {
    final Random random = seededRandom(931007);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> names = _runnerNames(1 + random.nextInt(7));

      final String notice = describeServerDownNotice(names);

      expect(notice, startsWith('$_serverDownLead Runs for '));
      expect(notice, endsWith(_waitTail));
    }
  });

  test('test_describe_server_retry_property_one_second_is_singular', () {
    final Random random = seededRandom(931008);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int seconds = 1 + random.nextInt(3);

      final String retry = describeServerRetry(
        _statusRetrying(Duration(seconds: seconds)),
      );

      final String unit = seconds == 1 ? 'second' : 'seconds';
      expect(retry, endsWith('trying every $seconds $unit'));
    }
  });
}
