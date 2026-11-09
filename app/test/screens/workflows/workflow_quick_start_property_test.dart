import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/tasks/created_task_start.dart';
import 'package:agent_orchestration/screens/workflows/workflow_quick_start.dart';

import '../../data/fakes/support/task_inputs.dart';
import '../../support/people_facing_refusal_matchers.dart';
import '../../support/random_inputs.dart';
import '../../support/random_signature_workflows.dart';
import '../support/planned_refusal.dart';
import '../support/refusing_work_repositories.dart';

const ProjectId _quickStartProjectId = GalleryProjectIds.acmeApp;

typedef _QuickStartChoice = ({Workflow workflow, bool isStartable});

typedef _QuickStartScene = ({
  List<_QuickStartChoice> choices,
  FakeTaskRepository tasks,
});

WorkflowInSignatureState _maybeDropAgents(
  Random random,
  WorkflowInSignatureState choice,
) {
  final bool dropsAgents = random.nextInt(4) == 0;
  if (!dropsAgents) {
    return choice;
  }
  final Workflow agentless = choice.workflow.withGraph(
    agents: const <WorkflowAgent>[],
    connections: const <AgentConnection>[],
  );
  return WorkflowInSignatureState(workflow: agentless, state: choice.state);
}

_QuickStartChoice _describeChoice(WorkflowInSignatureState choice) {
  final bool hasAgents = choice.workflow.agents.isNotEmpty;
  return (
    workflow: choice.workflow,
    isStartable: choice.isSigned && hasAgents,
  );
}

_QuickStartScene _buildScene(Random random) {
  final List<WorkflowInSignatureState> storedChoices =
      <WorkflowInSignatureState>[
        for (final WorkflowInSignatureState choice
            in randomWorkflowsInSignatureStates(random))
          _maybeDropAgents(random, choice),
      ];
  final FakeTaskRepository tasks = buildTaskRepository(
    tasks: const <Task>[],
    runs: const <Run>[],
    workflows: buildSignatureStateRepository(storedChoices),
  );
  return (
    choices: <_QuickStartChoice>[
      for (final WorkflowInSignatureState choice in storedChoices)
        _describeChoice(choice),
    ],
    tasks: tasks,
  );
}

Future<RunId> _startNow(FakeTaskRepository tasks, Workflow workflow) {
  return startWorkflowNow(
    taskRepository: tasks,
    workflow: workflow,
    projectId: _quickStartProjectId,
  );
}

Matcher _throwsRefusalNamingTheTask() {
  return throwsA(
    isA<PeopleFacingRefusal>().having(
      (PeopleFacingRefusal refusal) => refusal.message,
      'message',
      startsWith(createdTaskNotStartedPrefix),
    ),
  );
}

int _countRuns(FakeTaskRepository tasks) {
  int runCount = 0;
  for (final Task task in tasks.listTasks()) {
    runCount += tasks.listRuns(task.id).length;
  }
  return runCount;
}

void main() {
  test(
    'test_start_workflow_now_property_only_startable_workflows_run',
    () async {
      final Random random = seededRandom(12301);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _QuickStartScene scene = _buildScene(random);
        final _QuickStartChoice choice = pickOne(random, scene.choices);

        final Future<RunId> started = _startNow(scene.tasks, choice.workflow);

        if (choice.isStartable) {
          await started;
          expect(_countRuns(scene.tasks), 1);
        } else {
          await expectLater(started, throwsPeopleFacingRefusal);
          expect(_countRuns(scene.tasks), 0);
        }
      }
    },
  );

  test(
    'test_start_workflow_now_property_a_refused_start_names_its_task',
    () async {
      final Random random = seededRandom(12302);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _QuickStartScene scene = _buildScene(random);
        final _QuickStartChoice choice = pickOne(random, scene.choices);

        if (choice.isStartable) {
          continue;
        }

        await expectLater(
          _startNow(scene.tasks, choice.workflow),
          _throwsRefusalNamingTheTask(),
        );

        final List<Task> leftTasks = scene.tasks.listTasks();
        expect(leftTasks, hasLength(1));
        final String expectedTitle =
            '$quickStartTitleStart${choice.workflow.name}';
        expect(leftTasks.single.title, expectedTitle);
      }
    },
  );

  test(
    'test_start_workflow_now_property_a_refused_create_starts_nothing',
    () async {
      final Random random = seededRandom(12303);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _QuickStartScene scene = _buildScene(random);
        final _QuickStartChoice choice = pickOne(random, scene.choices);
        final ExplainedRefusal planned = randomExplainedRefusal(random);
        final PlannedRefusal refusal = PlannedRefusal();
        refusal.problem = planned.problem;

        final Future<RunId> started = startWorkflowNow(
          taskRepository: RefusingTaskRepository(
            stored: scene.tasks,
            refusal: refusal,
          ),
          workflow: choice.workflow,
          projectId: _quickStartProjectId,
        );

        await expectLater(started, throwsA(same(planned.problem)));
        expect(scene.tasks.listTasks(), isEmpty);
        expect(refusal.attempts, 1);
      }
    },
  );

  test(
    'test_build_quick_start_task_property_every_draft_is_storable',
    () async {
      final Random random = seededRandom(12304);

      for (int i = 0; i < propertyIterations; i += 1) {
        final _QuickStartScene scene = _buildScene(random);
        final _QuickStartChoice choice = pickOne(random, scene.choices);
        final TaskDraft draft = buildQuickStartTask(
          workflow: choice.workflow,
          projectId: _quickStartProjectId,
        );

        final Task stored = await scene.tasks.createTask(draft);

        expect(stored.title, draft.title);
        expect(stored.doer, WorkflowDoer(choice.workflow.id));
        expect(stored.schedule, isNull);
        expect(stored.status, TaskStatus.toDo);
      }
    },
  );
}
