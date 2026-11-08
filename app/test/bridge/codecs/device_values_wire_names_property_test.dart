import 'package:agent_orchestration/bridge/codecs/device_values.dart';

import '../support/node_wire_names.dart';
import '../support/wire_name_checks.dart';

const int _firstSeed = 50201;
const int _seedsPerFamily = 3;

const List<WireNameFamily> _families = <WireNameFamily>[
  WireNameFamily(
    typeName: 'device_role',
    choices: DeviceRole.values,
    nodeNames: nodeDeviceRoles,
    decode: DeviceRole.decode,
  ),
  WireNameFamily(
    typeName: 'device_kind',
    choices: DeviceKind.values,
    nodeNames: nodeDeviceKinds,
    decode: DeviceKind.decode,
  ),
  WireNameFamily(
    typeName: 'hardware_key_kind',
    choices: HardwareKeyKind.values,
    nodeNames: nodeHardwareKeyKinds,
    decode: HardwareKeyKind.decode,
  ),
  WireNameFamily(
    typeName: 'runner_link',
    choices: RunnerLink.values,
    nodeNames: nodeRunnerLinks,
    decode: RunnerLink.decode,
  ),
];

void main() {
  for (int index = 0; index < _families.length; index += 1) {
    final WireNameFamily family = _families[index];
    final int seed = _firstSeed + index * _seedsPerFamily;

    testWireNameDecodeProperties(family, seed);
  }
}
