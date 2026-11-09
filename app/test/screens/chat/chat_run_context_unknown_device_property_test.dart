import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/chat/chat_run_context.dart';

import '../../support/random_inputs.dart';
import '../../support/unknown_device_names.dart';

const int _seedSpan = 1 << 30;

ChatRunContext _contextOn(
  Random random,
  DeviceId runner,
  DeviceNames deviceNames,
) {
  final Run run = moveEveryStepTo(pickOne(random, galleryRuns), runner);
  return ChatRunContext(
    run: run,
    task: pickOne(random, galleryTasks),
    workflow: null,
    deviceNames: deviceNames,
  );
}

void main() {
  test('test_chat_run_context_runner_name_property_an_unknown_runner_never_'
      'throws', () {
    final Random random = seededRandom(5311801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final ChatRunContext context = _contextOn(
        random,
        unknown.deviceId,
        unknown.withoutDevice,
      );

      expect(() => context.runnerName, returnsNormally);
      expect(() => context.agentTitle, returnsNormally);
    }
  });

  test('test_chat_run_context_runner_name_property_an_unknown_runner_reads_'
      'as_its_short_identifier', () {
    final Random random = seededRandom(5311802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final int seed = random.nextInt(_seedSpan);
      final ChatRunContext withoutDevice = _contextOn(
        seededRandom(seed),
        unknown.deviceId,
        unknown.withoutDevice,
      );
      final ChatRunContext namingShortly = _contextOn(
        seededRandom(seed),
        unknown.deviceId,
        unknown.namingShortly,
      );

      expect(withoutDevice.runnerName, namingShortly.runnerName);
      expect(withoutDevice.runnerName, unknown.shortName);
    }
  });

  test('test_chat_run_context_runner_name_property_a_known_runner_is_'
      'named', () {
    final Random random = seededRandom(5311803);

    for (int i = 0; i < propertyIterations; i += 1) {
      final KnownDeviceNames known = randomKnownDeviceNames(random);
      final ChatRunContext context = _contextOn(
        random,
        known.device.id,
        known.deviceNames,
      );

      expect(context.runnerName, known.device.name);
      expect(context.agentTitle, 'Agent on ${known.device.name}');
    }
  });
}
