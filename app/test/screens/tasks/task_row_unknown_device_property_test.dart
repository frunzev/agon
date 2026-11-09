import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/tasks/task_row.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../support/random_inputs.dart';
import '../../support/unknown_device_names.dart';

String _describeRunsOn(Run run, DeviceNames deviceNames) {
  final Task task = pickOne(Random(run.number), galleryTasks);
  final List<TextSegment> segments = describeTaskRunsOn(
    task: task,
    latestRun: run,
    deviceNames: deviceNames,
  );
  final StringBuffer text = StringBuffer();
  for (final TextSegment segment in segments) {
    text.write(segment.text);
  }
  return text.toString();
}

Run _randomRunOn(Random random, DeviceId runner) {
  return moveEveryStepTo(pickOne(random, galleryRuns), runner);
}

void main() {
  test('test_describe_task_runs_on_property_an_unknown_runner_never_'
      'throws', () {
    final Random random = seededRandom(5311701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final Run run = _randomRunOn(random, unknown.deviceId);

      expect(
        () => _describeRunsOn(run, unknown.withoutDevice),
        returnsNormally,
      );
    }
  });

  test('test_describe_task_runs_on_property_an_unknown_runner_reads_as_its_'
      'short_identifier', () {
    final Random random = seededRandom(5311702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final Run run = _randomRunOn(random, unknown.deviceId);

      final String text = _describeRunsOn(run, unknown.withoutDevice);

      expect(text, _describeRunsOn(run, unknown.namingShortly));
      expect(text, unknown.shortName);
    }
  });

  test('test_describe_task_runs_on_property_a_known_runner_is_named', () {
    final Random random = seededRandom(5311703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final KnownDeviceNames known = randomKnownDeviceNames(random);
      final Run run = _randomRunOn(random, known.device.id);

      expect(_describeRunsOn(run, known.deviceNames), known.device.name);
    }
  });
}
