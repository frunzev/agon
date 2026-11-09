import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflows/workflow_text.dart';

import '../../support/random_inputs.dart';
import '../../support/unknown_device_names.dart';

Workflow _signedBy(Random random, DeviceId signer) {
  final Workflow template = pickOne(random, galleryWorkflows);
  return Workflow(
    id: template.id,
    name: template.name,
    availability: template.availability,
    agents: template.agents,
    connections: template.connections,
    signature: WorkflowSignature(
      signedBy: signer,
      signature: const <int>[],
      signedDocument: randomText(random),
      signedAt: random.nextBool() ? null : randomUtcMoment(random),
    ),
  );
}

WorkflowChange _changedBy(Random random, DeviceId changer) {
  final WorkflowChange template = pickOne(random, galleryWorkflowChanges);
  return WorkflowChange(
    workflowId: template.workflowId,
    changedBy: changer,
    changedAt: random.nextBool() ? null : randomUtcMoment(random),
    summary: template.summary,
    differences: template.differences,
    signedDocument: template.signedDocument,
    changedDocument: template.changedDocument,
  );
}

String _describeSigned(Workflow workflow, DeviceNames deviceNames) {
  return describeSignedSummary(
    workflow: workflow,
    workspaces: galleryWorkspaces,
    deviceNames: deviceNames,
    now: galleryNow,
  );
}

String _describeChange(WorkflowChange change, DeviceNames deviceNames) {
  return describeChangeSummary(
    change: change,
    deviceNames: deviceNames,
    now: galleryNow,
  );
}

void main() {
  test('test_describe_agent_target_property_an_unknown_runner_never_'
      'throws', () {
    final Random random = seededRandom(5311501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final RunnerTarget target = SpecificRunner(unknown.deviceId);

      expect(
        () => describeAgentTarget(target, unknown.withoutDevice),
        returnsNormally,
      );
    }
  });

  test('test_describe_agent_target_property_an_unknown_runner_reads_as_its_'
      'short_identifier', () {
    final Random random = seededRandom(5311502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final RunnerTarget target = SpecificRunner(unknown.deviceId);

      final String text = describeAgentTarget(target, unknown.withoutDevice);

      expect(text, describeAgentTarget(target, unknown.namingShortly));
      expect(text, unknown.shortName);
    }
  });

  test('test_describe_agent_target_property_a_known_runner_is_named', () {
    final Random random = seededRandom(5311503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final KnownDeviceNames known = randomKnownDeviceNames(random);
      final RunnerTarget target = SpecificRunner(known.device.id);

      expect(
        describeAgentTarget(target, known.deviceNames),
        known.device.name,
      );
    }
  });

  test('test_describe_signed_summary_property_an_unknown_signer_never_'
      'throws', () {
    final Random random = seededRandom(5311504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final Workflow workflow = _signedBy(random, unknown.deviceId);

      expect(
        () => _describeSigned(workflow, unknown.withoutDevice),
        returnsNormally,
      );
    }
  });

  test('test_describe_signed_summary_property_an_unknown_signer_reads_as_'
      'its_short_identifier', () {
    final Random random = seededRandom(5311505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final Workflow workflow = _signedBy(random, unknown.deviceId);

      final String text = _describeSigned(workflow, unknown.withoutDevice);

      expect(text, _describeSigned(workflow, unknown.namingShortly));
      expect(text, contains('signed on ${unknown.shortName}'));
    }
  });

  test('test_describe_signed_summary_property_a_known_signer_is_named', () {
    final Random random = seededRandom(5311506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final KnownDeviceNames known = randomKnownDeviceNames(random);
      final Workflow workflow = _signedBy(random, known.device.id);

      final String text = _describeSigned(workflow, known.deviceNames);

      expect(text, contains('signed on ${known.device.name}'));
    }
  });

  test('test_describe_change_summary_property_an_unknown_editor_never_'
      'throws', () {
    final Random random = seededRandom(5311507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final WorkflowChange change = _changedBy(random, unknown.deviceId);

      expect(
        () => _describeChange(change, unknown.withoutDevice),
        returnsNormally,
      );
    }
  });

  test('test_describe_change_summary_property_an_unknown_editor_reads_as_'
      'its_short_identifier', () {
    final Random random = seededRandom(5311508);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final WorkflowChange change = _changedBy(random, unknown.deviceId);

      final String text = _describeChange(change, unknown.withoutDevice);

      expect(text, _describeChange(change, unknown.namingShortly));
      expect(text, endsWith('on ${unknown.shortName}'));
    }
  });

  test('test_describe_change_summary_property_a_known_editor_is_named', () {
    final Random random = seededRandom(5311509);

    for (int i = 0; i < propertyIterations; i += 1) {
      final KnownDeviceNames known = randomKnownDeviceNames(random);
      final WorkflowChange change = _changedBy(random, known.device.id);

      final String text = _describeChange(change, known.deviceNames);

      expect(text, endsWith('on ${known.device.name}'));
    }
  });
}
