import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/chat/chat_run_context.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';
import 'support/random_chat_run_contexts.dart';

const String _unassignedName = 'Agent';
const String _personName = 'You';
final Set<String> _agentKindNames = <String>{
  for (final AgentKind kind in AgentKind.values) kind.label,
  _personName,
  _unassignedName,
};

String _describeStepSuffix(ChatRunContext context) {
  return ' · step ${context.currentStep.name}';
}

String _readKindPrefix(ChatRunContext context) {
  final String summary = context.agentSummary;
  final int suffixLength = _describeStepSuffix(context).length;
  return summary.substring(0, summary.length - suffixLength);
}

WorkflowAgentId? _randomAgentIdOf(Random random, Workflow? workflow) {
  return pickOne(random, <WorkflowAgentId?>[
    null,
    missingStepAgentId,
    for (final WorkflowAgent agent in workflow?.agents ?? <WorkflowAgent>[])
      agent.id,
  ]);
}

String _expectedAgentStepKind(Workflow? workflow, WorkflowAgentId? agentId) {
  for (final WorkflowAgent agent in workflow?.agents ?? <WorkflowAgent>[]) {
    if (agent.id == agentId && agent.stepKind == StepKind.agent) {
      return agent.kind?.label ?? _unassignedName;
    }
  }
  return _unassignedName;
}

void main() {
  test('test_agent_title_property_names_the_runner_device', () {
    final Random random = seededRandom(97801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext context = randomChatRunContext(random);
      if (context.runnerId == null) {
        continue;
      }

      expect(context.agentTitle, 'Agent on ${context.runnerName}');
    }
  });

  test('test_agent_title_property_unassigned_reads_agent_alone', () {
    final Random random = seededRandom(97802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext context = randomChatRunContext(random);
      if (context.runnerId != null) {
        continue;
      }

      expect(context.agentTitle, _unassignedName);
    }
  });

  test('test_agent_title_property_different_runners_get_different_'
      'titles', () {
    final Random random = seededRandom(97803);
    final Map<String, DeviceId> runnersByTitle = <String, DeviceId>{};

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext context = randomChatRunContext(random);
      final DeviceId? runner = context.runnerId;
      if (runner == null) {
        continue;
      }

      final DeviceId knownRunner = runnersByTitle.putIfAbsent(
        context.agentTitle,
        () => runner,
      );
      expect(knownRunner, runner);
    }
    expect(runnersByTitle.length, greaterThan(1));
  });

  test('test_agent_summary_property_ends_with_the_current_step', () {
    final Random random = seededRandom(97804);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext context = randomChatRunContext(random);

      expect(context.agentSummary, endsWith(_describeStepSuffix(context)));
    }
  });

  test('test_agent_summary_property_starts_with_a_known_kind', () {
    final Random random = seededRandom(97805);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext context = randomChatRunContext(random);

      expect(_agentKindNames, contains(_readKindPrefix(context)));
    }
  });

  test('test_agent_summary_property_ignores_device_names', () {
    final Random random = seededRandom(97806);
    final List<Device> renamedOrder = galleryDevices.reversed.toList();

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRunContext context = randomChatRunContext(random);
      final ChatRunContext reordered = rebuildWithDeviceNames(
        context,
        DeviceNames(renamedOrder),
      );

      expect(reordered.agentSummary, context.agentSummary);
    }
  });

  test('test_describe_agent_kind_property_one_agent_tasks_name_their_'
      'agent', () {
    final Random random = seededRandom(97807);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentKind kind = pickOne(random, AgentKind.values);
      final Workflow? workflow = random.nextBool()
          ? null
          : randomChatWorkflow(random);

      final ChatRunContext context = randomOneStepContext(
        random,
        doer: OneAgentDoer(kind),
        workflow: workflow,
        agentId: _randomAgentIdOf(random, workflow),
      );

      expect(_readKindPrefix(context), kind.label);
    }
  });

  test('test_describe_agent_kind_property_person_steps_read_you', () {
    final Random random = seededRandom(97808);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgent person = buildPersonStepAgent(
        randomAgent(random, 99),
      );
      final Workflow workflow = galleryWorkflows.first.withGraph(
        agents: <WorkflowAgent>[...randomChatWorkflow(random).agents, person],
        connections: const <AgentConnection>[],
      );

      final ChatRunContext context = randomOneStepContext(
        random,
        doer: WorkflowDoer(workflow.id),
        workflow: workflow,
        agentId: person.id,
      );

      expect(_readKindPrefix(context), _personName);
    }
  });

  test('test_describe_agent_kind_property_workflow_steps_read_their_agent_'
      'kind_or_agent', () {
    final Random random = seededRandom(97809);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow? workflow = random.nextInt(4) == 0
          ? null
          : randomChatWorkflow(random);
      final WorkflowAgentId? agentId = _randomAgentIdOf(random, workflow);
      final WorkflowAgent? agent = agentId == null
          ? null
          : workflow?.findAgentIfPresent(agentId);
      if (agent?.stepKind == StepKind.person) {
        continue;
      }

      final ChatRunContext context = randomOneStepContext(
        random,
        doer: WorkflowDoer(workflow?.id ?? galleryWorkflows.first.id),
        workflow: workflow,
        agentId: agentId,
      );

      final String expected = _expectedAgentStepKind(workflow, agentId);
      expect(_readKindPrefix(context), expected);
    }
  });
}
