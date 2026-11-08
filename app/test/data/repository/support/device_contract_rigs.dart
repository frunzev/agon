import 'dart:math';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../screens/support/planned_refusal.dart';
import '../../../screens/support/refusing_place_repositories.dart';
import '../../../support/random_inputs.dart';
import '../../node_backed/support/device_repository_rig.dart';
import '../../node_backed/support/simulated_device_node.dart';
import 'contract_step_failures.dart';
import 'rust_local_folder_model.dart';

const List<String> _peerProblems = <String>[
  'the published address cannot be reached',
  'no address is published',
];
const int _largestMissingNumber = 1 << 30;
const String _workspaceSeparator = '|';

const int _longestChangeSequence = 8;
typedef NamedDeviceRepository = ({String name, DeviceRepository repository});

typedef DeviceProjection = ({String id, bool revoked, String workspaces});

typedef DeviceContractWorld = ({
  List<NamedDeviceRepository> implementations,
  SimulatedDeviceNode node,
});

Future<DeviceContractWorld> buildEveryDeviceRepository(
  Random random, {
  required Set<String> gitlessFolderPaths,
}) async {
  final DeviceRig rig = buildDeviceRig(random);
  rig.node.peerProblem = random.nextBool()
      ? null
      : pickOne(random, _peerProblems);
  final RustLocalFolderModel folders = RustLocalFolderModel(
    deviceId: rigThisDeviceId,
    gitlessFolderPaths: gitlessFolderPaths,
  );
  final NodeBackedDeviceRepository nodeBacked = NodeBackedDeviceRepository(
    channel: NodeCommandChannel(
      transport: ScriptedNodeTransport(
        answer: (String inputJson) =>
            folders.answer(inputJson) ?? rig.node.answer(inputJson),
      ),
    ),
  );
  await nodeBacked.load();

  final List<NamedDeviceRepository> implementations = <NamedDeviceRepository>[
    (
      name: 'fake',
      repository: _buildFakeDevices(nodeBacked, rig, gitlessFolderPaths),
    ),
    (name: 'node backed', repository: nodeBacked),
    (
      name: 'refusing double',
      repository: RefusingDeviceRepository(
        stored: _buildFakeDevices(nodeBacked, rig, gitlessFolderPaths),
        refusal: PlannedRefusal(),
      ),
    ),
  ];
  return (implementations: implementations, node: rig.node);
}

FakeDeviceRepository _buildFakeDevices(
  NodeBackedDeviceRepository nodeBacked,
  DeviceRig rig,
  Set<String> gitlessFolderPaths,
) {
  return FakeDeviceRepository(
    devices: nodeBacked.listDevices(),
    currentDeviceId: const DeviceId(rigThisDeviceId),
    peerAddressProblem: rig.node.peerProblem,
    gitlessFolderPaths: gitlessFolderPaths,
  );
}

List<DeviceProjection> projectDevices(List<Device> devices) {
  final List<DeviceProjection> projections = <DeviceProjection>[];
  for (final Device device in devices) {
    projections.add(projectDevice(device));
  }
  return projections;
}

DeviceProjection projectDevice(Device device) {
  return (
    id: device.id.value,
    revoked: device.revoked,
    workspaces: <String>[
      for (final WorkspaceId workspaceId in device.workspaces)
        workspaceId.value,
    ].join(_workspaceSeparator),
  );
}

DeviceId pickDeviceId(Random random, DeviceRepository repository) {
  final List<Device> devices = repository.listDevices();
  if (random.nextInt(5) == 0) {
    return DeviceId('missing-device-${random.nextInt(_largestMissingNumber)}');
  }
  return pickOne(random, devices).id;
}

WorkspaceId pickWorkspaceId(Random random, DeviceRepository repository) {
  final List<WorkspaceId> known = <WorkspaceId>[
    for (final Device device in repository.listDevices()) ...device.workspaces,
  ];
  if (known.isEmpty || random.nextInt(4) == 0) {
    return WorkspaceId('fresh-workspace-${random.nextInt(4)}');
  }
  return pickOne(random, known);
}

enum MembershipChange { revoke, add, remove }

typedef MembershipOutcome = ({String name, Object? failure, Device? changed});

Future<List<MembershipOutcome>> changeMembershipOnEvery(
  List<NamedDeviceRepository> implementations, {
  required MembershipChange change,
  required DeviceId deviceId,
  required WorkspaceId workspaceId,
}) async {
  final List<MembershipOutcome> outcomes = <MembershipOutcome>[];
  for (final NamedDeviceRepository implementation in implementations) {
    Device? changed;
    final Object? failure = await findStepFailure(() async {
      changed = await _changeMembership(
        implementation.repository,
        change: change,
        deviceId: deviceId,
        workspaceId: workspaceId,
      );
    });
    outcomes.add((
      name: implementation.name,
      failure: failure,
      changed: changed,
    ));
  }
  return outcomes;
}

Future<Device> _changeMembership(
  DeviceRepository repository, {
  required MembershipChange change,
  required DeviceId deviceId,
  required WorkspaceId workspaceId,
}) {
  return switch (change) {
    MembershipChange.revoke => repository.revokeDevice(deviceId),
    MembershipChange.add => repository.addDeviceToWorkspace(
      deviceId,
      workspaceId,
    ),
    MembershipChange.remove => repository.removeDeviceFromWorkspace(
      deviceId,
      workspaceId,
    ),
  };
}

Future<List<MembershipOutcome>> changeRandomlyOnEvery(
  Random random,
  List<NamedDeviceRepository> implementations,
) {
  final DeviceRepository first = implementations.first.repository;
  return changeMembershipOnEvery(
    implementations,
    change: pickOne(random, MembershipChange.values),
    deviceId: pickDeviceId(random, first),
    workspaceId: pickWorkspaceId(random, first),
  );
}

Future<DeviceContractWorld> buildDeviceWorldAfterRandomChanges(
  Random random,
) async {
  final DeviceContractWorld world = await buildEveryDeviceRepository(
    random,
    gitlessFolderPaths: const <String>{},
  );
  final int stepCount = random.nextInt(_longestChangeSequence);
  for (int step = 0; step < stepCount; step += 1) {
    await changeRandomlyOnEvery(random, world.implementations);
  }
  return world;
}
