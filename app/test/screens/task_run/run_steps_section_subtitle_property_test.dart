import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/runner_target_text.dart';
import 'package:agent_orchestration/presentation/step_round_text.dart';
import 'package:agent_orchestration/screens/task_run/run_steps_section.dart';

import '../../support/random_inputs.dart';
import 'support/random_shown_runs.dart';
import 'support/run_steps_section_scenes.dart';

final RegExp _roundText = RegExp(r' · round (\d+)(?: of (\d+))?(?: · |$)');
const List<String> _personBeginnings = <String>[
  'Will ask you',
  'Asked you ',
  'You · answered after ',
  'Did not start',
  'Stopped after ',
];
const List<String> _personOnlyBeginnings = <String>[
  'Will ask you',
  'You · answered after ',
];

bool _isPersonAgent(Workflow? workflow, RunStep step) {
  final WorkflowAgentId? agentId = step.agentId;
  if (workflow == null || agentId == null) {
    return false;
  }
  return workflow.findAgentIfPresent(agentId)?.stepKind == StepKind.person;
}

Future<List<String>> _pumpAndReadSubtitles(
  WidgetTester tester,
  Random random,
  SectionInputs inputs,
) async {
  await pumpSection(
    tester,
    random: random,
    section: buildSection(inputs, key: UniqueKey()),
  );
  return readShownSubtitles(tester);
}

void main() {
  testWidgets(
    'test_run_steps_section_describe_subtitle_property_round_within_total',
    (WidgetTester tester) async {
      final Random random = seededRandom(115401);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SectionInputs inputs = randomSectionInputs(random);
        final List<String> subtitles = await _pumpAndReadSubtitles(
          tester,
          random,
          inputs,
        );

        for (int index = 0; index < subtitles.length; index += 1) {
          final RunStep step = inputs.run.steps[index];
          final RegExpMatch? match = _roundText.firstMatch(subtitles[index]);
          expect(match != null, step.earlierRounds.isNotEmpty);
          if (match == null) {
            continue;
          }
          final int round = int.parse(match.group(1)!);
          expect(round, step.earlierRounds.length + 1);
          final String? total = match.group(2);
          if (total != null) {
            expect(round, lessThanOrEqualTo(int.parse(total)));
          }
        }
      }
    },
  );

  testWidgets(
    'test_run_steps_section_describe_subtitle_property_outcome_comes_last',
    (WidgetTester tester) async {
      final Random random = seededRandom(115402);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SectionInputs inputs = randomSectionInputs(random);
        final List<String> subtitles = await _pumpAndReadSubtitles(
          tester,
          random,
          inputs,
        );

        for (int index = 0; index < subtitles.length; index += 1) {
          final String? outcome = inputs.run.steps[index].outcome;
          final bool endsWithOutcome =
              outcome != null &&
              subtitles[index].endsWith(' · →\u00A0$outcome');
          expect(endsWithOutcome, outcome != null);
          expect(subtitles[index].contains('→'), outcome != null);
        }
      }
    },
  );

  testWidgets(
    'test_run_steps_section_describe_subtitle_property_skipped_says_end',
    (WidgetTester tester) async {
      final Random random = seededRandom(115403);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SectionInputs inputs = randomSectionInputs(random);
        final List<String> subtitles = await _pumpAndReadSubtitles(
          tester,
          random,
          inputs,
        );

        for (int index = 0; index < subtitles.length; index += 1) {
          final RunStep step = inputs.run.steps[index];
          if (step.status != StepStatus.skipped) {
            continue;
          }
          final String expectedStart = step.startedAt == null
              ? 'Did not start'
              : 'Stopped after ';
          expect(subtitles[index], startsWith(expectedStart));
        }
      }
    },
  );

  testWidgets(
    'test_run_steps_section_is_person_step_property_names_no_runner',
    (WidgetTester tester) async {
      final Random random = seededRandom(115404);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SectionInputs inputs = randomSectionInputs(random);
        final List<String> subtitles = await _pumpAndReadSubtitles(
          tester,
          random,
          inputs,
        );

        for (int index = 0; index < subtitles.length; index += 1) {
          if (!_isPersonAgent(inputs.workflow, inputs.run.steps[index])) {
            continue;
          }
          final String subtitle = subtitles[index];
          expect(_personBeginnings.any(subtitle.startsWith), isTrue);
          expect(subtitle, isNot(contains('Waiting for a runner')));
          expect(subtitle, isNot(contains(' so far')));
          expect(subtitle, isNot(startsWith('Any runner')));
        }
      }
    },
  );

  testWidgets(
    'test_run_steps_section_is_person_step_property_agent_steps_never_ask_you',
    (WidgetTester tester) async {
      final Random random = seededRandom(115405);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SectionInputs inputs = randomSectionInputs(random);
        final List<String> subtitles = await _pumpAndReadSubtitles(
          tester,
          random,
          inputs,
        );

        for (int index = 0; index < subtitles.length; index += 1) {
          if (_isPersonAgent(inputs.workflow, inputs.run.steps[index])) {
            continue;
          }
          expect(
            _personOnlyBeginnings.any(subtitles[index].startsWith),
            isFalse,
          );
        }
      }
    },
  );

  testWidgets(
    'test_run_steps_section_is_person_step_property_unknown_uses_task',
    (WidgetTester tester) async {
      final Random random = seededRandom(115406);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final SectionInputs inputs = randomSectionInputs(random);
        final SectionInputs unknown = (
          run: inputs.run,
          task: inputs.task,
          workflow: random.nextBool()
              ? null
              : randomWorkflowWithAgents(random),
        );
        final List<String> subtitles = await _pumpAndReadSubtitles(
          tester,
          random,
          unknown,
        );

        final String taskTarget = joinSegments(
          describeRunnerTarget(inputs.task.runsOn, galleryDeviceNames),
        );
        for (int index = 0; index < subtitles.length; index += 1) {
          final RunStep step = inputs.run.steps[index];
          final bool isKnown =
              unknown.workflow?.findAgentIfPresent(step.agentId!) != null;
          if (isKnown || step.status != StepStatus.waiting) {
            continue;
          }
          expect(subtitles[index], startsWith(taskTarget));
          expect(subtitles[index], isNot(startsWith('Will ask you')));
        }
      }
    },
  );

  test('test_find_step_target_property_missing_agent_falls_back_to_task', () {
    final Random random = seededRandom(115407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SectionInputs inputs = randomSectionInputs(random);
      final RunStep step = pickOne(random, inputs.run.steps);
      final Workflow? otherWorkflow = random.nextBool()
          ? null
          : randomWorkflowWithAgents(random);
      final bool isKnown =
          otherWorkflow?.findAgentIfPresent(step.agentId!) != null;

      final RunnerTarget target = findStepTarget(
        step: step,
        task: inputs.task,
        workflow: otherWorkflow,
      );

      if (!isKnown) {
        expect(target, inputs.task.runsOn);
      }
    }
  });

  test('test_find_step_target_property_ignores_step_progress', () {
    final Random random = seededRandom(115408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SectionInputs inputs = randomSectionInputs(random);
      final RunStep step = pickOne(random, inputs.run.steps);
      final StepStatus otherStatus = pickOne(random, StepStatus.values);
      final StepTimes times = randomStepTimes(random, otherStatus, galleryNow);
      final RunStep progressed = RunStep(
        name: step.name,
        agentId: step.agentId,
        runner: pickOne(random, <DeviceId?>[null, ...shownRunners]),
        status: otherStatus,
        startedAt: times.startedAt,
        finishedAt: times.finishedAt,
        result: randomWordPhrase(random),
        outcome: null,
        loopSource: step.loopSource,
        earlierRounds: step.earlierRounds,
      );

      final RunnerTarget before = findStepTarget(
        step: step,
        task: inputs.task,
        workflow: inputs.workflow,
      );
      final RunnerTarget after = findStepTarget(
        step: progressed,
        task: inputs.task,
        workflow: inputs.workflow,
      );
      expect(after, before);
      expect(
        describeStepRound(step: progressed, workflow: inputs.workflow),
        describeStepRound(step: step, workflow: inputs.workflow),
      );
    }
  });
}
