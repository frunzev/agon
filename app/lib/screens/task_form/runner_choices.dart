import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/runner_target_text.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const String _anyFreeRunnerLabel = 'Any free runner';
const String _offlineSuffix = ', offline';
const String _pausedSuffix = ', paused';

String _describeTargetLabel(RunnerTarget target, DeviceNames deviceNames) {
  if (target is AnyFreeRunner) {
    return _anyFreeRunnerLabel;
  }
  final List<TextSegment> segments = describeRunnerTarget(target, deviceNames);

  return segments.map((TextSegment segment) => segment.text).join();
}

String _describeMissingTargetLabel(
  RunnerTarget target,
  DeviceNames deviceNames,
) {
  final String label = _describeTargetLabel(target, deviceNames);
  if (target is SpecificRunner) {
    return '$label$_offlineSuffix';
  }
  return label;
}

List<SelectOption<RunnerTarget>> includeRunnerTarget({
  required List<SelectOption<RunnerTarget>> options,
  required RunnerTarget target,
  required DeviceNames deviceNames,
}) {
  for (final SelectOption<RunnerTarget> option in options) {
    if (option.value == target) {
      return options;
    }
  }

  return <SelectOption<RunnerTarget>>[
    ...options,
    SelectOption<RunnerTarget>(
      value: target,
      label: _describeMissingTargetLabel(target, deviceNames),
    ),
  ];
}

SelectOption<RunnerTarget> _buildOnlineRunnerOption(
  Runner runner,
  DeviceNames deviceNames,
) {
  final RunnerTarget target = SpecificRunner(runner.deviceId);
  final String label = _describeTargetLabel(target, deviceNames);
  if (runner.acceptingNewRuns) {
    return SelectOption<RunnerTarget>(value: target, label: label);
  }
  return SelectOption<RunnerTarget>(
    value: target,
    label: '$label$_pausedSuffix',
  );
}

List<SelectOption<RunnerTarget>> buildRunnerOptions({
  required List<Runner> runners,
  required DeviceNames deviceNames,
  required RunnerTarget chosenTarget,
}) {
  final List<SelectOption<RunnerTarget>> onlineOptions =
      <SelectOption<RunnerTarget>>[
        const SelectOption<RunnerTarget>(
          value: AnyFreeRunner(),
          label: _anyFreeRunnerLabel,
        ),
        for (final Runner runner in runners)
          if (runner.online) _buildOnlineRunnerOption(runner, deviceNames),
      ];

  return includeRunnerTarget(
    options: onlineOptions,
    target: chosenTarget,
    deviceNames: deviceNames,
  );
}
