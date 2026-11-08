import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';

const DeviceId membershipThisDeviceId = GalleryDeviceIds.airLaptop;
const WorkspaceId membershipWorkspaceId = GalleryWorkspaceIds.acme;

typedef RunnerMembership = ({
  FakeDeviceRepository devices,
  FakeWorkspaceRepository workspaces,
});

FakeWorkspaceRepository buildMembershipWorkspaces(WorkspaceId currentId) {
  return FakeWorkspaceRepository(
    workspaces: galleryWorkspaces,
    currentWorkspaceId: currentId,
    appServerStatus: galleryAppServerStatus,
    appServerGroup: galleryAppServerGroup,
    currentDeviceId: membershipThisDeviceId,
    clock: FixedClock(galleryNow),
  );
}

Device buildMemberDevice(DeviceId deviceId, List<WorkspaceId> workspaces) {
  final Device template = galleryDevices.first;
  return Device(
    id: deviceId,
    name: 'member-${deviceId.value}',
    role: DeviceRole.runner,
    kind: template.kind,
    keyKind: template.keyKind,
    signingPublicKey: template.signingPublicKey,
    sealingPublicKey: template.sealingPublicKey,
    workspaces: workspaces,
    pairedAt: template.pairedAt,
    approvedBy: membershipThisDeviceId,
    lastSeen: template.lastSeen,
    revoked: false,
  );
}

FakeDeviceRepository buildMembershipDevices(List<Device> otherDevices) {
  final Set<DeviceId> galleryIds = <DeviceId>{
    for (final Device device in galleryDevices) device.id,
  };
  return FakeDeviceRepository(
    devices: <Device>[
      ...galleryDevices,
      for (final Device device in otherDevices)
        if (!galleryIds.contains(device.id)) device,
    ],
    currentDeviceId: membershipThisDeviceId,
    peerAddressProblem: null,
    gitlessFolderPaths: const <String>{},
  );
}

RunnerMembership buildWorkspaceMembersFor(List<Runner> runners) {
  final Map<DeviceId, Device> memberDevices = <DeviceId, Device>{
    for (final Runner runner in runners)
      runner.deviceId: buildMemberDevice(runner.deviceId, const <WorkspaceId>[
        membershipWorkspaceId,
      ]),
  };
  return (
    devices: buildMembershipDevices(memberDevices.values.toList()),
    workspaces: buildMembershipWorkspaces(membershipWorkspaceId),
  );
}

FakeRunnerRepository buildMemberRunnerRepository({
  required List<Runner> runners,
  required List<PlaceOffer>? offers,
  required String? problem,
}) {
  final RunnerMembership membership = buildWorkspaceMembersFor(runners);
  return FakeRunnerRepository(
    runners: runners,
    deviceRepository: membership.devices,
    workspaceRepository: membership.workspaces,
    thisDeviceOffers: offers,
    thisRunnerProblem: problem,
  );
}
