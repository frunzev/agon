import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/screens/workflows/draft_progress.dart';

import '../../support/random_inputs.dart';
import '../../support/unknown_device_names.dart';

WorkflowDraftProgress _draftedOn(Random random, DeviceId drafter) {
  return WorkflowDraftProgress(
    workflow: pickOne(random, galleryWorkflows),
    pendingAgents: const <PendingAgent>[],
    drafterKind: pickOne(random, AgentKind.values),
    drafterDeviceId: drafter,
  );
}

void main() {
  test('test_describe_drafter_property_an_unknown_device_never_throws', () {
    final Random random = seededRandom(5311601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final WorkflowDraftProgress progress = _draftedOn(
        random,
        unknown.deviceId,
      );

      expect(
        () => describeDrafter(
          progress: progress,
          deviceNames: unknown.withoutDevice,
        ),
        returnsNormally,
      );
    }
  });

  test('test_describe_drafter_property_an_unknown_device_reads_as_its_short_'
      'identifier', () {
    final Random random = seededRandom(5311602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final WorkflowDraftProgress progress = _draftedOn(
        random,
        unknown.deviceId,
      );

      final String text = describeDrafter(
        progress: progress,
        deviceNames: unknown.withoutDevice,
      );

      expect(
        text,
        describeDrafter(
          progress: progress,
          deviceNames: unknown.namingShortly,
        ),
      );
      expect(text, endsWith('is drafting on ${unknown.shortName}'));
    }
  });

  test('test_describe_drafter_property_a_known_device_is_named', () {
    final Random random = seededRandom(5311603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final KnownDeviceNames known = randomKnownDeviceNames(random);
      final WorkflowDraftProgress progress = _draftedOn(
        random,
        known.device.id,
      );

      final String text = describeDrafter(
        progress: progress,
        deviceNames: known.deviceNames,
      );

      expect(
        text,
        '${progress.drafterKind.label} is drafting on ${known.device.name}',
      );
    }
  });
}
