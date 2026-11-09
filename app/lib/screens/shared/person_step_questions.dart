import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/person_step_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/step_round_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/shared/person_step_card.dart';
import 'package:agent_orchestration/screens/shared/run_label_lookup.dart';

const String _separator = ' · ';

String describeAskedTime(DateTime? askedAt, DateTime now) {
  if (askedAt == null) {
    return 'Waiting for your answer';
  }
  return 'Asked ${lowercaseFirstLetter(describeTimeSince(askedAt, now))}';
}

List<OpenPersonStep> findQuestionsForRun(
  List<OpenPersonStep> openSteps,
  RunId runId,
) {
  return <OpenPersonStep>[
    for (final OpenPersonStep openStep in openSteps)
      if (openStep.runId == runId) openStep,
  ];
}

final class PersonStepQuestions {
  const PersonStepQuestions({
    required this.taskRepository,
    required this.workflowRepository,
    required this.personStepRepository,
  });

  final TaskRepository taskRepository;
  final WorkflowRepository workflowRepository;
  final PersonStepRepository personStepRepository;

  Widget buildCardOnRunPage({
    required OpenPersonStep openStep,
    required Run run,
    required Workflow? workflow,
    required DateTime now,
  }) {
    return _buildCard(
      openStep: openStep,
      run: run,
      workflow: workflow,
      contextLine: describeAskedTime(openStep.askedAt, now),
    );
  }

  Widget buildCardInApprovals({
    required OpenPersonStep openStep,
    required DateTime now,
  }) {
    final String asked = describeAskedTime(openStep.askedAt, now);
    final List<Workflow> workflows = workflowRepository.listWorkflows();
    final String? runLabel = findRunLabel(
      runId: openStep.runId,
      taskRepository: taskRepository,
      workflows: workflows,
    );
    if (runLabel == null) {
      return _buildCard(
        openStep: openStep,
        run: null,
        workflow: null,
        contextLine: asked,
      );
    }

    final Run run = taskRepository.findRun(openStep.runId);
    final Task task = taskRepository.findTask(run.taskId);
    return _buildCard(
      openStep: openStep,
      run: run,
      workflow: findWorkflowForDoer(task.doer, workflows),
      contextLine: '$runLabel$_separator${lowercaseFirstLetter(asked)}',
    );
  }

  Widget _buildCard({
    required OpenPersonStep openStep,
    required Run? run,
    required Workflow? workflow,
    required String contextLine,
  }) {
    return PersonStepCard(
      key: ValueKey<(RunId, String)>((openStep.runId, openStep.stepName)),
      openStep: openStep,
      incomingResults: run == null
          ? const <RunStep>[]
          : findIncomingResults(
              run: run,
              workflow: workflow,
              stepName: openStep.stepName,
            ),
      contextLine: contextLine,
      personStepRepository: personStepRepository,
    );
  }
}
