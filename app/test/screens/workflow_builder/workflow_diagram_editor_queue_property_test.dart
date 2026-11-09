import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';

import '../../support/random_inputs.dart';
import 'support/queued_editor_pair.dart';

const int _iterations = 60;
const int _mostEditsPerRound = 8;

Future<List<Workflow>> _applyRandomEdits(
  Random random,
  QueuedEditorPair pair,
) async {
  final List<Workflow> shownStates = <Workflow>[];
  final int editCount = 1 + random.nextInt(_mostEditsPerRound);
  for (int step = 0; step < editCount; step += 1) {
    await pair.apply(randomEditorEdit(random, pair.readExpected()));
    shownStates.add(pair.queued.readLatestWorkflow());
    if (pair.held.heldReplyCount > 0 && random.nextBool()) {
      await pair.releaseOneReply();
    }
  }
  return shownStates;
}

void main() {
  test('test_save_in_order_property_sends_one_save_at_a_time', () async {
    final Random random = seededRandom(1190501);

    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = QueuedEditorPair();

      await _applyRandomEdits(random, pair);
      await pair.releaseEveryReply();

      expect(pair.held.mostSavesInFlight, 1);
      expect(pair.held.savesInFlight, 0);
    }
  });

  test('test_save_in_order_property_every_edit_lands_in_order', () async {
    final Random random = seededRandom(1190502);

    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = QueuedEditorPair();

      await _applyRandomEdits(random, pair);
      await pair.releaseEveryReply();

      expectSameDesign(pair.readSaved(), pair.readExpected());
      expectSameDesign(pair.queued.readLatestWorkflow(), pair.readExpected());
    }
  });

  test('test_save_in_order_property_a_refusal_shows_the_saved_'
      'workflow', () async {
    final Random random = seededRandom(1190503);

    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = QueuedEditorPair();
      final Workflow saved = pair.readSaved();
      final Future<void> firstSave = randomTaskEdit(random, saved)(
        pair.queued,
      );
      final Future<void> refused = expectLater(
        firstSave,
        throwsA(isA<PeopleFacingRefusal>()),
      );
      await randomMoveEdit(random, saved)(pair.queued);

      pair.held.refuseNextReply(PeopleFacingRefusal(randomText(random)));
      await refused;

      expect(pair.held.heldReplyCount, 0);
      expectSameDesign(pair.queued.readLatestWorkflow(), saved);
      expectSameDesign(pair.readSaved(), saved);
    }
  });

  test('test_send_until_latest_is_saved_property_last_sent_is_the_'
      'latest', () async {
    final Random random = seededRandom(1190504);

    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = QueuedEditorPair();

      final List<Workflow> shownStates = await _applyRandomEdits(random, pair);
      await pair.releaseEveryReply();

      expectSameDesign(pair.held.sentWorkflows.last, shownStates.last);
      expect(
        pair.held.sentWorkflows.length,
        lessThanOrEqualTo(shownStates.length),
      );
    }
  });

  test('test_send_until_latest_is_saved_property_sends_shown_states_in_'
      'order', () async {
    final Random random = seededRandom(1190505);

    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = QueuedEditorPair();

      final List<Workflow> shownStates = await _applyRandomEdits(random, pair);
      await pair.releaseEveryReply();

      int nextShownIndex = 0;
      for (final Workflow sent in pair.held.sentWorkflows) {
        while (nextShownIndex < shownStates.length &&
            !hasSameDesign(shownStates[nextShownIndex], sent)) {
          nextShownIndex += 1;
        }
        expect(nextShownIndex, lessThan(shownStates.length));
        nextShownIndex += 1;
      }
    }
  });

  test('test_send_until_latest_is_saved_property_idle_editor_sends_'
      'nothing_more', () async {
    final Random random = seededRandom(1190506);

    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = QueuedEditorPair();
      await _applyRandomEdits(random, pair);
      await pair.releaseEveryReply();
      final int sentCount = pair.held.sentWorkflows.length;

      await pumpEventQueue();

      expect(pair.held.sentWorkflows, hasLength(sentCount));
      expect(pair.held.heldReplyCount, 0);
    }
  });

  test('test_read_latest_workflow_property_shows_each_edit_at_'
      'once', () async {
    final Random random = seededRandom(1190507);

    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = QueuedEditorPair();
      final int editCount = 1 + random.nextInt(_mostEditsPerRound);

      for (int step = 0; step < editCount; step += 1) {
        await pair.apply(randomEditorEdit(random, pair.readExpected()));

        expectSameDesign(
          pair.queued.readLatestWorkflow(),
          pair.readExpected(),
        );
        if (random.nextBool()) {
          await pair.releaseOneReply();
          expectSameDesign(
            pair.queued.readLatestWorkflow(),
            pair.readExpected(),
          );
        }
      }
      await pair.releaseEveryReply();
    }
  });

  test('test_read_latest_workflow_property_idle_reads_the_saved_'
      'workflow', () async {
    final Random random = seededRandom(1190508);

    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = QueuedEditorPair();
      expect(pair.queued.readLatestWorkflow(), same(pair.readSaved()));

      await _applyRandomEdits(random, pair);
      await pair.releaseEveryReply();

      expect(pair.queued.readLatestWorkflow(), same(pair.readSaved()));
    }
  });

  test('test_read_latest_workflow_property_listeners_hear_every_'
      'edit', () async {
    final Random random = seededRandom(1190509);

    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = QueuedEditorPair();
      final List<Workflow> heard = <Workflow>[];
      pair.queued.addListener(
        () => heard.add(pair.queued.readLatestWorkflow()),
      );

      final List<Workflow> shownStates = await _applyRandomEdits(random, pair);
      await pair.releaseEveryReply();

      for (final Workflow shown in shownStates) {
        expect(heard, contains(same(shown)));
      }
      expect(heard.last, same(pair.readSaved()));
    }
  });

  test('test_show_unsaved_property_each_edit_is_heard_before_its_'
      'reply', () async {
    final Random random = seededRandom(1190510);
    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = QueuedEditorPair();
      int heardCount = 0;
      pair.queued.addListener(() => heardCount += 1);

      final int heardBefore = heardCount;
      await pair.apply(randomEditorEdit(random, pair.readExpected()));

      expect(heardCount, heardBefore + 1);
      expect(pair.held.heldReplyCount, 1);
      await pair.releaseEveryReply();
    }
  });

  test('test_show_unsaved_property_the_end_of_saving_is_heard', () async {
    final Random random = seededRandom(1190511);
    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = QueuedEditorPair();
      await _applyRandomEdits(random, pair);
      await pair.apply(randomEditorEdit(random, pair.readExpected()));
      int heardCount = 0;
      pair.queued.addListener(() => heardCount += 1);

      await pair.releaseEveryReply();

      expect(heardCount, greaterThanOrEqualTo(1));
      expect(pair.queued.readLatestWorkflow(), same(pair.readSaved()));
    }
  });

  test('test_show_unsaved_property_disposed_editor_tells_nobody', () async {
    final Random random = seededRandom(1190512);
    for (int i = 0; i < _iterations; i += 1) {
      final QueuedEditorPair pair = QueuedEditorPair();
      int heardCount = 0;
      pair.queued.addListener(() => heardCount += 1);
      await pair.apply(randomEditorEdit(random, pair.readExpected()));
      final int heardBeforeDispose = heardCount;

      pair.queued.dispose();
      await pair.releaseEveryReply();

      expect(heardCount, heardBeforeDispose);
    }
  });
}
