import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/screens/chat/chat_run_context.dart';

import '../../data/rules/support/random_progress_runs.dart';
import '../../support/random_inputs.dart';
import 'support/random_chat_run_contexts.dart';

const String _unassignedName = 'Agent';
final DeviceNames _reversedDeviceNames = DeviceNames(
  galleryDevices.reversed.toList(),
);

String _findDeviceName(DeviceId deviceId) {
  for (final Device device in galleryDevices) {
    if (device.id == deviceId) {
      return device.name;
    }
  }
  throw StateError('No gallery device $deviceId');
}

ChatRunContext _withRun(ChatRunContext context, Run run) {
  return ChatRunContext(
    run: run,
    task: context.task,
    workflow: context.workflow,
    deviceNames: galleryDeviceNames,
  );
}

Run _copyRun(Run run, {required int number, required List<RunStep> steps}) {
  return Run(
    id: run.id,
    taskId: run.taskId,
    number: number,
    status: run.status,
    steps: steps,
    log: run.log,
    chat: run.chat,
    failure: run.failure,
    link: run.link,
    linkLostAt: run.linkLostAt,
    agentSession: run.agentSession,
    worktreeBranch: run.worktreeBranch,
    startedBy: run.startedBy,
    startedAt: run.startedAt,
    finishedAt: run.finishedAt,
    loopRounds: run.loopRounds,
    notes: run.notes,
  );
}

void main() {
  test('test_chat_run_context_constructor_property_keeps_records_and_finds_'
      'the_current_step', () {
    final Random random = seededRandom(97701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext sample = randomChatRunContext(random);

      final ChatRunContext context = ChatRunContext(
        run: sample.run,
        task: sample.task,
        workflow: sample.workflow,
        deviceNames: galleryDeviceNames,
      );

      expect(identical(context.run, sample.run), isTrue);
      expect(identical(context.task, sample.task), isTrue);
      expect(identical(context.workflow, sample.workflow), isTrue);
      final RunStep expectedStep = findCurrentStep(sample.run);
      expect(identical(context.currentStep, expectedStep), isTrue);
    }
  });

  test('test_chat_run_context_constructor_property_a_run_without_steps_'
      'fails_at_once', () {
    final Random random = seededRandom(97702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext sample = randomChatRunContext(random);
      final Run stepless = buildProgressRun(
        random,
        status: pickOne(random, RunStatus.values),
        steps: const <RunStep>[],
      );

      expect(() => _withRun(sample, stepless), throwsA(isA<StateError>()));
    }
  });

  test('test_runner_id_property_is_the_current_step_runner', () {
    final Random random = seededRandom(97703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext context = randomChatRunContext(random);

      expect(context.runnerId, findCurrentStep(context.run).runner);
    }
  });

  test('test_runner_id_property_ignores_device_names', () {
    final Random random = seededRandom(97704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext context = randomChatRunContext(random);
      final ChatRunContext renamed = rebuildWithDeviceNames(
        context,
        _reversedDeviceNames,
      );

      expect(renamed.runnerId, context.runnerId);
    }
  });

  test('test_runner_id_property_unassigned_steps_have_no_runner_name', () {
    final Random random = seededRandom(97705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext context = randomChatRunContext(random);

      final bool isUnassigned = context.runnerId == null;
      expect(context.runnerName == _unassignedName, isUnassigned);
      expect(context.agentTitle == _unassignedName, isUnassigned);
    }
  });

  test('test_run_label_property_names_workflow_or_task_and_number', () {
    final Random random = seededRandom(97706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext context = randomChatRunContext(random);
      final String name = context.workflow?.name ?? context.task.title;

      final String numberSuffix = ' #${context.run.number}';
      expect(context.runLabel, startsWith(name));
      expect(context.runLabel, endsWith(numberSuffix));
      expect(context.runLabel.length, name.length + numberSuffix.length);
    }
  });

  test('test_run_label_property_ignores_steps_runners_and_devices', () {
    final Random random = seededRandom(97707);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext context = randomChatRunContext(random);
      final Run otherSteps = randomChatRun(random, workflow: context.workflow);
      final Run sameNumber = _copyRun(
        context.run,
        number: context.run.number,
        steps: otherSteps.steps,
      );
      final ChatRunContext changed = rebuildWithDeviceNames(
        _withRun(context, sameNumber),
        _reversedDeviceNames,
      );

      expect(changed.runLabel, context.runLabel);
    }
  });

  test('test_run_label_property_other_run_numbers_get_other_labels', () {
    final Random random = seededRandom(97708);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext context = randomChatRunContext(random);
      final int otherNumber = context.run.number + 1 + random.nextInt(50);
      final Run renumbered = _copyRun(
        context.run,
        number: otherNumber,
        steps: context.run.steps,
      );
      final ChatRunContext other = _withRun(context, renumbered);

      expect(other.runLabel, isNot(context.runLabel));
    }
  });

  test('test_runner_name_property_names_the_runner_device', () {
    final Random random = seededRandom(97709);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext context = randomChatRunContext(random);
      final DeviceId? runner = context.runnerId;
      if (runner == null) {
        continue;
      }

      expect(context.runnerName, _findDeviceName(runner));
    }
  });

  test('test_runner_name_property_unassigned_reads_agent', () {
    final Random random = seededRandom(97710);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext context = randomChatRunContext(random);
      if (context.runnerId != null) {
        continue;
      }

      expect(context.runnerName, _unassignedName);
    }
  });

  test('test_runner_name_property_order_of_known_devices_does_not_'
      'matter', () {
    final Random random = seededRandom(97711);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext context = randomChatRunContext(random);
      final ChatRunContext reordered = rebuildWithDeviceNames(
        context,
        _reversedDeviceNames,
      );

      expect(reordered.runnerName, context.runnerName);
    }
  });
}
