import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/step_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../support/random_inputs.dart';
import '../support/sample_records.dart';

const int _longestStepSeconds = 6 * 60 * 60;
const String _separator = ' · ';

final DeviceNames _deviceNames = DeviceNames(galleryDevices);
final List<RunStep> _templates = <RunStep>[
  for (final Run run in galleryRuns)
    for (final RunStep step in run.steps)
      if (step.runner != null) step,
];
final RegExp _durationPattern = RegExp(r'(?:(\d+) min)? ?(?:(\d+) s)?$');
final RegExp _negativeNumber = RegExp(r'-\d');
final RegExp _elapsedPattern = RegExp(r'(\d+) min so far$');

RunStep _rebuildStep({
  required RunStep template,
  required StepStatus status,
  required DateTime? startedAt,
  required DateTime? finishedAt,
}) {
  return RunStep(
    name: template.name,
    agentId: template.agentId,
    runner: template.runner,
    status: status,
    startedAt: startedAt,
    finishedAt: finishedAt,
    result: template.result,
    outcome: template.outcome,
    loopSource: template.loopSource,
    earlierRounds: template.earlierRounds,
  );
}

String _describeAgentStep(Random random, RunStep step, DateTime now) {
  final List<TextSegment> segments = describeStepSubtitle(
    step: step,
    target: randomRunnerTarget(random),
    deviceNames: _deviceNames,
    now: now,
  );
  final StringBuffer text = StringBuffer();
  for (final TextSegment segment in segments) {
    text.write(segment.text);
  }
  return text.toString();
}

int _readShownSeconds(String text) {
  final String duration = text.split(_separator).last;
  final RegExpMatch match = _durationPattern.firstMatch(duration)!;
  final int minutes = int.parse(match.group(1) ?? '0');
  final int seconds = int.parse(match.group(2) ?? '0');
  return minutes * Duration.secondsPerMinute + seconds;
}

Duration _randomLength(Random random) {
  return Duration(seconds: random.nextInt(_longestStepSeconds));
}

void main() {
  test('test_measure_step_property_a_finished_step_reads_its_own_length', () {
    final Random random = seededRandom(96401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Duration length = _randomLength(random);
      final DateTime finishedAt = galleryNow.subtract(_randomLength(random));
      final RunStep step = _rebuildStep(
        template: pickOne(random, _templates),
        status: pickOne(random, <StepStatus>[
          StepStatus.done,
          StepStatus.failed,
        ]),
        startedAt: finishedAt.subtract(length),
        finishedAt: finishedAt,
      );

      final String text = _describeAgentStep(random, step, galleryNow);

      expect(text, startsWith(_deviceNames.describeDevice(step.runner!)));
      expect(_readShownSeconds(text), length.inSeconds);
    }
  });

  test('test_measure_step_property_a_skewed_clock_never_reads_negative', () {
    final Random random = seededRandom(96402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime startedAt = galleryNow.subtract(_randomLength(random));
      final DateTime finishedAt = startedAt.subtract(
        Duration(seconds: 1 + random.nextInt(_longestStepSeconds)),
      );
      final RunStep step = _rebuildStep(
        template: pickOne(random, _templates),
        status: pickOne(random, <StepStatus>[
          StepStatus.done,
          StepStatus.failed,
          StepStatus.skipped,
        ]),
        startedAt: startedAt,
        finishedAt: finishedAt,
      );

      final String agentText = _describeAgentStep(random, step, galleryNow);
      final String personText = describePersonStepSubtitle(
        step: step,
        now: galleryNow,
      ).single.text;

      expect(_negativeNumber.hasMatch(agentText), isFalse, reason: agentText);
      expect(
        _negativeNumber.hasMatch(personText),
        isFalse,
        reason: personText,
      );
      expect(agentText, endsWith('0 s'));
      expect(personText, endsWith('0 s'));
    }
  });

  test('test_measure_step_property_running_time_grows_with_now', () {
    final Random random = seededRandom(96403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime startedAt = galleryNow.subtract(_randomLength(random));
      final RunStep step = _rebuildStep(
        template: pickOne(random, _templates),
        status: StepStatus.running,
        startedAt: startedAt,
        finishedAt: null,
      );
      final DateTime laterNow = galleryNow.add(_randomLength(random));

      final String earlier = _describeAgentStep(random, step, galleryNow);
      final String later = _describeAgentStep(random, step, laterNow);
      final int earlierMinutes = int.parse(
        _elapsedPattern.firstMatch(earlier)!.group(1)!,
      );
      final int laterMinutes = int.parse(
        _elapsedPattern.firstMatch(later)!.group(1)!,
      );

      expect(earlierMinutes, greaterThanOrEqualTo(1));
      expect(laterMinutes, greaterThanOrEqualTo(earlierMinutes));
      expect(laterMinutes, max(1, laterNow.difference(startedAt).inMinutes));
    }
  });
}
