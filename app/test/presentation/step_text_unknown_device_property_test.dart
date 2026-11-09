import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/step_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../support/random_inputs.dart';
import '../support/sample_records.dart';
import '../support/unknown_device_names.dart';

const int _seedSpan = 1 << 30;

const List<StepStatus> _statusesNamingTheRunner = <StepStatus>[
  StepStatus.running,
  StepStatus.waitingForApproval,
  StepStatus.done,
  StepStatus.failed,
];

final List<RunStep> _templates = <RunStep>[
  for (final Run run in galleryRuns) ...run.steps,
];

RunStep _randomStepOn(Random random, DeviceId runner, StepStatus status) {
  final RunStep template = pickOne(random, _templates);
  return RunStep(
    name: template.name,
    agentId: template.agentId,
    runner: runner,
    status: status,
    startedAt: template.startedAt ?? galleryNow,
    finishedAt: template.finishedAt,
    result: template.result,
    outcome: template.outcome,
    loopSource: template.loopSource,
    earlierRounds: template.earlierRounds,
  );
}

String _describe(Random random, RunStep step, DeviceNames deviceNames) {
  final List<TextSegment> segments = describeStepSubtitle(
    step: step,
    target: randomRunnerTarget(random),
    deviceNames: deviceNames,
    now: galleryNow,
  );
  final StringBuffer text = StringBuffer();
  for (final TextSegment segment in segments) {
    text.write(segment.text);
  }
  return text.toString();
}

void main() {
  test('test_describe_step_subtitle_property_an_unknown_runner_never_'
      'throws', () {
    final Random random = seededRandom(5311301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final StepStatus status = pickOne(random, StepStatus.values);
      final RunStep step = _randomStepOn(random, unknown.deviceId, status);

      expect(
        () => _describe(random, step, unknown.withoutDevice),
        returnsNormally,
      );
    }
  });

  test('test_describe_step_subtitle_property_an_unknown_runner_reads_as_'
      'its_short_identifier', () {
    final Random random = seededRandom(5311302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final StepStatus status = pickOne(random, _statusesNamingTheRunner);
      final RunStep step = _randomStepOn(random, unknown.deviceId, status);
      final int seed = random.nextInt(_seedSpan);

      final String withoutDevice = _describe(
        seededRandom(seed),
        step,
        unknown.withoutDevice,
      );
      final String namingShortly = _describe(
        seededRandom(seed),
        step,
        unknown.namingShortly,
      );

      expect(withoutDevice, namingShortly);
      expect(withoutDevice, startsWith(unknown.shortName));
    }
  });

  test('test_describe_step_subtitle_property_a_known_runner_is_named', () {
    final Random random = seededRandom(5311303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final KnownDeviceNames known = randomKnownDeviceNames(random);
      final StepStatus status = pickOne(random, _statusesNamingTheRunner);
      final RunStep step = _randomStepOn(random, known.device.id, status);

      final String text = _describe(random, step, known.deviceNames);

      expect(text, startsWith(known.device.name));
    }
  });
}
