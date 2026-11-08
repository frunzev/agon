import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow_draft.dart';

import '../../support/random_inputs.dart';
import 'support/drafting_rig.dart';

const String _typePrefix = 'test_node_workflow_drafting';
const int _iterations = 12;
const int _pollsOfALongDraft = 1000000;
const int _largestShortPolls = 4;
const Duration _pausingPollInterval = Duration(milliseconds: 30);
const String _statusCommand = 'workflow_draft_status';
const String _draftCommand = 'draft_workflow';

typedef _Restart = ({
  DraftingRig rig,
  WorkflowDraft draft,
  Object? firstProblem,
  List<WorkflowDraftProgress> second,
  Future<void> secondStreaming,
});

WorkflowDraft _randomDraft(Random random) {
  return WorkflowDraft(description: 'Draft ${randomWordPhrase(random)}x');
}

Future<_Restart> _stopAndRestart(Random random) async {
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
  await waitForDraftProgress(first, 1 + random.nextInt(2));
  await rig.drafting.stopDrafting(draft);

  final List<WorkflowDraftProgress> second = <WorkflowDraftProgress>[];
  final Future<void> secondStreaming = rig
      .streamDraft(draft)
      .forEach(second.add);
  final Object? firstProblem = await firstEnd.future;
  return (
    rig: rig,
    draft: draft,
    firstProblem: firstProblem,
    second: second,
    secondStreaming: secondStreaming,
  );
}

int _countStatusReadsOf(DraftingRig rig, Object? taskId) {
  int count = 0;
  for (final Map<String, Object?> command in rig.sentCommands) {
    final bool isStatus = command['command'] == _statusCommand;
    if (isStatus && command['task_id'] == taskId) {
      count += 1;
    }
  }
  return count;
}

void main() {
  test('${_typePrefix}_is_still_running_property_a_replaced_draft_stops_'
      'polling_its_old_task', () async {
    final Random random = seededRandom(85601);
    for (int i = 0; i < _iterations; i += 1) {
      final _Restart restart = await _stopAndRestart(random);
      final Object? oldTaskId = restart.rig.simulated.deletedTaskIds.single;
      final int oldReads = _countStatusReadsOf(restart.rig, oldTaskId);

      await waitForDraftProgress(restart.second, 2);

      expect(restart.firstProblem, isNull);
      expect(_countStatusReadsOf(restart.rig, oldTaskId), oldReads);
      await restart.rig.drafting.stopDrafting(restart.draft);
      await restart.secondStreaming;
    }
  });

  test('${_typePrefix}_is_still_running_property_the_new_draft_keeps_'
      'reporting_after_the_old_stream_ends', () async {
    final Random random = seededRandom(85602);
    for (int i = 0; i < _iterations; i += 1) {
      final _Restart restart = await _stopAndRestart(random);
      final int reportsAtOldEnd = restart.second.length;

      await waitForDraftProgress(restart.second, reportsAtOldEnd + 1);

      expect(restart.second.length, greaterThan(reportsAtOldEnd));
      expect(restart.second.last.isFinished, isFalse);
      await restart.rig.drafting.stopDrafting(restart.draft);
      await restart.secondStreaming;
      expect(restart.rig.stored, isEmpty);
    }
  });

  test('${_typePrefix}_is_still_running_property_a_failed_start_frees_the_'
      'draft', () async {
    final Random random = seededRandom(85603);
    for (int i = 0; i < _iterations; i += 1) {
      final DraftingRig rig = DraftingRig(
        pollsBeforeDraftIsDone: random.nextInt(_largestShortPolls),
        pollInterval: Duration.zero,
      );
      final WorkflowDraft draft = _randomDraft(random);
      rig.simulated.failingCommands.add(_draftCommand);

      await expectLater(rig.streamDraft(draft).toList(), throwsStateError);
      await expectLater(rig.drafting.stopDrafting(draft), throwsStateError);
      rig.simulated.failingCommands.remove(_draftCommand);
      final List<WorkflowDraftProgress> retried = await rig
          .streamDraft(draft)
          .toList();

      expect(retried.last.isFinished, isTrue);
      expect(rig.stored, hasLength(1));
    }
  });
}
