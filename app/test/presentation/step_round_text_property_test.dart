import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/step_round_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/random_branching_workflows.dart';
import '../support/random_inputs.dart';
import '../support/random_step_rounds.dart';

const String _arrowWithNoBreakSpace = '→ ';
const String _separator = ' · ';

Run _runOf(List<RunStep> steps) {
  return galleryRunningRun.withProgress(
    nextStatus: RunStatus.running,
    nextSteps: steps,
    nextFinishedAt: null,
  );
}

List<RunStep> _randomStepsFor(Random random, Workflow workflow) {
  return <RunStep>[
    for (final WorkflowAgent agent in workflow.agents)
      buildAgentRunStep(
        agent: agent,
        loopSource: null,
        earlierRounds: const <EarlierRound>[],
        result: random.nextBool() ? randomHostileText(random) : null,
      ),
  ];
}

bool _feeds(Workflow workflow, RunStep step, WorkflowAgent target) {
  return workflow.connections.any(
    (AgentConnection connection) =>
        connection.from == step.agentId && connection.to == target.id,
  );
}

void main() {
  test('test_describe_step_outcome_property_hostile_outcome_verbatim', () {
    final Random random = seededRandom(94721);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String outcome = randomHostileText(random);

      final String? text = describeStepOutcome(outcome);

      expect(text, '$_arrowWithNoBreakSpace$outcome');
    }
  });

  test('test_describe_step_outcome_property_distinct_outcomes_differ', () {
    final Random random = seededRandom(94722);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String first = randomHostileText(random);
      final String second = randomHostileText(random);

      expect(
        describeStepOutcome(first) == describeStepOutcome(second),
        first == second,
      );
    }
  });

  test('test_describe_step_outcome_property_arrow_never_wraps_alone', () {
    final Random random = seededRandom(94723);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String? text = describeStepOutcome(
        pickOne(random, sampleOutcomes),
      );

      expect(text, isNotNull);
      expect(text!.contains('→ '), isFalse);
      expect(text, startsWith(_arrowWithNoBreakSpace));
    }
  });

  test('test_find_agent_named_property_unknown_step_has_no_inputs', () {
    final Random random = seededRandom(94724);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final Run run = _runOf(_randomStepsFor(random, workflow));

      expect(
        findIncomingResults(
          run: run,
          workflow: workflow,
          stepName: 'missing-${randomHostileText(random)}',
        ),
        isEmpty,
      );
    }
  });

  test('test_find_agent_named_property_only_exact_names_match', () {
    final Random random = seededRandom(94725);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final Run run = _runOf(_randomStepsFor(random, workflow));
      final String name = pickOne(random, workflow.agents).name;
      final String nearMiss = pickOne(random, <String>[
        ' $name',
        '$name ',
        name.toUpperCase(),
      ]);

      expect(
        findIncomingResults(run: run, workflow: workflow, stepName: nearMiss),
        isEmpty,
      );
    }
  });

  test('test_find_agent_named_property_each_step_finds_its_own_inputs', () {
    final Random random = seededRandom(94726);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final List<RunStep> steps = _randomStepsFor(random, workflow);
      final Run run = _runOf(steps);

      for (final WorkflowAgent target in workflow.agents) {
        final List<RunStep> incoming = findIncomingResults(
          run: run,
          workflow: workflow,
          stepName: target.name,
        );

        expect(incoming, <RunStep>[
          for (final RunStep step in steps)
            if (_feeds(workflow, step, target) && step.result != null) step,
        ]);
      }
    }
  });

  test('test_find_incoming_results_property_no_workflow_no_inputs', () {
    final Random random = seededRandom(94727);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final Run run = _runOf(_randomStepsFor(random, workflow));

      expect(
        findIncomingResults(
          run: run,
          workflow: null,
          stepName: pickOne(random, workflow.agents).name,
        ),
        isEmpty,
      );
    }
  });

  test('test_find_incoming_results_property_loop_sources_feed_targets', () {
    final Random random = seededRandom(94728);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final List<RunStep> steps = _randomStepsFor(random, workflow);
      final Run run = _runOf(steps);

      for (final AgentConnection loop in workflow.connections) {
        if (!loop.isLoop) {
          continue;
        }
        final RunStep sourceStep = steps.firstWhere(
          (RunStep step) => step.agentId == loop.from,
        );
        final List<RunStep> incoming = findIncomingResults(
          run: run,
          workflow: workflow,
          stepName: workflow.findAgent(loop.to).name,
        );

        expect(incoming.contains(sourceStep), sourceStep.result != null);
      }
    }
  });

  test('test_describe_earlier_round_property_parts_in_reading_order', () {
    final Random random = seededRandom(94729);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EarlierRound round = randomEarlierRound(random);
      final int roundNumber = 1 + random.nextInt(30);
      final String statusText = randomWordPhrase(random);

      final String text = describeEarlierRound(
        round: round,
        roundNumber: roundNumber,
        statusText: statusText,
      );

      final DateTime? startedAt = round.startedAt;
      final DateTime? finishedAt = round.finishedAt;
      final String? outcome = round.outcome;
      expect(
        text,
        <String>[
          'Round $roundNumber',
          statusText,
          if (outcome != null) '$_arrowWithNoBreakSpace$outcome',
          if (startedAt != null && finishedAt != null)
            'took ${describeStepDuration(finishedAt.difference(startedAt))}',
        ].join(_separator),
      );
    }
  });

  test('test_describe_earlier_round_property_took_needs_both_moments', () {
    final Random random = seededRandom(94730);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EarlierRound template = randomEarlierRound(random);
      final DateTime moment = randomUtcMoment(random);
      final EarlierRound halfTimed = EarlierRound(
        status: template.status,
        startedAt: random.nextBool() ? moment : null,
        finishedAt: null,
        result: template.result,
        outcome: template.outcome,
      );

      final String text = describeEarlierRound(
        round: halfTimed,
        roundNumber: 1,
        statusText: 'Done',
      );

      expect(text.contains('took'), isFalse);
    }
  });
}
