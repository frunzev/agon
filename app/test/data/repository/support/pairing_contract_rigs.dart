import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';

import '../../../screens/support/planned_refusal.dart';
import '../../../screens/support/refusing_place_repositories.dart';
import '../../../support/recording_pairing_repository.dart';
import '../../fakes/support/pairing_inputs.dart';
import '../../node_backed/support/pairing_repository_harness.dart';
import '../../node_backed/support/simulated_pairing_node.dart';

const int neverJoiningPolls = 1000000;

typedef NamedPairingRepository = ({String name, PairingRepository repository});

typedef PairingContractWorld = ({
  MovableClock clock,
  NodeBackedPairingRepository node,
  List<NamedPairingRepository> implementations,
});

FakePairingRepository buildContractFakePairing({
  required MovableClock clock,
  required PairingSession? session,
  required PairingRequest? request,
}) {
  return FakePairingRepository(
    session: session,
    request: request,
    clock: clock,
    deviceRepository: FakeDeviceRepository(
      devices: galleryDevices,
      currentDeviceId: GalleryDeviceIds.airLaptop,
      peerAddressProblem: null,
      gitlessFolderPaths: const <String>{},
    ),
    joinOutcome: galleryPairingOutcome,
    startedPairingRendezvousProblem: null,
  );
}

PairingContractWorld _buildWorld({
  required MovableClock clock,
  required NodeBackedPairingRepository node,
  required PairingSession? session,
  required PairingRequest? request,
}) {
  return (
    clock: clock,
    node: node,
    implementations: <NamedPairingRepository>[
      (
        name: 'fake',
        repository: buildContractFakePairing(
          clock: clock,
          session: session,
          request: request,
        ),
      ),
      (name: 'node backed', repository: node),
      (
        name: 'refusing double',
        repository: RefusingPairingRepository(
          stored: buildContractFakePairing(
            clock: clock,
            session: session,
            request: request,
          ),
          refusal: PlannedRefusal(),
        ),
      ),
    ],
  );
}

PairingContractWorld buildIdlePairingWorld() {
  final MovableClock clock = MovableClock(pairingStart);
  return _buildWorld(
    clock: clock,
    node: buildPairingRepository(
      buildPairingNode(pollsBeforeJoin: neverJoiningPolls),
      clock,
    ),
    session: null,
    request: null,
  );
}

Future<PairingContractWorld> buildWaitingPairingWorld() async {
  final MovableClock clock = MovableClock(pairingStart);
  final NodeBackedPairingRepository node = buildPairingRepository(
    buildPairingNode(),
    clock,
  );
  await node.startPairing();
  await waitUntil(() => node.findPendingRequest() != null);
  return _buildWorld(
    clock: clock,
    node: node,
    session: liveSessionAt(clock.moment),
    request: node.findPendingRequest(),
  );
}

Future<void> startPairingEverywhere(PairingContractWorld world) async {
  for (final NamedPairingRepository implementation in world.implementations) {
    await implementation.repository.startPairing();
  }
}

void expirePairingCodes(PairingContractWorld world) {
  world.clock.moment = world.clock.moment.add(pairingLifetime);
}

List<NamedPairingRepository> buildEveryAccountPairingRepository() {
  final SimulatedPairingNode simulated = buildPairingNode();
  final MovableClock clock = MovableClock(pairingStart);
  return <NamedPairingRepository>[
    (
      name: 'fake',
      repository: buildContractFakePairing(
        clock: clock,
        session: null,
        request: null,
      ),
    ),
    (
      name: 'node backed',
      repository: NodeBackedPairingRepository(
        channel: simulated.channel,
        clock: clock,
        pollInterval: pairingWaitStep,
        runnerLabels: pairingRunnerLabels,
      ),
    ),
    (
      name: 'refusing double',
      repository: RefusingPairingRepository(
        stored: buildContractFakePairing(
          clock: clock,
          session: null,
          request: null,
        ),
        refusal: PlannedRefusal(),
      ),
    ),
    (
      name: 'recording double',
      repository: RecordingPairingRepository(hostingProblem: null),
    ),
  ];
}

void closePairingWorld(PairingContractWorld world) {
  world.node.dispose();
}
