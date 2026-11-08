import 'dart:math';

import '../../../bridge/node/support/feed_poll_transport.dart';
import '../../../support/random_inputs.dart';
import 'synchronization_rig.dart';

const int _largestBatchLength = 3;
const int _startSequence = 3;
const Duration firstResubscribeDelay = Duration(seconds: 1);
const Duration idleLongPoll = Duration(minutes: 1);

enum FeedAnswerKind { ending, quiet, changes }

typedef ScriptedFeedPoll = ({FeedAnswerKind kind, Duration hold});

typedef ReadFakeNow = DateTime Function();

final class LongPollFeedNode {
  LongPollFeedNode({
    required this.script,
    required this.random,
    required this.readNow,
  });

  final List<ScriptedFeedPoll> script;
  final Random random;
  final ReadFakeNow readNow;
  final List<DateTime> feedPollMoments = <DateTime>[];

  Future<String> answer(String inputJson) async {
    final int afterSequence = readPolledAfterSequence(inputJson);
    final String quietReply = encodeEventsReply(
      <Object?>[],
      latestSequence: afterSequence,
    );
    if (afterSequence == 0) {
      return encodeEventsReply(<Object?>[], latestSequence: _startSequence);
    }

    feedPollMoments.add(readNow());
    final int scriptIndex = feedPollMoments.length - 1;
    if (scriptIndex >= script.length) {
      await Future<void>.delayed(idleLongPoll);
      return quietReply;
    }

    final ScriptedFeedPoll poll = script[scriptIndex];
    await Future<void>.delayed(poll.hold);
    switch (poll.kind) {
      case FeedAnswerKind.ending:
        return pickOne(random, feedEndingAnswers)();
      case FeedAnswerKind.quiet:
        return quietReply;
      case FeedAnswerKind.changes:
        return buildChangeBatch(
          random,
          afterSequence: afterSequence,
          notificationCount: 1 + random.nextInt(_largestBatchLength),
        ).reply;
    }
  }

  List<Duration> measureGapsAfterEachScriptedPoll() {
    final List<Duration> gaps = <Duration>[];
    for (int i = 0; i < script.length; i += 1) {
      final bool isNextPollSeen = i + 1 < feedPollMoments.length;
      if (!isNextPollSeen) {
        break;
      }
      gaps.add(feedPollMoments[i + 1].difference(feedPollMoments[i]));
    }
    return gaps;
  }
}

final class BackoffModel {
  BackoffModel({required this.retryDelay});

  final Duration retryDelay;
  Duration resubscribeDelay = firstResubscribeDelay;

  List<Duration> predictGapsAfterEachPoll(List<ScriptedFeedPoll> script) {
    final List<Duration> gaps = <Duration>[];
    for (final ScriptedFeedPoll poll in script) {
      if (poll.kind != FeedAnswerKind.ending) {
        resubscribeDelay = firstResubscribeDelay;
        gaps.add(poll.hold);
        continue;
      }

      final Duration waited = resubscribeDelay < retryDelay
          ? resubscribeDelay
          : retryDelay;
      resubscribeDelay = waited * 2;
      gaps.add(poll.hold + waited);
    }
    return gaps;
  }
}

ScriptedFeedPoll endingFeedPoll() {
  return (kind: FeedAnswerKind.ending, hold: Duration.zero);
}

ScriptedFeedPoll healthyFeedPoll(Random random, {required Duration hold}) {
  final FeedAnswerKind kind = random.nextBool()
      ? FeedAnswerKind.quiet
      : FeedAnswerKind.changes;
  return (kind: kind, hold: hold);
}
