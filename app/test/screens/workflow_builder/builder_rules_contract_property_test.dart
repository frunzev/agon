import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';

const String _chooseAgentLabel = 'Choose an agent';
const String _nameTakenProblem = 'Another agent has this name';
const String _completeTask = 'Do the work';
const WorkflowAgentId _unknownAgentId = WorkflowAgentId('unknown-step');
const List<String> _blankTasks = <String>['', ' ', '\t\n', ' ', ' 　'];

Workflow _randomCompleteWorkflow(Random random) {
  final Workflow workflow = randomBranchingWorkflow(random);
  return workflow.withGraph(
    agents: <WorkflowAgent>[
      for (final WorkflowAgent agent in workflow.agents)
        agent.copyWith(
          kind: agent.kind ?? pickOne(random, AgentKind.values),
          task: _completeTask,
        ),
    ],
    connections: workflow.connections,
  );
}

Workflow _withExtraConnection(
  Random random,
  Workflow workflow,
  AgentConnection added,
) {
  final List<AgentConnection> connections = List<AgentConnection>.of(
    workflow.connections,
  );
  connections.insert(random.nextInt(connections.length + 1), added);
  return workflow.withGraph(agents: workflow.agents, connections: connections);
}

AgentConnection _randomBrokenConnection(Random random, Workflow workflow) {
  final WorkflowAgentId known = pickOne(random, workflow.agents).id;
  final List<AgentConnection> broken = <AgentConnection>[
    AgentConnection(from: known, to: known, condition: null, roundLimit: null),
    AgentConnection(
      from: known,
      to: _unknownAgentId,
      condition: null,
      roundLimit: null,
    ),
    AgentConnection(
      from: _unknownAgentId,
      to: known,
      condition: null,
      roundLimit: null,
    ),
  ];
  if (workflow.connections.isNotEmpty) {
    final AgentConnection copied = pickOne(random, workflow.connections);
    broken.add(copied);
  }
  return pickOne(random, broken);
}

void main() {
  test(
    'test_describe_signing_problem_property_agrees_with_workflow_rules',
    () {
      final Random random = seededRandom(1161501);
      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow complete = _randomCompleteWorkflow(random);
        final Workflow checked = complete.agents.isEmpty || random.nextBool()
            ? complete
            : _withExtraConnection(
                random,
                complete,
                _randomBrokenConnection(random, complete),
              );

        expect(
          describeSigningProblem(checked),
          describeWorkflowProblem(checked),
        );
      }
    },
  );

  test('test_describe_signing_problem_property_broken_graphs_never_sign', () {
    final Random random = seededRandom(1161502);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        expect(describeSigningProblem(workflow), noAgentsProblem);
        continue;
      }
      final Workflow broken = _withExtraConnection(
        random,
        workflow,
        _randomBrokenConnection(random, workflow),
      );

      expect(describeWorkflowProblem(broken), isNotNull);
      expect(describeSigningProblem(broken), isNotNull);
    }
  });

  test('test_describe_step_problem_property_names_the_first_open_step', () {
    final Random random = seededRandom(1161503);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow complete = _randomCompleteWorkflow(random);
      if (complete.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent opened = pickOne(random, complete.agents);
      final String blank = pickOne(random, _blankTasks);
      final bool isPerson = opened.stepKind == StepKind.person;
      final bool clearsKind = !isPerson && random.nextBool();
      final WorkflowAgent changed = clearsKind
          ? WorkflowAgent(
              id: opened.id,
              name: opened.name,
              stepKind: opened.stepKind,
              kind: null,
              task: opened.task,
              runsOn: opened.runsOn,
              skills: opened.skills,
              usesAutomaticSkills: opened.usesAutomaticSkills,
              approvalPolicy: opened.approvalPolicy,
              position: opened.position,
            )
          : opened.copyWith(task: blank);
      final Workflow withOpenStep = complete.withGraph(
        agents: <WorkflowAgent>[
          for (final WorkflowAgent agent in complete.agents)
            if (agent.id == opened.id) changed else agent,
        ],
        connections: complete.connections,
      );

      final String expected = isPerson
          ? 'Write a question for ${opened.name}'
          : clearsKind
          ? 'Choose an agent for ${opened.name}'
          : 'Write a task for ${opened.name}';
      expect(describeSigningProblem(withOpenStep), expected);
    }
  });

  test('test_describe_step_problem_property_kind_comes_before_task', () {
    final Random random = seededRandom(1161504);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final WorkflowAgent blank = buildBlankAgent(workflow);
      final Workflow withBlank = addAgent(workflow, blank);
      final bool hasOtherOpenStep = workflow.agents.any(
        (WorkflowAgent agent) =>
            agent.task.trim().isEmpty ||
            (agent.stepKind == StepKind.agent && agent.kind == null),
      );
      if (hasOtherOpenStep) {
        continue;
      }

      expect(
        describeSigningProblem(withBlank),
        'Choose an agent for ${blank.name}',
      );
    }
  });

  test('test_describe_step_problem_property_people_never_need_an_agent', () {
    final Random random = seededRandom(1161505);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow complete = _randomCompleteWorkflow(random);
      final WorkflowAgent person = buildBlankPersonStep(complete);
      final Workflow asked = addAgent(
        complete,
        person.copyWith(task: randomHostileText(random) + _completeTask),
      );

      expect(person.kind, isNull);
      expect(describeSigningProblem(asked), describeWorkflowProblem(asked));
    }
  });

  test('test_describe_agent_name_problem_property_own_name_is_free', () {
    final Random random = seededRandom(1161506);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomCompleteWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent agent = pickOne(random, workflow.agents);

      final String? problem = describeAgentNameProblem(
        workflow: workflow,
        agent: agent,
        name: agent.name,
      );

      expect(problem, describeNameProblem(agent.name));
    }
  });

  test(
    'test_describe_agent_name_problem_property_hostile_names_explained',
    () {
      final Random random = seededRandom(1161507);
      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow workflow = _randomCompleteWorkflow(random);
        final WorkflowAgent agent = buildBlankAgent(workflow);
        final String name = randomHostileText(random);

        final String? problem = describeAgentNameProblem(
          workflow: workflow,
          agent: agent,
          name: name,
        );

        final String? formatProblem = describeNameProblem(name);
        if (formatProblem != null) {
          expect(problem, formatProblem);
        } else {
          expect(problem == null || problem == _nameTakenProblem, isTrue);
        }
      }
    },
  );

  test('test_build_agent_kind_entries_property_each_kind_once_in_order', () {
    for (final AgentKind? kind in <AgentKind?>[null, ...AgentKind.values]) {
      final List<SelectOption<AgentKindChoice>> entries =
          buildAgentKindEntries(kind);
      final List<SelectOption<AgentKindChoice>> kindEntries =
          <SelectOption<AgentKindChoice>>[
            for (final SelectOption<AgentKindChoice> entry in entries)
              if (entry.value.kind != null) entry,
          ];

      expect(kindEntries.length, AgentKind.values.length);
      for (int index = 0; index < kindEntries.length; index += 1) {
        final AgentKind expected = AgentKind.values[index];
        expect(kindEntries[index].value, AgentKindChoice(expected));
        expect(kindEntries[index].label, expected.label);
        expect(kindEntries[index].isEnabled, isTrue);
      }
    }
  });

  test(
    'test_build_agent_kind_entries_property_placeholder_first_disabled',
    () {
      final List<SelectOption<AgentKindChoice>> unset = buildAgentKindEntries(
        null,
      );

      expect(unset.first.value, const AgentKindChoice(null));
      expect(unset.first.label, _chooseAgentLabel);
      expect(unset.first.isEnabled, isFalse);
      for (final AgentKind kind in AgentKind.values) {
        final List<String> labels = <String>[
          for (final SelectOption<AgentKindChoice> entry
              in buildAgentKindEntries(kind))
            entry.label,
        ];
        expect(labels, isNot(contains(_chooseAgentLabel)));
      }
    },
  );
}
