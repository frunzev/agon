import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart';
import 'package:agent_orchestration/bridge/node/node_change_feed.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';

import '../../support/random_inputs.dart';
import '../support/random_account_json.dart';
import '../support/scripted_node_transport.dart';
import 'support/feed_poll_transport.dart';

const int _firstSeed = 8611000;
const int _sequenceIterations = 40;
const int _largestScriptLength = 10;
const int _feedStartSequence = 1;
const int _settlingTurns = 40;
const Duration _feedPatience = Duration(seconds: 5);

enum _ScriptedPollKind { failure, quiet, changes }

final class _ScriptedPolls {
  _ScriptedPolls({required this.kinds, required this.random});

  final List<_ScriptedPollKind> kinds;
  final Random random;
  final Completer<void> heldPollStarted = Completer<void>();
  final Completer<void> releaseHeldPoll = Completer<void>();
  int answeredPolls = 0;
  int latestSequence = _feedStartSequence;

  int countSuccessfulPolls() {
    int successes = 0;
    for (final _ScriptedPollKind kind in kinds) {
      if (kind != _ScriptedPollKind.failure) {
        successes += 1;
      }
    }
    return successes;
  }

  Future<String> answer(String inputJson) async {
    if (answeredPolls == kinds.length) {
      heldPollStarted.complete();
      await releaseHeldPoll.future;
      return encodeEventsReply(<Object?>[], latestSequence: latestSequence);
    }

    final _ScriptedPollKind kind = kinds[answeredPolls];
    answeredPolls += 1;
    if (kind == _ScriptedPollKind.failure) {
      return encodeErrorReply('poll $answeredPolls failed');
    }

    final List<Object?> notifications = <Object?>[];
    if (kind == _ScriptedPollKind.changes) {
      latestSequence += 1;
      notifications.add(<String, Object?>{
        'sequence': latestSequence,
        'topic': randomChangeTopicJson(random),
      });
    }
    return encodeEventsReply(notifications, latestSequence: latestSequence);
  }
}

final class _QuietThenBrokenPolls {
  _QuietThenBrokenPolls({required this.quietPolls});

  final int quietPolls;
  int answeredPolls = 0;

  Future<String> answer(String inputJson) async {
    answeredPolls += 1;
    if (answeredPolls > quietPolls) {
      return encodeSuccessReply(<String, Object?>{'notifications': 1});
    }
    return answerFeedPollQuietly(inputJson);
  }
}

final class _PollReports {
  int reports = 0;
  bool isListenerGone = false;
  int reportsAfterListenerLeft = 0;
  final List<int> reportsAtEachChange = <int>[];

  void recordPoll() {
    reports += 1;
    if (isListenerGone) {
      reportsAfterListenerLeft += 1;
    }
  }

  void recordChange(ChangeNotification notification) {
    reportsAtEachChange.add(reports);
  }
}

List<_ScriptedPollKind> _randomScript(Random random) {
  final int length = random.nextInt(_largestScriptLength + 1);
  return <_ScriptedPollKind>[
    for (int i = 0; i < length; i += 1)
      pickOne(random, _ScriptedPollKind.values),
  ];
}

NodeChangeFeed _buildReportingFeed(
  FeedPollTransport transport,
  _PollReports reports,
) {
  return NodeChangeFeed(
    channel: NodeCommandChannel(transport: transport),
    retryDelay: Duration.zero,
    onRecovered: ignoreFeedRecovery,
    onPolled: reports.recordPoll,
  );
}

List<int> _modelReportsAtEachChange(List<_ScriptedPollKind> kinds) {
  final List<int> expected = <int>[];
  int successes = 0;
  for (final _ScriptedPollKind kind in kinds) {
    if (kind != _ScriptedPollKind.failure) {
      successes += 1;
    }
    if (kind == _ScriptedPollKind.changes) {
      expected.add(successes);
    }
  }
  return expected;
}

typedef _ScriptedRun = ({_ScriptedPolls polls, _PollReports reports});

Future<_ScriptedRun> _runScriptUntilHeld(Random random) async {
  final _ScriptedPolls polls = _ScriptedPolls(
    kinds: _randomScript(random),
    random: random,
  );
  final _PollReports reports = _PollReports();
  final StreamSubscription<ChangeNotification> subscription =
      _buildReportingFeed(FeedPollTransport(answer: polls.answer), reports)
          .watchChanges(afterSequence: _feedStartSequence)
          .listen(reports.recordChange, onError: ignoreFeedProblem);

  await polls.heldPollStarted.future.timeout(_feedPatience);
  await letFeedTurnsPass(_settlingTurns);
  reports.isListenerGone = true;
  await subscription.cancel();
  polls.releaseHeldPoll.complete();
  await letFeedTurnsPass(_settlingTurns);
  return (polls: polls, reports: reports);
}

void main() {
  test(
    'test_poll_while_listened_property_reports_each_successful_poll_once',
    () async {
      final Random random = seededRandom(_firstSeed);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final _ScriptedRun run = await _runScriptUntilHeld(random);

        expect(run.reports.reports, run.polls.countSuccessfulPolls());
      }
    },
  );

  test(
    'test_poll_while_listened_property_reports_a_poll_before_its_changes',
    () async {
      final Random random = seededRandom(_firstSeed + 1);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final _ScriptedRun run = await _runScriptUntilHeld(random);

        expect(
          run.reports.reportsAtEachChange,
          orderedEquals(_modelReportsAtEachChange(run.polls.kinds)),
        );
      }
    },
  );

  test(
    'test_poll_while_listened_property_no_report_after_the_listener_left',
    () async {
      final Random random = seededRandom(_firstSeed + 2);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final _ScriptedRun run = await _runScriptUntilHeld(random);

        expect(run.reports.reportsAfterListenerLeft, 0);
      }
    },
  );

  test(
    'test_poll_while_listened_property_an_ending_poll_is_never_reported',
    () async {
      final Random random = seededRandom(_firstSeed + 3);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final _QuietThenBrokenPolls polls = _QuietThenBrokenPolls(
          quietPolls: random.nextInt(_largestScriptLength),
        );
        final _PollReports reports = _PollReports();
        final FeedPollTransport transport = FeedPollTransport(
          answer: polls.answer,
        );
        await _buildReportingFeed(transport, reports)
            .watchChanges(afterSequence: _feedStartSequence)
            .handleError(ignoreFeedProblem)
            .drain<void>()
            .timeout(_feedPatience);

        expect(reports.reports, polls.quietPolls);
      }
    },
  );
}
