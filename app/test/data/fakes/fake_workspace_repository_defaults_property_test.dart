import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import '../node_backed/support/simulated_catalog_node.dart';
import '../rules/support/schedule_scope_run_tables.dart';
import 'support/workspace_inputs.dart';

const int _largestSeededCount = 3;
const Duration _retryInterval = Duration(seconds: 30);

typedef _Twins = ({
  FakeWorkspaceRepository fake,
  NodeBackedWorkspaceRepository nodeBacked,
});

String _randomValidName(Random random) => 'team-${random.nextInt(1000)}';

Future<_Twins> _buildTwins(Random random) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final int seededCount = 1 + random.nextInt(_largestSeededCount);
  for (int i = 0; i < seededCount; i += 1) {
    simulated.addWorkspace('seeded-$i');
  }
  final NodeBackedWorkspaceRepository nodeBacked =
      NodeBackedWorkspaceRepository(
        channel: simulated.channel,
        clock: FixedClock(galleryNow),
        retryInterval: _retryInterval,
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  await nodeBacked.load();
  final FakeWorkspaceRepository fake = FakeWorkspaceRepository(
    workspaces: nodeBacked.listWorkspaces(),
    currentWorkspaceId: nodeBacked.currentWorkspace().id,
    appServerStatus: nodeBacked.findAppServerStatus(),
    appServerGroup: nodeBacked.findAppServerGroup(),
    currentDeviceId: const DeviceId(simulatedDeviceId),
    clock: FixedClock(galleryNow),
  );
  return (fake: fake, nodeBacked: nodeBacked);
}

void main() {
  final List<String> rustDefaults = readSharedDefaultProtectedPatterns();

  test('test_create_workspace_property_new_workspaces_get_the_rust_'
      'defaults', () async {
    final Random random = seededRandom(89401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkspaceRepository repository = seedRandomWorkspaces(random)
          .repository;

      final Workspace created = await repository.createWorkspace(
        name: _randomValidName(random),
      );

      expect(created.protectedFiles, orderedEquals(rustDefaults));
    }
  });

  test(
    'test_create_workspace_property_defaults_agree_with_the_node',
    () async {
      final Random random = seededRandom(89402);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _Twins twins = await _buildTwins(random);
        final String name = _randomValidName(random);

        final Workspace fromFake = await twins.fake.createWorkspace(
          name: name,
        );
        final Workspace fromNode = await twins.nodeBacked.createWorkspace(
          name: name,
        );

        expect(
          fromFake.protectedFiles,
          orderedEquals(fromNode.protectedFiles),
        );
      }
    },
  );

  test('test_reset_protected_files_property_restores_the_rust_'
      'defaults', () async {
    final Random random = seededRandom(89403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final WorkspaceId workspaceId = pickOne(random, seeded.workspaces).id;
      await seeded.repository.saveProtectedFiles(
        workspaceId: workspaceId,
        patterns: randomPatterns(random),
      );

      final Workspace reset = await seeded.repository.resetProtectedFiles(
        workspaceId,
      );

      expect(reset.protectedFiles, orderedEquals(rustDefaults));
    }
  });

  test('test_reset_protected_files_property_agrees_with_the_node', () async {
    final Random random = seededRandom(89404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _Twins twins = await _buildTwins(random);
      final WorkspaceId workspaceId = pickOne(
        random,
        twins.nodeBacked.listWorkspaces(),
      ).id;
      final List<String> patterns = randomPatterns(random);
      await twins.fake.saveProtectedFiles(
        workspaceId: workspaceId,
        patterns: patterns,
      );
      await twins.nodeBacked.saveProtectedFiles(
        workspaceId: workspaceId,
        patterns: patterns,
      );

      final Workspace fromFake = await twins.fake.resetProtectedFiles(
        workspaceId,
      );
      final Workspace fromNode = await twins.nodeBacked.resetProtectedFiles(
        workspaceId,
      );

      expect(fromFake.protectedFiles, orderedEquals(fromNode.protectedFiles));
    }
  });

  test('test_reset_protected_files_property_touches_only_one_'
      'workspace', () async {
    final Random random = seededRandom(89405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final List<Workspace> before = seeded.repository.listWorkspaces();
      final WorkspaceId workspaceId = pickOne(random, before).id;

      final Workspace reset = await seeded.repository.resetProtectedFiles(
        workspaceId,
      );

      expectOtherWorkspacesUntouched(seeded.repository, before, reset);
    }
  });
}
