import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';

Runner? findDeviceRunner({
  required List<Runner> runners,
  required DeviceId deviceId,
}) {
  for (final Runner runner in runners) {
    if (runner.deviceId == deviceId) {
      return runner;
    }
  }
  return null;
}
