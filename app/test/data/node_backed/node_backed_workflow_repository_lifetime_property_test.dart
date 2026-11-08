import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/out_of_order_replies.dart';
import 'support/workflow_workspace_rig.dart';

const String _typePrefix = 'test_node_backed_workflow_repository';
const String _listCommand = 'list_workflows';
const String _workflowKind = 'workflow';
const int _iterations = 40;
const int _longestSwitchRun = 6;

Future<void> _switchToRandomWorkspace(
  Random random,
  WorkflowWorkspaceRig rig,
) async {
  await rig.workspaces.repository.switchWorkspace(
    pickOne(random, rig.workspaceIds),
  );
  await pumpEventQueue();
}

void _expectListingMatchesCurrentWorkspace(
  NodeBackedWorkflowRepository repository,
  WorkflowWorkspaceRig rig,
) {
  final WorkspaceId current = currentRigWorkspaceId(rig);
  expect(
    listShownWorkflowIds(repository),
    predictListedWorkflowIds(rig.simulated, current),
  );
  expect(
    listShownChangedWorkflowIds(repository, rig.simulated),
    predictChangedWorkflowIds(rig.simulated, current),
  );
}

final class _ListingRecorder {
  _ListingRecorder(this.repository);

  final NodeBackedWorkflowRepository repository;
  final List<List<String>> heardListings = <List<String>>[];

  void record() {
    heardListings.add(listShownWorkflowIds(repository));
  }
}

void main() {
  test('${_typePrefix}_constructor_property_starts_empty_and_asks_the_node_'
      'nothing', () async {
    final Random random = seededRandom(90601);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);
      await pumpEventQueue();

      expect(rig.repository.listWorkflows(), isEmpty);
      for (final Map<String, Object?> view in rig.simulated.views) {
        final WorkflowId workflowId = WorkflowId(
          readSimulatedWorkflowId(view),
        );
        expect(rig.repository.findPendingChange(workflowId), isNull);
      }
      expect(rig.transport.exchanges, isEmpty);
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_constructor_property_finding_before_a_load_is_'
      'record_not_found', () async {
    final Random random = seededRandom(90602);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);
      final List<String> candidates = <String>[
        for (final Map<String, Object?> view in rig.simulated.views)
          readSimulatedWorkflowId(view),
        randomText(random),
      ];
      final String identifier = pickOne(random, candidates);

      expect(
        () => rig.repository.findWorkflow(WorkflowId(identifier)),
        throwsA(
          isA<RecordNotFound>()
              .having(
                (RecordNotFound error) => error.kind,
                'kind',
                _workflowKind,
              )
              .having(
                (RecordNotFound error) => error.identifier,
                'identifier',
                identifier,
              ),
        ),
      );
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_constructor_property_follows_a_workspace_switch_'
      'without_a_load', () async {
    final Random random = seededRandom(90603);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);

      await _switchToRandomWorkspace(random, rig);

      _expectListingMatchesCurrentWorkspace(rig.repository, rig);
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_dispose_property_stops_following_workspace_'
      'switches', () async {
    final Random random = seededRandom(90604);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);
      await rig.repository.load();
      final List<String> shownBefore = listShownWorkflowIds(rig.repository);
      final int listsBefore = countSentCommands(rig.transport, _listCommand);

      rig.repository.dispose();
      await _switchToRandomWorkspace(random, rig);

      expect(countSentCommands(rig.transport, _listCommand), listsBefore);
      expect(listShownWorkflowIds(rig.repository), shownBefore);
    }
  });

  test('${_typePrefix}_dispose_property_sibling_repositories_keep_'
      'following', () async {
    final Random random = seededRandom(90605);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);
      final NodeBackedWorkflowRepository sibling = buildWorkflowRepositoryOver(
        transport: rig.transport,
        workspaces: rig.workspaces,
      );
      await rig.repository.load();
      await sibling.load();

      rig.repository.dispose();
      await _switchToRandomWorkspace(random, rig);

      _expectListingMatchesCurrentWorkspace(sibling, rig);
      sibling.dispose();
    }
  });

  test('${_typePrefix}_dispose_property_right_after_construction_sends_'
      'nothing', () async {
    final Random random = seededRandom(90606);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);

      rig.repository.dispose();
      await _switchToRandomWorkspace(random, rig);

      expect(rig.transport.exchanges, isEmpty);
      expect(rig.repository.listWorkflows(), isEmpty);
    }
  });

  test('${_typePrefix}_load_after_workspace_change_property_listing_follows_'
      'every_chosen_workspace', () async {
    final Random random = seededRandom(90607);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);
      await rig.repository.load();
      final int switchCount = 1 + random.nextInt(_longestSwitchRun);

      for (int step = 0; step < switchCount; step += 1) {
        await _switchToRandomWorkspace(random, rig);

        _expectListingMatchesCurrentWorkspace(rig.repository, rig);
      }
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_load_after_workspace_change_property_a_burst_with_'
      'late_replies_ends_on_the_last_workspace', () async {
    final Random random = seededRandom(90608);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);
      final OutOfOrderReplyTransport transport = OutOfOrderReplyTransport(
        answer: rig.simulated.answer,
        random: random,
      );
      final NodeBackedWorkflowRepository repository =
          buildWorkflowRepositoryOver(
            transport: transport,
            workspaces: rig.workspaces,
          );
      await repository.load();
      transport.isHoldingReplies = true;
      final int switchCount = 1 + random.nextInt(_longestSwitchRun);

      for (int step = 0; step < switchCount; step += 1) {
        await rig.workspaces.repository.switchWorkspace(
          pickOne(random, rig.workspaceIds),
        );
      }
      await releaseEveryReplyInRandomOrder(transport);
      await pumpEventQueue();

      _expectListingMatchesCurrentWorkspace(repository, rig);
      repository.dispose();
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_load_after_workspace_change_property_listeners_hear_'
      'the_new_listing', () async {
    final Random random = seededRandom(90609);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);
      await rig.repository.load();
      final _ListingRecorder recorder = _ListingRecorder(rig.repository);
      rig.repository.addListener(recorder.record);

      await _switchToRandomWorkspace(random, rig);

      expect(recorder.heardListings, isNotEmpty);
      expect(
        recorder.heardListings.last,
        predictListedWorkflowIds(rig.simulated, currentRigWorkspaceId(rig)),
      );
      rig.repository.dispose();
    }
  });
}
