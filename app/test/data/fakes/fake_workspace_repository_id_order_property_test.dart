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
import 'support/workspace_inputs.dart';

const int _largestWorkspaceCount = 6;
const int _identifierSpan = 1000;
const int _largestCreationCount = 4;
const Duration _retryInterval = Duration(seconds: 30);

List<Workspace> _randomUnorderedWorkspaces(Random random) {
  final int count = 2 + random.nextInt(_largestWorkspaceCount - 1);
  final Set<String> identifiers = <String>{};
  while (identifiers.length < count) {
    identifiers.add('w-${random.nextInt(_identifierSpan)}');
  }
  final List<Workspace> workspaces = <Workspace>[];
  int index = 0;
  for (final String identifier in identifiers) {
    final Workspace sample = buildSampleWorkspace(random, index);
    workspaces.add(
      Workspace(
        id: WorkspaceId(identifier),
        name: sample.name,
        appServerAddress: sample.appServerAddress,
        protectedFiles: sample.protectedFiles,
        approvalPolicy: sample.approvalPolicy,
      ),
    );
    index += 1;
  }
  workspaces.shuffle(random);
  return workspaces;
}

List<String> _listIdentifiers(List<Workspace> workspaces) {
  return <String>[
    for (final Workspace workspace in workspaces) workspace.id.value,
  ];
}

List<String> _sortIdentifiers(List<Workspace> workspaces) {
  final List<String> identifiers = _listIdentifiers(workspaces);
  identifiers.sort();
  return identifiers;
}

FakeWorkspaceRepository _buildFake(Random random, List<Workspace> seeded) {
  return buildWorkspaceRepository(
    workspaces: seeded,
    currentWorkspaceId: pickOne(random, seeded).id,
    appServerGroup: randomAppServerGroup(random),
  );
}

Future<NodeBackedWorkspaceRepository> _buildNodeBacked(
  List<Workspace> seeded,
) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  for (final String identifier in _sortIdentifiers(seeded)) {
    simulated.addWorkspace('name-$identifier')['id'] = identifier;
  }
  final NodeBackedWorkspaceRepository nodeBacked =
      NodeBackedWorkspaceRepository(
        channel: simulated.channel,
        clock: FixedClock(galleryNow),
        retryInterval: _retryInterval,
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  await nodeBacked.load();
  return nodeBacked;
}

void main() {
  test('test_fake_workspace_repository_new_property_lists_workspaces_in_'
      'id_order', () {
    final Random random = seededRandom(89501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workspace> seeded = _randomUnorderedWorkspaces(random);

      final FakeWorkspaceRepository fake = _buildFake(random, seeded);

      final List<String> listed = _listIdentifiers(fake.listWorkspaces());
      expect(listed, orderedEquals(_sortIdentifiers(seeded)));
    }
  });

  test('test_fake_workspace_repository_new_property_keeps_every_seeded_'
      'workspace', () {
    final Random random = seededRandom(89502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workspace> seeded = _randomUnorderedWorkspaces(random);

      final FakeWorkspaceRepository fake = _buildFake(random, seeded);

      final List<Workspace> listed = fake.listWorkspaces();
      expect(listed, hasLength(seeded.length));
      for (final Workspace workspace in seeded) {
        expect(listed, contains(same(workspace)));
      }
    }
  });

  test('test_fake_workspace_repository_new_property_keeps_the_chosen_'
      'current_workspace', () {
    final Random random = seededRandom(89503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workspace> seeded = _randomUnorderedWorkspaces(random);
      final Workspace chosen = pickOne(random, seeded);

      final FakeWorkspaceRepository fake = buildWorkspaceRepository(
        workspaces: seeded,
        currentWorkspaceId: chosen.id,
        appServerGroup: randomAppServerGroup(random),
      );

      expect(fake.currentWorkspace(), same(chosen));
    }
  });

  test('test_create_workspace_property_created_workspaces_land_in_id_'
      'order', () async {
    final Random random = seededRandom(89504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkspaceRepository fake = _buildFake(
        random,
        _randomUnorderedWorkspaces(random),
      );
      final int creationCount = 1 + random.nextInt(_largestCreationCount);

      for (int created = 0; created < creationCount; created += 1) {
        await fake.createWorkspace(name: 'team-$created');
      }

      final List<Workspace> listed = fake.listWorkspaces();
      expect(
        _listIdentifiers(listed),
        orderedEquals(_sortIdentifiers(listed)),
      );
    }
  });

  test(
    'test_delete_workspace_property_current_moves_to_the_first_id',
    () async {
      final Random random = seededRandom(89505);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<Workspace> seeded = _randomUnorderedWorkspaces(random);
        final Workspace current = pickOne(random, seeded);
        final FakeWorkspaceRepository fake = buildWorkspaceRepository(
          workspaces: seeded,
          currentWorkspaceId: current.id,
          appServerGroup: randomAppServerGroup(random),
        );

        await fake.deleteWorkspace(current.id);

        final List<Workspace> remaining = <Workspace>[
          for (final Workspace workspace in seeded)
            if (workspace.id != current.id) workspace,
        ];
        final String firstIdentifier = _sortIdentifiers(remaining).first;
        expect(fake.currentWorkspace().id.value, firstIdentifier);
      }
    },
  );

  test('test_delete_workspace_property_agrees_with_the_node_on_the_next_'
      'current', () async {
    final Random random = seededRandom(89506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workspace> seeded = _randomUnorderedWorkspaces(random);
      final NodeBackedWorkspaceRepository nodeBacked = await _buildNodeBacked(
        seeded,
      );
      final List<Workspace> shuffled = List<Workspace>.of(
        nodeBacked.listWorkspaces(),
      );
      shuffled.shuffle(random);
      final Workspace current = pickOne(random, shuffled);
      await nodeBacked.switchWorkspace(current.id);
      final FakeWorkspaceRepository fake = buildWorkspaceRepository(
        workspaces: shuffled,
        currentWorkspaceId: current.id,
        appServerGroup: nodeBacked.findAppServerGroup(),
      );

      await fake.deleteWorkspace(current.id);
      await nodeBacked.deleteWorkspace(current.id);

      expect(fake.currentWorkspace().id, nodeBacked.currentWorkspace().id);
      expect(
        _listIdentifiers(fake.listWorkspaces()),
        orderedEquals(_listIdentifiers(nodeBacked.listWorkspaces())),
      );
    }
  });
}
