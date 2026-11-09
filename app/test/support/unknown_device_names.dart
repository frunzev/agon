import 'dart:math';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';

import '../bridge/support/node_json_primitives.dart';
import 'random_device_records.dart';

const String _unknownDevicePrefix = 'unknown-';

typedef UnknownDeviceNames = ({
  DeviceId deviceId,
  String shortName,
  DeviceNames withoutDevice,
  DeviceNames namingShortly,
});

typedef KnownDeviceNames = ({Device device, DeviceNames deviceNames});

UnknownDeviceNames randomUnknownDeviceNames(Random random) {
  final List<Device> otherDevices = randomDeviceRecords(random);
  final DeviceId deviceId = DeviceId(
    '$_unknownDevicePrefix${randomDeviceIdText(random)}',
  );
  final String shortName = shortenIdentifier(deviceId.value);
  final Device template = randomDeviceRecord(random, approvedBy: null);
  final Device shortNamed = Device(
    id: deviceId,
    name: shortName,
    role: template.role,
    kind: template.kind,
    keyKind: template.keyKind,
    signingPublicKey: template.signingPublicKey,
    sealingPublicKey: template.sealingPublicKey,
    workspaces: template.workspaces,
    pairedAt: template.pairedAt,
    approvedBy: template.approvedBy,
    lastSeen: template.lastSeen,
    revoked: template.revoked,
  );
  return (
    deviceId: deviceId,
    shortName: shortName,
    withoutDevice: DeviceNames(otherDevices),
    namingShortly: DeviceNames(<Device>[...otherDevices, shortNamed]),
  );
}

KnownDeviceNames randomKnownDeviceNames(Random random) {
  final List<Device> devices = <Device>[
    randomDeviceRecord(random, approvedBy: null),
    ...randomDeviceRecords(random),
  ];
  final Device device = devices.first;
  final List<Device> uniqueDevices = <Device>[
    device,
    for (final Device other in devices.skip(1))
      if (other.id != device.id) other,
  ];
  return (device: device, deviceNames: DeviceNames(uniqueDevices));
}

Run moveEveryStepTo(Run run, DeviceId runner) {
  final List<RunStep> movedSteps = <RunStep>[
    for (final RunStep step in run.steps)
      RunStep(
        name: step.name,
        agentId: step.agentId,
        runner: runner,
        status: step.status,
        startedAt: step.startedAt,
        finishedAt: step.finishedAt,
        result: step.result,
        outcome: step.outcome,
        loopSource: step.loopSource,
        earlierRounds: step.earlierRounds,
      ),
  ];
  return run.withProgress(
    nextStatus: run.status,
    nextSteps: movedSteps,
    nextFinishedAt: run.finishedAt,
  );
}
