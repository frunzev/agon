import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';

const String _numberedIdPrefix = '00000000-0000-4000-8000-';
const int _hexadecimalRadix = 16;
const CanvasPosition _firstAgentPosition = CanvasPosition(
  horizontal: 92,
  vertical: 16,
);
final RegExp _numberedIdShape = RegExp(
  r'^00000000-0000-4000-8000-[0-9a-f]{12}$',
);

int _readIdNumber(WorkflowAgentId agentId) {
  final String digits = agentId.value.substring(_numberedIdPrefix.length);
  return int.parse(digits, radix: _hexadecimalRadix);
}

WorkflowAgentId _numberedId(int number) {
  final String digits = number.toRadixString(_hexadecimalRadix);
  return WorkflowAgentId('$_numberedIdPrefix${digits.padLeft(12, '0')}');
}

WorkflowAgent _withId(WorkflowAgent agent, WorkflowAgentId agentId) {
  return WorkflowAgent(
    id: agentId,
    name: agent.name,
    stepKind: agent.stepKind,
    kind: agent.kind,
    task: agent.task,
    runsOn: agent.runsOn,
    skills: agent.skills,
    usesAutomaticSkills: agent.usesAutomaticSkills,
    approvalPolicy: agent.approvalPolicy,
    position: agent.position,
  );
}

void main() {
  test('test_describe_numbered_agent_id_property_is_a_version_four_uuid', () {
    final Random random = seededRandom(84106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);

      final WorkflowAgent blank = random.nextBool()
          ? buildBlankAgent(workflow)
          : buildBlankPersonStep(workflow);

      expect(blank.id.value, matches(_numberedIdShape));
    }
  });

  test('test_describe_numbered_agent_id_property_counts_past_the_steps', () {
    final Random random = seededRandom(84107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);

      final WorkflowAgent blank = buildBlankAgent(workflow);

      expect(_readIdNumber(blank.id), workflow.agents.length + 1);
    }
  });

  test('test_describe_numbered_agent_id_property_numbers_keep_growing', () {
    final Random random = seededRandom(84108);

    for (int i = 0; i < propertyIterations; i += 1) {
      Workflow workflow = randomBranchingWorkflow(random);
      final int additions = 1 + random.nextInt(5);
      final List<int> numbers = <int>[];

      for (int step = 0; step < additions; step += 1) {
        final WorkflowAgent blank = buildBlankAgent(workflow);
        numbers.add(_readIdNumber(blank.id));
        workflow = addAgent(workflow, blank);
      }

      for (int index = 1; index < numbers.length; index += 1) {
        expect(numbers[index], greaterThan(numbers[index - 1]));
      }
    }
  });

  test('test_find_free_agent_id_property_skips_stored_numbered_ids', () {
    final Random random = seededRandom(84109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final int offset = random.nextInt(3);
      final List<WorkflowAgent> numbered = <WorkflowAgent>[
        for (int index = 0; index < workflow.agents.length; index += 1)
          _withId(
            workflow.agents[index],
            _numberedId(workflow.agents.length + offset + index),
          ),
      ];
      final Workflow crowded = workflow.withGraph(
        agents: numbered,
        connections: const <AgentConnection>[],
      );

      final WorkflowAgent blank = buildBlankAgent(crowded);

      final bool isTaken = numbered.any(
        (WorkflowAgent agent) => agent.id == blank.id,
      );
      expect(isTaken, isFalse);
    }
  });

  test('test_find_free_agent_id_property_is_the_same_for_the_same_input', () {
    final Random random = seededRandom(84110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);

      expect(buildBlankAgent(workflow).id, buildBlankPersonStep(workflow).id);
    }
  });

  test('test_find_free_agent_id_property_never_reuses_a_stored_id', () {
    final Random random = seededRandom(84111);

    for (int i = 0; i < propertyIterations; i += 1) {
      Workflow workflow = randomBranchingWorkflow(random);
      final int additions = 1 + random.nextInt(6);

      for (int step = 0; step < additions; step += 1) {
        final WorkflowAgent blank = random.nextBool()
            ? buildBlankAgent(workflow)
            : buildBlankPersonStep(workflow);
        final bool isTaken = workflow.agents.any(
          (WorkflowAgent agent) => agent.id == blank.id,
        );

        expect(isTaken, isFalse);
        workflow = addAgent(workflow, blank);
      }
    }
  });

  test('test_place_below_agents_property_an_empty_canvas_starts_at_top', () {
    expect(placeBelowAgents(const <WorkflowAgent>[]), _firstAgentPosition);
  });

  test('test_place_below_agents_property_lines_up_under_a_lowest_step', () {
    final Random random = seededRandom(84112);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      double lowest = workflow.agents.first.position.vertical;
      for (final WorkflowAgent agent in workflow.agents) {
        lowest = max(lowest, agent.position.vertical);
      }

      final CanvasPosition placed = placeBelowAgents(workflow.agents);

      final bool isUnderALowestStep = workflow.agents.any(
        (WorkflowAgent agent) =>
            agent.position.vertical == lowest &&
            agent.position.horizontal == placed.horizontal,
      );
      expect(isUnderALowestStep, isTrue);
      expect(placed.vertical, greaterThan(lowest));
    }
  });

  test('test_build_blank_step_property_starts_blank', () {
    final Random random = seededRandom(84113);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);

      for (final WorkflowAgent blank in <WorkflowAgent>[
        buildBlankAgent(workflow),
        buildBlankPersonStep(workflow),
      ]) {
        expect(blank.kind, isNull);
        expect(blank.task, isEmpty);
        expect(blank.runsOn, const AnyFreeRunner());
        expect(blank.skills, isEmpty);
        expect(blank.usesAutomaticSkills, isTrue);
        expect(blank.approvalPolicy, isNull);
        expect(describeNameProblem(blank.name), isNull);
      }
    }
  });

  test('test_build_blank_step_property_sits_below_every_step', () {
    final Random random = seededRandom(84114);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final CanvasPosition expected = placeBelowAgents(workflow.agents);

      expect(buildBlankAgent(workflow).position, expected);
      expect(buildBlankPersonStep(workflow).position, expected);
    }
  });

  test('test_build_blank_step_property_leaves_the_workflow_as_it_was', () {
    final Random random = seededRandom(84115);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final List<WorkflowAgent> agentsBefore = List<WorkflowAgent>.of(
        workflow.agents,
      );
      final List<AgentConnection> connectionsBefore = List<AgentConnection>.of(
        workflow.connections,
      );

      buildBlankAgent(workflow);
      buildBlankPersonStep(workflow);

      expect(workflow.agents, agentsBefore);
      expect(workflow.connections, connectionsBefore);
    }
  });

  test('test_has_agent_id_property_any_stored_id_is_refused', () {
    final Random random = seededRandom(84118);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent stored = pickOne(random, workflow.agents);
      final WorkflowAgent twin = _withId(buildBlankAgent(workflow), stored.id);

      expect(() => addAgent(workflow, twin), throwsArgumentError);
    }
  });

  test('test_has_agent_id_property_a_fresh_id_is_taken_in', () {
    final Random random = seededRandom(84119);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final WorkflowAgent fresh = _withId(
        buildBlankAgent(workflow),
        WorkflowAgentId('fresh-agent-$i'),
      );

      final Workflow added = addAgent(workflow, fresh);

      expect(added.agents.last, fresh);
    }
  });

  test('test_has_agent_id_property_ids_must_match_exactly', () {
    final Random random = seededRandom(84120);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final String storedId = pickOne(random, workflow.agents).id.value;
      final List<String> nearIds = <String>[
        storedId.toUpperCase(),
        '$storedId ',
        ' $storedId',
        '${storedId}0',
      ];
      final WorkflowAgent near = _withId(
        buildBlankAgent(workflow),
        WorkflowAgentId(pickOne(random, nearIds)),
      );

      expect(() => addAgent(workflow, near), returnsNormally);
    }
  });
}
