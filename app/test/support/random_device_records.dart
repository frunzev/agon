import 'dart:math';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../bridge/support/hostile_texts.dart';
import '../bridge/support/node_json_primitives.dart';
import '../bridge/support/random_moments.dart';
import 'random_inputs.dart';
import 'sample_scopes.dart';

const int _largestDeviceRecordCount = 8;

Device randomDeviceRecord(Random random, {required DeviceId? approvedBy}) {
  return Device(
    id: DeviceId(randomDeviceIdText(random)),
    name: randomHostileText(random),
    role: pickOne(random, DeviceRole.values),
    kind: pickOne(random, DeviceKind.values),
    keyKind: pickOne(random, HardwareKeyKind.values),
    signingPublicKey: const <int>[],
    sealingPublicKey: const <int>[],
    workspaces: pickSome(random, sampleWorkspaceIds),
    pairedAt: randomPreciseMoment(random),
    approvedBy: approvedBy,
    lastSeen: randomPreciseMoment(random),
    revoked: random.nextBool(),
  );
}

List<Device> randomDeviceRecords(Random random) {
  final int count = random.nextInt(_largestDeviceRecordCount + 1);
  final List<Device> devices = <Device>[];

  for (int index = 0; index < count; index += 1) {
    final bool hasNoApprover = devices.isEmpty || random.nextBool();
    final DeviceId? approvedBy = hasNoApprover
        ? null
        : pickOne(random, devices).id;
    devices.add(randomDeviceRecord(random, approvedBy: approvedBy));
  }

  return devices;
}
