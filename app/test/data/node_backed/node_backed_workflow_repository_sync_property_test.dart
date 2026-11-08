import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/support/scripted_node_transport.dart';
import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import 'support/out_of_order_replies.dart';
import 'support/simulated_catalog_node.dart';
import 'support/simulated_workflow_node.dart';
import 'support/workflow_workspace_rig.dart';

const String _typePrefix = 'test_node_backed_workflow_repository';
const String _listCommand = 'list_workflows';
const String _workspaceField = 'workspace_id';
const int _iterations = 30;
const int _largestCatalogWorkspaceCount = 3;
const int _largestWorkflowCount = 5;
const int _longestAnnouncementRun = 5;
const Duration _workspaceRetryInterval = Duration(seconds: 30);
const node.AreaChanged _workflowsChanged = node.AreaChanged(
  area: node.ChangeArea.workflows,
);

final class _NotificationTally {
  int count = 0;

  void record() {
    count += 1;
  }
}

void _changeTheNodeElsewhere(Random random, WorkflowWorkspaceRig rig) {
  final List<Map<String, Object?>> views = rig.simulated.views;
  if (views.isNotEmpty && random.nextBool()) {
    views.removeAt(random.nextInt(views.length));
    return;
  }
  seedWorkflowAvailableOver(random, rig.simulated, rig.workspaceIds);
}

List<node.ChangeTopic> _listTopicsOutsideWorkflows(Random random) {
  return <node.ChangeTopic>[
    for (final node.ChangeArea area in node.ChangeArea.values)
      if (area != node.ChangeArea.workflows) node.AreaChanged(area: area),
    node.RunChanged(runId: RunId('run-${randomText(random)}')),
  ];
}

void _expectListingMatchesCurrentWorkspace(WorkflowWorkspaceRig rig) {
  expect(
    listShownWorkflowIds(rig.repository),
    predictListedWorkflowIds(rig.simulated, currentRigWorkspaceId(rig)),
  );
}

void main() {
  test('${_typePrefix}_load_property_each_accepted_load_notifies_once_and_'
      'repeats_the_same_listing', () async {
    final Random random = seededRandom(90801);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);
      final _NotificationTally tally = _NotificationTally();
      rig.repository.addListener(tally.record);

      await rig.repository.load();
      final List<String> first = listShownWorkflowIds(rig.repository);
      await rig.repository.load();

      expect(listShownWorkflowIds(rig.repository), first);
      expect(tally.count, 2);
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_load_property_a_refused_load_throws_and_keeps_the_'
      'listing', () async {
    final Random random = seededRandom(90802);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);
      await rig.repository.load();
      final List<String> before = listShownWorkflowIds(rig.repository);
      final _NotificationTally tally = _NotificationTally();
      rig.repository.addListener(tally.record);
      rig.simulated.failingCommands.add(_listCommand);

      await expectLater(rig.repository.load(), throwsStateError);

      expect(listShownWorkflowIds(rig.repository), before);
      expect(tally.count, 0);
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_apply_change_property_workflow_changes_reload_what_'
      'the_node_now_holds', () async {
    final Random random = seededRandom(90803);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);
      await rig.repository.load();
      _changeTheNodeElsewhere(random, rig);

      await rig.repository.applyChange(_workflowsChanged);

      _expectListingMatchesCurrentWorkspace(rig);
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_apply_change_property_other_topics_ask_nothing_and_'
      'stay_silent', () async {
    final Random random = seededRandom(90804);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);
      await rig.repository.load();
      final int exchangesBefore = rig.transport.exchanges.length;
      final List<String> before = listShownWorkflowIds(rig.repository);
      final _NotificationTally tally = _NotificationTally();
      rig.repository.addListener(tally.record);
      _changeTheNodeElsewhere(random, rig);

      for (final node.ChangeTopic topic in _listTopicsOutsideWorkflows(
        random,
      )) {
        await rig.repository.applyChange(topic);
      }

      expect(rig.transport.exchanges.length, exchangesBefore);
      expect(listShownWorkflowIds(rig.repository), before);
      expect(tally.count, 0);
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_apply_change_property_overlapping_announcements_end_'
      'on_the_newest_node_state', () async {
    final Random random = seededRandom(90805);
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
      final PendingRaceWork pending = PendingRaceWork();
      final int announcementCount =
          1 + random.nextInt(_longestAnnouncementRun);

      for (int step = 0; step < announcementCount; step += 1) {
        _changeTheNodeElsewhere(random, rig);
        pending.start(repository.applyChange(_workflowsChanged));
        if (random.nextBool()) {
          transport.releaseRandomReply();
        }
        await pumpEventQueue();
      }
      await releaseEveryReplyInRandomOrder(transport);
      await pending.finish();
      await releaseEveryReplyInRandomOrder(transport);

      expect(
        listShownWorkflowIds(repository),
        predictListedWorkflowIds(rig.simulated, currentRigWorkspaceId(rig)),
      );
      repository.dispose();
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_load_views_property_asks_only_for_the_current_'
      'workspace', () async {
    final Random random = seededRandom(90806);
    for (int i = 0; i < _iterations; i += 1) {
      final WorkflowWorkspaceRig rig = openWorkflowWorkspaceRig(random);
      await rig.workspaces.repository.switchWorkspace(
        pickOne(random, rig.workspaceIds),
      );
      await pumpEventQueue();

      await rig.repository.load();

      final RecordedExchange last = rig.transport.exchanges.last;
      final Map<String, Object?> command =
          jsonDecode(last.inputJson) as Map<String, Object?>;
      expect(command[_workspaceField], currentRigWorkspaceId(rig).value);
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_load_views_property_no_workspace_yet_lists_nothing_'
      'and_asks_nothing', () async {
    final Random random = seededRandom(90807);
    for (int i = 0; i < _iterations; i += 1) {
      final _CatalogRig rig = _openCatalogRig(random);

      await rig.repository.load();

      expect(rig.repository.listWorkflows(), isEmpty);
      expect(rig.workflowTransport.exchanges, isEmpty);
      rig.repository.dispose();
    }
  });

  test('${_typePrefix}_load_views_property_workspaces_arriving_later_fill_'
      'the_listing', () async {
    final Random random = seededRandom(90808);
    for (int i = 0; i < _iterations; i += 1) {
      final _CatalogRig rig = _openCatalogRig(random);
      await rig.repository.load();

      await rig.workspaces.load();
      await pumpEventQueue();

      expect(
        listShownWorkflowIds(rig.repository),
        predictListedWorkflowIds(
          rig.simulated,
          rig.workspaces.currentWorkspace().id,
        ),
      );
      rig.repository.dispose();
    }
  });
}

typedef _CatalogRig = ({
  SimulatedWorkflowNode simulated,
  ScriptedNodeTransport workflowTransport,
  NodeBackedWorkspaceRepository workspaces,
  NodeBackedWorkflowRepository repository,
});

_CatalogRig _openCatalogRig(Random random) {
  final SimulatedCatalogNode catalog = SimulatedCatalogNode(hasAccount: true);
  final int workspaceCount = 1 + random.nextInt(_largestCatalogWorkspaceCount);
  final List<WorkspaceId> workspaceIds = <WorkspaceId>[
    for (int index = 0; index < workspaceCount; index += 1)
      WorkspaceId(catalog.addWorkspace('place-$index')['id']! as String),
  ];
  final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
    pollsBeforeDraftIsDone: 0,
  );
  final int workflowCount = random.nextInt(_largestWorkflowCount + 1);
  for (int index = 0; index < workflowCount; index += 1) {
    seedWorkflowAvailableOver(random, simulated, workspaceIds);
  }
  final NodeBackedWorkspaceRepository workspaces =
      NodeBackedWorkspaceRepository(
        channel: catalog.channel,
        clock: FixedClock(DateTime.utc(2026, 11, 7)),
        retryInterval: _workspaceRetryInterval,
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  final ScriptedNodeTransport workflowTransport = ScriptedNodeTransport(
    answer: simulated.answer,
  );
  final NodeBackedWorkflowRepository repository = NodeBackedWorkflowRepository(
    channel: NodeCommandChannel(transport: workflowTransport),
    workspaceRepository: workspaces,
    draftPollInterval: Duration.zero,
  );
  return (
    simulated: simulated,
    workflowTransport: workflowTransport,
    workspaces: workspaces,
    repository: repository,
  );
}
