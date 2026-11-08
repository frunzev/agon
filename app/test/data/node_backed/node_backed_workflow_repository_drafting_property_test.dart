import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../fakes/support/refusals.dart';
import 'support/simulated_workflow_node.dart';
import 'support/workflow_repository_harness.dart';

const String _typePrefix = 'test_node_backed_workflow_repository';
const int _iterations = 30;
const int _pollsOfALongDraft = 1000000;
const int _pollsOfAShortDraft = 40;
const String _descriptionField = 'description';
const String _requestCommand = 'change_workflow';

Future<NodeBackedWorkflowRepository> _openLoaded(
  SimulatedWorkflowNode simulated,
) async {
  final NodeBackedWorkflowRepository repository =
      buildSimulatedWorkflowRepository(simulated);
  await repository.load();
  return repository;
}

Future<void> _yieldTimes(Random random) async {
  final int waits = 1 + random.nextInt(4);
  for (int wait = 0; wait < waits; wait += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

bool _isArgumentRefusal(Object error) => error is ArgumentError;

Future<bool> _isRefusedLocally(Future<Object?> work) {
  return isRefused(() => work, isRefusal: _isArgumentRefusal);
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  test('${_typePrefix}_stop_drafting_property_unknown_drafts_are_refused_'
      'and_send_nothing', () async {
    final Random random = seededRandom(90901);
    final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
      pollsBeforeDraftIsDone: 0,
    );
    final NodeBackedWorkflowRepository repository = await _openLoaded(
      simulated,
    );

    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowDraft draft = WorkflowDraft(
        description: 'Never started ${randomText(random)}',
      );

      await expectLater(repository.stopDrafting(draft), throwsStateError);

      expect(simulated.cancelledRunIds, isEmpty);
      expect(simulated.deletedTaskIds, isEmpty);
      expect(repository.listWorkflows(), isEmpty);
    }
    repository.dispose();
  });

  test('${_typePrefix}_stop_drafting_property_stopping_one_draft_lets_the_'
      'other_finish', () async {
    final Random random = seededRandom(90902);
    for (int i = 0; i < _iterations; i += 1) {
      final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
        pollsBeforeDraftIsDone: _pollsOfAShortDraft,
      );
      final NodeBackedWorkflowRepository repository = await _openLoaded(
        simulated,
      );
      final WorkflowDraft stopped = WorkflowDraft(description: 'Stop $i');
      final WorkflowDraft kept = WorkflowDraft(description: 'Keep $i');
      final Future<void> stoppedStream = repository
          .draftWorkflow(stopped)
          .drain<void>();
      final Future<WorkflowDraftProgress> keptLast = repository
          .draftWorkflow(kept)
          .last;
      await _yieldTimes(random);

      await repository.stopDrafting(stopped);
      await stoppedStream;
      final WorkflowDraftProgress finished = await keptLast;

      expect(simulated.cancelledRunIds, hasLength(1));
      expect(repository.listWorkflows(), hasLength(1));
      expect(repository.listWorkflows().single.id, finished.workflow.id);
      repository.dispose();
    }
  });

  test('${_typePrefix}_draft_workflow_property_refuses_exactly_what_the_node_'
      'calls_blank', () async {
    final Random random = seededRandom(90903);
    final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
      pollsBeforeDraftIsDone: 0,
    );
    final NodeBackedWorkflowRepository repository = await _openLoaded(
      simulated,
    );

    for (int i = 0; i < _iterations; i += 1) {
      final String description = table.randomExoticTitle(random);
      final String trimmedByNode = table.trimByModel(description);

      final bool isRefused = await _isRefusedLocally(
        repository.draftWorkflow(WorkflowDraft(description: description)).last,
      );

      expect(isRefused, trimmedByNode.isEmpty, reason: '${description.runes}');
      if (!isRefused) {
        final Object? sent = simulated.draftCommands.last[_descriptionField];
        expect(sent, trimmedByNode, reason: '${description.runes}');
      }
    }
    repository.dispose();
  });

  test('${_typePrefix}_change_workflow_property_refuses_exactly_what_the_node_'
      'calls_blank', () async {
    final Random random = seededRandom(90904);
    final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
      pollsBeforeDraftIsDone: 0,
    );
    simulated.addWorkflow(name: 'changed', state: signedState);
    final NodeBackedWorkflowRepository repository = await _openLoaded(
      simulated,
    );
    final Workflow workflow = repository.listWorkflows().single;

    for (int i = 0; i < _iterations; i += 1) {
      final String request = table.randomExoticTitle(random);
      final int agentsBefore = simulated.changeAgents.length;

      final bool isRefused = await _isRefusedLocally(
        repository.changeWorkflow(
          workflow.id,
          request,
          pickOne(random, AgentKind.values),
        ),
      );

      final bool isBlankForNode = table.trimByModel(request).isEmpty;
      expect(isRefused, isBlankForNode, reason: '${request.runes}');
      expect(
        simulated.changeAgents.length,
        isBlankForNode ? agentsBefore : agentsBefore + 1,
        reason: _requestCommand,
      );
    }
    repository.dispose();
  });

  test('${_typePrefix}_stop_drafting_property_a_long_draft_stops_without_'
      'a_workflow', () async {
    final Random random = seededRandom(90905);
    final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
      pollsBeforeDraftIsDone: _pollsOfALongDraft,
    );
    final NodeBackedWorkflowRepository repository = await _openLoaded(
      simulated,
    );

    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowDraft draft = WorkflowDraft(description: 'Long $i');
      final List<WorkflowDraftProgress> received = <WorkflowDraftProgress>[];
      final Completer<void> ended = Completer<void>();
      repository
          .draftWorkflow(draft)
          .listen(received.add, onDone: ended.complete);
      await _yieldTimes(random);

      await repository.stopDrafting(draft);
      await ended.future;

      expect(repository.listWorkflows(), isEmpty);
      for (final WorkflowDraftProgress progress in received) {
        expect(progress.isFinished, isFalse);
      }
    }
    repository.dispose();
  });
}
