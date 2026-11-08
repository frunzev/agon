import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/workspace_repository_rig.dart';

const int _iterations = 40;
const int _largestStepCount = 8;
const String _workspaceKind = 'workspace';
const node.AreaChanged _workspacesChanged = node.AreaChanged(
  area: node.ChangeArea.workspaces,
);

WorkspaceId _randomUnknownWorkspaceId(Random random) {
  return WorkspaceId('unknown-${randomText(random)}');
}

void main() {
  test('test_current_workspace_property_follows_the_choice_model', () async {
    final Random random = seededRandom(96501);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = await openLoadedWorkspaceRig(random);
      WorkspaceId? chosen;
      final int stepCount = 1 + random.nextInt(_largestStepCount);

      for (int step = 0; step < stepCount; step += 1) {
        if (random.nextBool()) {
          chosen = rig.pickNodeWorkspaceId(random);
          await rig.repository.switchWorkspace(chosen);
        } else if (rig.node.workspaces.length > 1) {
          rig.node.workspaces.removeAt(
            random.nextInt(rig.node.workspaces.length),
          );
          await rig.repository.applyChange(_workspacesChanged);
        } else {
          rig.node.addWorkspace(randomWordPhrase(random));
          await rig.repository.applyChange(_workspacesChanged);
        }

        final List<String> shownIds = rig.listShownWorkspaceIds();
        final String expectedId = shownIds.contains(chosen?.value)
            ? chosen!.value
            : shownIds.first;
        expect(rig.repository.currentWorkspace().id.value, expectedId);
      }
    }
  });

  test('test_current_workspace_property_without_workspaces_says_so', () async {
    final Random random = seededRandom(96502);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = WorkspaceRepositoryRig.open(
        random,
        hasAccount: random.nextBool(),
      );
      rig.node.workspaces.clear();

      await rig.repository.load();

      expect(rig.repository.currentWorkspace, throwsStateError);
    }
  });

  test('test_switch_workspace_property_unknown_ids_change_nothing', () async {
    final Random random = seededRandom(96503);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = await openLoadedWorkspaceRig(random);
      final WorkspaceId currentBefore = rig.repository.currentWorkspace().id;
      final WorkspaceId? storedBefore = rig.choiceStore.chosenWorkspaceId;
      int notifications = 0;
      rig.repository.addListener(() => notifications += 1);

      final Object? problem = await readRepositoryProblem(
        () =>
            rig.repository.switchWorkspace(_randomUnknownWorkspaceId(random)),
      );

      expect(problem, isA<RecordNotFound>());
      expect(rig.repository.currentWorkspace().id, currentBefore);
      expect(rig.choiceStore.chosenWorkspaceId, storedBefore);
      expect(notifications, 0);
    }
  });

  test('test_switch_workspace_property_notifies_once_with_the_listed_'
      'workspace', () async {
    final Random random = seededRandom(96504);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = await openLoadedWorkspaceRig(random);
      final WorkspaceId chosen = rig.pickNodeWorkspaceId(random);
      int notifications = 0;
      rig.repository.addListener(() => notifications += 1);

      final Workspace switched = await rig.repository.switchWorkspace(chosen);

      final Workspace listed = rig.repository.listWorkspaces().firstWhere(
        (Workspace workspace) => workspace.id == chosen,
      );
      expect(notifications, 1);
      expect(identical(switched, listed), isTrue);
    }
  });

  test(
    'test_find_workspace_property_unknown_ids_name_the_workspace',
    () async {
      final Random random = seededRandom(96505);

      for (int i = 0; i < _iterations; i += 1) {
        final WorkspaceRepositoryRig rig = await openLoadedWorkspaceRig(
          random,
        );
        final WorkspaceId unknownId = _randomUnknownWorkspaceId(random);

        final Object? switchProblem = await readRepositoryProblem(
          () => rig.repository.switchWorkspace(unknownId),
        );
        final Object? policyProblem = await readRepositoryProblem(
          () => rig.repository.changeApprovalPolicy(
            workspaceId: unknownId,
            approvalPolicy: pickOne(random, ApprovalPolicy.values),
          ),
        );

        for (final Object? problem in <Object?>[
          switchProblem,
          policyProblem,
        ]) {
          expect(problem, isA<RecordNotFound>());
          expect((problem as RecordNotFound).kind, _workspaceKind);
          expect(problem.identifier, unknownId.value);
        }
      }
    },
  );

  test('test_find_workspace_property_a_workspace_deleted_elsewhere_is_'
      'gone_after_reload', () async {
    final Random random = seededRandom(96506);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = await openLoadedWorkspaceRig(random);
      final WorkspaceId deletedId = rig.pickNodeWorkspaceId(random);
      rig.node.workspaces.removeWhere(
        (Map<String, Object?> workspace) => workspace['id'] == deletedId.value,
      );

      await rig.repository.applyChange(_workspacesChanged);
      final Object? problem = await readRepositoryProblem(
        () => rig.repository.switchWorkspace(deletedId),
      );

      expect(problem, isA<RecordNotFound>());
      expect(rig.listShownWorkspaceIds(), isNot(contains(deletedId.value)));
    }
  });

  test('test_find_workspace_property_an_unknown_policy_change_asks_no_'
      'node', () async {
    final Random random = seededRandom(96507);

    for (int i = 0; i < _iterations; i += 1) {
      final WorkspaceRepositoryRig rig = await openLoadedWorkspaceRig(random);
      final int exchangesBefore = rig.transport.exchanges.length;

      await readRepositoryProblem(
        () => rig.repository.changeApprovalPolicy(
          workspaceId: _randomUnknownWorkspaceId(random),
          approvalPolicy: pickOne(random, ApprovalPolicy.values),
        ),
      );

      expect(rig.transport.exchanges, hasLength(exchangesBefore));
    }
  });
}
