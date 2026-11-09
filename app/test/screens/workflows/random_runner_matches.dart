import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';

const List<String> runnerLabelPool = <String>['gpu', 'mac', 'linux', 'arm'];
const int runnerDeviceCount = 4;
const int _largestRunnerCount = 6;
const int _runnerSlots = 2;

DeviceId runnerDeviceAt(int index) => DeviceId('runner-device-$index');

Runner buildMatchRunner({
  required DeviceId deviceId,
  required List<String> labels,
  required bool online,
}) {
  return Runner(
    deviceId: deviceId,
    labels: labels,
    slotsTotal: _runnerSlots,
    slotsBusy: 0,
    link: RunnerLink.direct,
    online: online,
    acceptingNewRuns: true,
    offers: AgentPlace.values,
    allowedHosts: const <String>[],
  );
}

List<String> randomRunnerLabels(Random random) {
  return <String>[
    for (final String label in runnerLabelPool)
      if (random.nextBool()) label,
  ];
}

List<Runner> randomMatchRunners(Random random) {
  final int count = random.nextInt(_largestRunnerCount + 1);
  return <Runner>[
    for (int index = 0; index < count; index += 1)
      buildMatchRunner(
        deviceId: runnerDeviceAt(random.nextInt(runnerDeviceCount)),
        labels: randomRunnerLabels(random),
        online: random.nextBool(),
      ),
  ];
}

RunnerTarget randomMatchTarget(Random random) {
  return pickOne<RunnerTarget>(random, <RunnerTarget>[
    const AnyFreeRunner(),
    SpecificRunner(runnerDeviceAt(random.nextInt(runnerDeviceCount))),
    RunnerWithLabels(randomRunnerLabels(random)),
  ]);
}

bool _isMatch(RunnerTarget target, Runner runner) {
  switch (target) {
    case AnyFreeRunner():
      return true;
    case SpecificRunner():
      return runner.deviceId == target.deviceId;
    case RunnerWithLabels():
      return target.labels.every(runner.labels.contains);
  }
}

int countOnlineMatches(RunnerTarget target, List<Runner> runners) {
  int count = 0;
  for (final Runner runner in runners) {
    if (runner.online && _isMatch(target, runner)) {
      count += 1;
    }
  }
  return count;
}
