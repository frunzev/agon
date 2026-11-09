import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';

import '../bridge/support/hostile_texts.dart';
import '../bridge/support/node_json_primitives.dart';
import '../support/random_inputs.dart';

const int _largestWorkflowCount = 6;

Workflow _workflowNamed(WorkflowId id, String name) {
  return Workflow(
    id: id,
    name: name,
    availability: const AllWorkspaces(),
    agents: const <WorkflowAgent>[],
    connections: const <AgentConnection>[],
    signature: null,
  );
}

List<Workflow> _randomWorkflows(Random random) {
  final int count = random.nextInt(_largestWorkflowCount + 1);
  return <Workflow>[
    for (int i = 0; i < count; i += 1)
      _workflowNamed(
        WorkflowId('workflow-$i-${randomUuidText(random)}'),
        randomHostileText(random),
      ),
  ];
}

WorkflowId _unknownWorkflowId(Random random) {
  return WorkflowId('missing-${randomHostileText(random)}');
}

void main() {
  test('test_find_workflow_for_doer_property_returns_the_matching_one', () {
    final Random random = seededRandom(97291);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> workflows = _randomWorkflows(random);
      if (workflows.isEmpty) {
        continue;
      }
      final Workflow wanted = pickOne(random, workflows);

      final Workflow? found = findWorkflowForDoer(
        WorkflowDoer(wanted.id),
        workflows,
      );

      expect(identical(found, wanted), isTrue);
    }
  });

  test('test_find_workflow_for_doer_property_one_agent_needs_no_list', () {
    final Random random = seededRandom(97292);

    for (int i = 0; i < propertyIterations; i += 1) {
      final OneAgentDoer doer = OneAgentDoer(
        pickOne(random, AgentKind.values),
      );

      expect(findWorkflowForDoer(doer, const <Workflow>[]), isNull);
      expect(findWorkflowForDoer(doer, _randomWorkflows(random)), isNull);
    }
  });

  test('test_find_workflow_for_doer_property_failure_names_the_workflow', () {
    final Random random = seededRandom(97293);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowId unknown = _unknownWorkflowId(random);

      expect(
        () => findWorkflowForDoer(
          WorkflowDoer(unknown),
          _randomWorkflows(random),
        ),
        throwsA(
          isA<RecordNotFound>()
              .having((RecordNotFound error) => error.kind, 'kind', 'workflow')
              .having(
                (RecordNotFound error) => error.identifier,
                'identifier',
                unknown.value,
              ),
        ),
      );
    }
  });

  test('test_describe_doer_property_agents_shown_by_plain_label', () {
    final Set<String> labels = <String>{};

    for (final AgentKind agent in AgentKind.values) {
      final String label = describeDoer(
        OneAgentDoer(agent),
        const <Workflow>[],
      );

      expect(label.trim(), isNotEmpty);
      expect(label, isNot(contains(agent.name)), reason: label);
      labels.add(label);
    }

    expect(labels.length, AgentKind.values.length);
  });

  test('test_describe_doer_property_workflow_name_kept_after_prefix', () {
    final Random random = seededRandom(97294);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> workflows = _randomWorkflows(random);
      if (workflows.isEmpty) {
        continue;
      }
      final Workflow wanted = pickOne(random, workflows);

      final String label = describeDoer(WorkflowDoer(wanted.id), workflows);

      expect(label, 'workflow ${wanted.name}');
    }
  });

  test('test_describe_doer_property_unknown_workflow_fails_cleanly', () {
    final Random random = seededRandom(97295);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowDoer doer = WorkflowDoer(_unknownWorkflowId(random));

      expect(
        () => describeDoer(doer, _randomWorkflows(random)),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });
}
