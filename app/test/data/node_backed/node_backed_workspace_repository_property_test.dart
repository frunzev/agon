import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../bridge/support/random_account_json.dart';
import '../../support/random_inputs.dart';
import 'support/workspace_repository_rig.dart';

const int _iterations = 40;
const int _largestLoadCount = 3;
const String _statusCommand = 'status';
const String _listWorkspacesCommand = 'list_workspaces';
const Set<node.ChangeArea> _workspaceAreas = <node.ChangeArea>{
  node.ChangeArea.account,
  node.ChangeArea.workspaces,
  node.ChangeArea.serverGroup,
};

int _countSent(WorkspaceRepositoryRig rig, String commandName) {
  int count = 0;
  for (final String sent in rig.listSentCommandNames()) {
    if (sent == commandName) {
      count += 1;
    }
  }
  return count;
}

void main() {
  test('test_node_backed_workspace_repository_constructor_property_'
      'contacts_nobody_until_load', () async {
    final Random random = seededRandom(96401);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = WorkspaceRepositoryRig.open(
        random,
        hasAccount: random.nextBool(),
      );

      await Future<void>.delayed(Duration.zero);

      expect(rig.transport.exchanges, isEmpty);
      expect(rig.repository.listWorkspaces(), isEmpty);
      expect(rig.repository.currentWorkspace, throwsStateError);
      expect(rig.repository.findAppServerStatus, throwsStateError);
      expect(rig.repository.findAppServerGroup, throwsStateError);
    }
  });

  test('test_node_backed_workspace_repository_constructor_property_status_'
      'uses_the_given_clock_and_interval', () async {
    final Random random = seededRandom(96402);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = WorkspaceRepositoryRig.open(
        random,
        hasAccount: true,
      );
      rig.node.isServerReachable = random.nextBool();

      await rig.repository.load();

      final AppServerStatus status = rig.repository.findAppServerStatus();
      final DateTime? expectedConnection = rig.node.isServerReachable
          ? workspaceRigMoment
          : null;
      expect(status.retryInterval, workspaceRigRetryInterval);
      expect(status.lastConnectedAt, expectedConnection);
    }
  });

  test('test_node_backed_workspace_repository_constructor_property_'
      'switching_saves_to_the_given_store', () async {
    final Random random = seededRandom(96403);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = WorkspaceRepositoryRig.open(
        random,
        hasAccount: true,
      );
      rig.node.addWorkspace(randomWordPhrase(random));
      await rig.repository.load();
      final WorkspaceId chosen = rig.pickNodeWorkspaceId(random);

      await rig.repository.switchWorkspace(chosen);

      expect(rig.choiceStore.chosenWorkspaceId, chosen);
      expect(rig.repository.currentWorkspace().id, chosen);
    }
  });

  test('test_node_backed_workspace_repository_apply_change_property_'
      'reloads_exactly_for_its_areas', () async {
    final Random random = seededRandom(96404);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = WorkspaceRepositoryRig.open(
        random,
        hasAccount: true,
      );
      await rig.repository.load();
      final node.ChangeTopic topic = node.ChangeTopic.fromJson(
        randomChangeTopicJson(random),
      );
      final int statusReadsBefore = _countSent(rig, _statusCommand);

      await rig.repository.applyChange(topic);

      final bool isWorkspaceChange =
          topic is node.AreaChanged && _workspaceAreas.contains(topic.area);
      final int expectedReads = isWorkspaceChange ? 1 : 0;
      final int statusReads = _countSent(rig, _statusCommand);
      expect(statusReads - statusReadsBefore, expectedReads);
    }
  });

  test('test_node_backed_workspace_repository_apply_change_property_a_'
      'reload_mirrors_changes_elsewhere', () async {
    final Random random = seededRandom(96405);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = WorkspaceRepositoryRig.open(
        random,
        hasAccount: true,
      );
      await rig.repository.load();
      rig.node.addWorkspace(randomWordPhrase(random));
      if (rig.node.workspaces.length > 1 && random.nextBool()) {
        rig.node.workspaces.removeAt(0);
      }

      await rig.repository.applyChange(
        node.AreaChanged(area: pickOne(random, _workspaceAreas.toList())),
      );

      expect(rig.listShownWorkspaceIds(), rig.listNodeWorkspaceIds());
    }
  });

  test('test_list_workspaces_property_mirrors_the_node_in_identifier_'
      'order', () async {
    final Random random = seededRandom(96406);

    for (int i = 0; i < _iterations; i += 1) {
      final bool hasAccount = random.nextBool();
      final WorkspaceRepositoryRig rig = WorkspaceRepositoryRig.open(
        random,
        hasAccount: hasAccount,
      );

      await rig.repository.load();

      final List<String> expectedIds = hasAccount
          ? rig.listNodeWorkspaceIds()
          : <String>[];
      expect(rig.listShownWorkspaceIds(), expectedIds);
    }
  });

  test('test_list_workspaces_property_callers_cannot_change_the_'
      'listing', () async {
    final Random random = seededRandom(96407);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = WorkspaceRepositoryRig.open(
        random,
        hasAccount: true,
      );
      await rig.repository.load();
      final List<Workspace> listed = rig.repository.listWorkspaces();
      final List<String> idsBefore = rig.listShownWorkspaceIds();

      expect(listed.clear, throwsUnsupportedError);
      expect(rig.listShownWorkspaceIds(), idsBefore);
    }
  });

  test('test_list_workspaces_property_reads_without_asking_the_'
      'node', () async {
    final Random random = seededRandom(96408);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = WorkspaceRepositoryRig.open(
        random,
        hasAccount: random.nextBool(),
      );
      await rig.repository.load();
      final int exchangesBefore = rig.transport.exchanges.length;

      final List<String> first = rig.listShownWorkspaceIds();
      final List<String> second = rig.listShownWorkspaceIds();

      expect(rig.transport.exchanges, hasLength(exchangesBefore));
      expect(second, first);
    }
  });

  test('test_load_workspaces_property_without_an_account_lists_'
      'nothing_and_asks_nothing', () async {
    final Random random = seededRandom(96409);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = WorkspaceRepositoryRig.open(
        random,
        hasAccount: false,
      );
      rig.node.addWorkspace(randomWordPhrase(random));

      await rig.repository.load();

      expect(_countSent(rig, _listWorkspacesCommand), 0);
      expect(rig.repository.listWorkspaces(), isEmpty);
    }
  });

  test('test_load_workspaces_property_one_listing_per_load_after_the_'
      'status', () async {
    final Random random = seededRandom(96410);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = WorkspaceRepositoryRig.open(
        random,
        hasAccount: true,
      );
      final int loadCount = 1 + random.nextInt(_largestLoadCount);

      for (int load = 0; load < loadCount; load += 1) {
        await rig.repository.load();
      }

      final List<String> expectedCommands = <String>[
        for (int load = 0; load < loadCount; load += 1) ...<String>[
          _statusCommand,
          _listWorkspacesCommand,
        ],
      ];
      expect(rig.listSentCommandNames(), expectedCommands);
    }
  });

  test('test_load_workspaces_property_keeps_every_node_name', () async {
    final Random random = seededRandom(96411);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = WorkspaceRepositoryRig.open(
        random,
        hasAccount: true,
      );

      await rig.repository.load();

      final Map<String, Object?> nodeNames = <String, Object?>{
        for (final Map<String, Object?> workspace in rig.node.workspaces)
          workspace['id']! as String: workspace['name'],
      };
      for (final Workspace workspace in rig.repository.listWorkspaces()) {
        expect(workspace.name, nodeNames[workspace.id.value]);
      }
    }
  });
}
