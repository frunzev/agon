import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const List<TextSegment> _anyRunnerSegments = <TextSegment>[
  TextSegment('Any runner'),
];

List<TextSegment> describeRunnerTarget(
  RunnerTarget target,
  DeviceNames deviceNames,
) {
  switch (target) {
    case AnyFreeRunner():
      return _anyRunnerSegments;
    case SpecificRunner():
      return <TextSegment>[
        TextSegment.monospace(deviceNames.describeDevice(target.deviceId)),
      ];
    case RunnerWithLabels():
      if (target.labels.isEmpty) {
        return _anyRunnerSegments;
      }
      return <TextSegment>[
        const TextSegment('Any runner with '),
        TextSegment.monospace(target.labels.join(', ')),
      ];
  }
}
