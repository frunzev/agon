import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/drafting_rig.dart';
import 'support/simulated_node_replies.dart';

const String _typePrefix = 'test_node_workflow_drafting';
const int _iterations = 20;
const int _pollsOfALongDraft = 1000000;
const int _largestShortPolls = 4;
const Duration _pausingPollInterval = Duration(milliseconds: 30);

WorkflowDraft _randomDraft(Random random) {
  return WorkflowDraft(description: 'Draft ${randomWordPhrase(random)}x');
}

void main() {
  test('${_typePrefix}_constructor_property_sends_nothing_until_asked', () {
    final Random random = seededRandom(85301);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> sent = <String>[];
      NodeWorkflowDrafting(
        channel: buildSimulatedChannel((String inputJson) {
          sent.add(inputJson);
          return '';
        }),
        pollInterval: Duration(milliseconds: random.nextInt(1000)),
      );

      expect(sent, isEmpty);
    }
  });

  test('${_typePrefix}_constructor_property_each_drafting_keeps_its_own_'
      'drafts', () async {
    final Random random = seededRandom(85302);
    for (int i = 0; i < _iterations; i += 1) {
      final DraftingRig first = DraftingRig(
        pollsBeforeDraftIsDone: _pollsOfALongDraft,
        pollInterval: Duration.zero,
      );
      final DraftingRig second = DraftingRig(
        pollsBeforeDraftIsDone: _pollsOfALongDraft,
        pollInterval: Duration.zero,
      );
      final WorkflowDraft draft = _randomDraft(random);
      final List<WorkflowDraftProgress> received = <WorkflowDraftProgress>[];
      final Future<void> streaming = first
          .streamDraft(draft)
          .forEach(received.add);
      await waitForDraftProgress(received, 1);

      await expectLater(second.drafting.stopDrafting(draft), throwsStateError);
      await first.drafting.stopDrafting(draft);
      await streaming;
    }
  });

  test('${_typePrefix}_constructor_property_a_zero_interval_still_'
      'finishes', () async {
    final Random random = seededRandom(85303);
    for (int i = 0; i < _iterations; i += 1) {
      final int polls = random.nextInt(_largestShortPolls);
      final DraftingRig rig = DraftingRig(
        pollsBeforeDraftIsDone: polls,
        pollInterval: Duration.zero,
      );

      final List<WorkflowDraftProgress> progress = await rig
          .streamDraft(_randomDraft(random))
          .toList();

      expect(progress.last.isFinished, isTrue);
      expect(rig.stored, hasLength(1));
    }
  });

  test('${_typePrefix}_stream_draft_progress_property_a_running_draft_'
      'cannot_be_streamed_twice', () async {
    final Random random = seededRandom(85304);
    for (int i = 0; i < _iterations; i += 1) {
      final DraftingRig rig = DraftingRig(
        pollsBeforeDraftIsDone: _pollsOfALongDraft,
        pollInterval: Duration.zero,
      );
      final WorkflowDraft draft = _randomDraft(random);
      final List<WorkflowDraftProgress> received = <WorkflowDraftProgress>[];
      final Future<void> streaming = rig
          .streamDraft(draft)
          .forEach(received.add);
      await waitForDraftProgress(received, 1);

      await expectLater(rig.streamDraft(draft).toList(), throwsStateError);
      await rig.drafting.stopDrafting(draft);
      await streaming;
      expect(rig.simulated.draftCommands, hasLength(1));
    }
  });

  test('${_typePrefix}_stream_draft_progress_property_separate_drafts_'
      'finish_independently', () async {
    final Random random = seededRandom(85305);
    for (int i = 0; i < _iterations; i += 1) {
      final DraftingRig rig = DraftingRig(
        pollsBeforeDraftIsDone: random.nextInt(_largestShortPolls),
        pollInterval: Duration.zero,
      );
      final List<WorkflowDraft> drafts = <WorkflowDraft>[
        for (int index = 0; index < 2 + random.nextInt(3); index += 1)
          _randomDraft(random),
      ];

      final List<List<WorkflowDraftProgress>> streams = await Future.wait(
        <Future<List<WorkflowDraftProgress>>>[
          for (final WorkflowDraft draft in drafts)
            rig.streamDraft(draft).toList(),
        ],
      );

      expect(rig.stored, hasLength(drafts.length));
      for (final List<WorkflowDraftProgress> progress in streams) {
        expect(progress.last.isFinished, isTrue);
        expect(
          progress.where((WorkflowDraftProgress step) => step.isFinished),
          hasLength(1),
        );
      }
    }
  });

  test('${_typePrefix}_stream_draft_progress_property_a_finished_draft_can_'
      'be_drafted_again', () async {
    final Random random = seededRandom(85306);
    for (int i = 0; i < _iterations; i += 1) {
      final DraftingRig rig = DraftingRig(
        pollsBeforeDraftIsDone: random.nextInt(_largestShortPolls),
        pollInterval: Duration.zero,
      );
      final WorkflowDraft draft = _randomDraft(random);

      await rig.streamDraft(draft).toList();
      final List<WorkflowDraftProgress> again = await rig
          .streamDraft(draft)
          .toList();

      expect(again.last.isFinished, isTrue);
      expect(rig.stored, hasLength(2));
      await expectLater(rig.drafting.stopDrafting(draft), throwsStateError);
    }
  });

  test('${_typePrefix}_stop_drafting_property_restarting_a_stopped_draft_'
      'keeps_the_new_draft_running', () async {
    final Random random = seededRandom(85307);
    for (int i = 0; i < _iterations; i += 1) {
      final DraftingRig rig = DraftingRig(
        pollsBeforeDraftIsDone: _pollsOfALongDraft,
        pollInterval: _pausingPollInterval,
      );
      final WorkflowDraft draft = _randomDraft(random);
      final List<WorkflowDraftProgress> first = <WorkflowDraftProgress>[];
      final Completer<Object?> firstEnd = Completer<Object?>();
      rig
          .streamDraft(draft)
          .listen(
            first.add,
            onError: firstEnd.complete,
            onDone: () => firstEnd.complete(null),
          );
      await waitForDraftProgress(first, 1 + random.nextInt(3));

      await rig.drafting.stopDrafting(draft);
      final List<WorkflowDraftProgress> second = <WorkflowDraftProgress>[];
      final Future<void> secondStreaming = rig
          .streamDraft(draft)
          .forEach(second.add);
      final Object? firstProblem = await firstEnd.future;
      await waitForDraftProgress(second, 1);

      expect(firstProblem, isNull);
      await rig.drafting.stopDrafting(draft);
      await secondStreaming;
      expect(rig.simulated.cancelledRunIds, hasLength(2));
      expect(rig.simulated.cancelledRunIds.toSet(), hasLength(2));
    }
  });

  test('${_typePrefix}_stop_drafting_property_a_stopped_stream_ends_'
      'unfinished_and_cannot_be_stopped_again', () async {
    final Random random = seededRandom(85308);
    for (int i = 0; i < _iterations; i += 1) {
      final DraftingRig rig = DraftingRig(
        pollsBeforeDraftIsDone: _pollsOfALongDraft,
        pollInterval: Duration.zero,
      );
      final WorkflowDraft draft = _randomDraft(random);
      final List<WorkflowDraftProgress> received = <WorkflowDraftProgress>[];
      final Future<void> streaming = rig
          .streamDraft(draft)
          .forEach(received.add);
      await waitForDraftProgress(received, random.nextInt(3));

      await rig.drafting.stopDrafting(draft);
      await streaming;

      expect(
        received.any((WorkflowDraftProgress step) => step.isFinished),
        isFalse,
      );
      expect(rig.stored, isEmpty);
      await expectLater(rig.drafting.stopDrafting(draft), throwsStateError);
    }
  });

  test('${_typePrefix}_stop_drafting_property_cancels_and_deletes_only_its_'
      'own_task', () async {
    final Random random = seededRandom(85309);
    for (int i = 0; i < _iterations; i += 1) {
      final DraftingRig rig = DraftingRig(
        pollsBeforeDraftIsDone: _pollsOfALongDraft,
        pollInterval: Duration.zero,
      );
      final WorkflowDraft stopped = _randomDraft(random);
      final WorkflowDraft kept = _randomDraft(random);
      final List<WorkflowDraftProgress> stoppedSteps =
          <WorkflowDraftProgress>[];
      final List<WorkflowDraftProgress> keptSteps = <WorkflowDraftProgress>[];
      final Future<void> stoppedStreaming = rig
          .streamDraft(stopped)
          .forEach(stoppedSteps.add);
      final Future<void> keptStreaming = rig
          .streamDraft(kept)
          .forEach(keptSteps.add);
      await waitForDraftProgress(stoppedSteps, 1);
      await waitForDraftProgress(keptSteps, 1);

      await rig.drafting.stopDrafting(stopped);
      await stoppedStreaming;

      expect(rig.simulated.cancelledRunIds, hasLength(1));
      expect(rig.simulated.deletedTaskIds, hasLength(1));
      expect(
        rig.simulated.cancelledRunIds.single,
        'run-of-${rig.simulated.deletedTaskIds.single}',
      );
      await rig.drafting.stopDrafting(kept);
      await keptStreaming;
      expect(rig.simulated.cancelledRunIds.toSet(), hasLength(2));
    }
  });
}
