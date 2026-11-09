import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../support/random_inputs.dart';
import 'support/random_connection_scenes.dart';

const int _roundReach = 1000;
const List<int> _documentedRounds = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
const String _arrow = ' → ';
final RegExp _wholeNumber = RegExp(r'-?\d+');

int? _randomValidLimit(Random random) {
  if (random.nextInt(4) == 0) {
    return null;
  }
  return pickOne(random, _documentedRounds);
}

String _randomNameText(Random random) {
  return randomText(random).replaceAll(_arrow.trim(), '');
}

ConnectionScene _renameEnds(Random random, ConnectionScene scene) {
  final List<WorkflowAgent> renamed = <WorkflowAgent>[
    for (final WorkflowAgent agent in scene.workflow.agents)
      agent.copyWith(name: '${_randomNameText(random)}#${agent.id.value}'),
  ];
  return ConnectionScene(
    workflow: scene.workflow.withGraph(
      agents: renamed,
      connections: scene.workflow.connections,
    ),
    connection: scene.connection,
  );
}

void main() {
  test('test_describe_connection_ends_property_from_then_arrow_then_to', () {
    final Random random = seededRandom(117909);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ConnectionScene scene = _renameEnds(
        random,
        randomConnectionScene(random),
      );
      final String fromName = scene.workflow
          .findAgent(scene.connection.from)
          .name;
      final String toName = scene.workflow.findAgent(scene.connection.to).name;

      final String ends = describeConnectionEnds(
        scene.workflow,
        scene.connection,
      );

      expect(ends.startsWith(fromName), isTrue, reason: ends);
      expect(ends.endsWith(toName), isTrue, reason: ends);
      expect(
        ends.substring(fromName.length, ends.length - toName.length),
        _arrow,
      );
    }
  });

  test('test_describe_connection_ends_property_reversing_swaps_names', () {
    final Random random = seededRandom(117910);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ConnectionScene scene = _renameEnds(
        random,
        randomConnectionScene(random),
      );
      final AgentConnection reversed = AgentConnection(
        from: scene.connection.to,
        to: scene.connection.from,
        condition: null,
        roundLimit: null,
      );

      final List<String> forward = describeConnectionEnds(
        scene.workflow,
        scene.connection,
      ).split(_arrow);
      final List<String> backward = describeConnectionEnds(
        scene.workflow,
        reversed,
      ).split(_arrow);

      expect(backward.reversed.join(_arrow), forward.join(_arrow));
    }
  });

  test('test_describe_connection_ends_property_unknown_step_is_refused', () {
    final Random random = seededRandom(117911);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ConnectionScene scene = randomConnectionScene(random);
      final AgentConnection dangling = AgentConnection(
        from: scene.connection.from,
        to: WorkflowAgentId('missing-${randomText(random)}'),
        condition: null,
        roundLimit: null,
      );

      expect(
        () => describeConnectionEnds(scene.workflow, dangling),
        throwsStateError,
      );
    }
  });

  test('test_describe_forward_outcome_hint_property_names_the_step', () {
    final Random random = seededRandom(117912);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String fromName = randomText(random);

      expect(describeForwardOutcomeHint(fromName), contains(fromName));
    }
  });

  test('test_describe_forward_outcome_hint_property_explains_empty_value', () {
    final Random random = seededRandom(117913);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String hint = describeForwardOutcomeHint(randomText(random));

      expect(hint, contains('empty'));
      expect(hint, contains('always follow'));
      expect(hint.trimRight().endsWith('.'), isTrue);
    }
  });

  test('test_describe_forward_outcome_hint_property_only_name_changes', () {
    final Random random = seededRandom(117914);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String first = randomText(random);
      final String second = randomText(random);

      final int lengthGap =
          describeForwardOutcomeHint(first).length -
          describeForwardOutcomeHint(second).length;

      expect(lengthGap, first.length - second.length);
    }
  });

  test('test_describe_round_limit_choice_property_matches_design_wording', () {
    for (final int rounds in _documentedRounds) {
      final String unit = rounds == 1 ? 'round' : 'rounds';

      expect(
        describeRoundLimitChoice(rounds),
        'Go back at most $rounds $unit',
      );
    }
  });

  test('test_describe_round_limit_choice_property_number_reads_back', () {
    final Random random = seededRandom(117915);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int rounds = random.nextInt(2 * _roundReach) - _roundReach;

      final String label = describeRoundLimitChoice(rounds);
      final Iterable<RegExpMatch> numbers = _wholeNumber.allMatches(label);

      expect(numbers.length, 1, reason: label);
      expect(int.parse(numbers.single.group(0)!), rounds);
    }
  });

  test('test_describe_round_limit_choice_property_labels_are_unique', () {
    final Set<String> labels = <String>{
      for (final int rounds in _documentedRounds)
        describeRoundLimitChoice(rounds),
    };

    expect(labels.length, _documentedRounds.length);
  });

  test('test_build_round_limit_entries_property_lists_rule_rounds', () {
    final Random random = seededRandom(117916);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int? roundLimit = _randomValidLimit(random);

      final List<SelectOption<RoundLimitChoice>> enabled =
          <SelectOption<RoundLimitChoice>>[
            for (final SelectOption<RoundLimitChoice> entry
                in buildRoundLimitEntries(roundLimit))
              if (entry.isEnabled) entry,
          ];

      expect(
        <int?>[
          for (final SelectOption<RoundLimitChoice> entry in enabled)
            entry.value.rounds,
        ],
        <int>[for (int r = fewestLoopRounds; r <= mostLoopRounds; r += 1) r],
      );
      for (final SelectOption<RoundLimitChoice> entry in enabled) {
        expect(entry.label, describeRoundLimitChoice(entry.value.rounds!));
      }
    }
  });

  test(
    'test_build_round_limit_entries_property_prompt_only_without_limit',
    () {
      final Random random = seededRandom(117917);

      for (int i = 0; i < propertyIterations; i += 1) {
        final int? roundLimit = _randomValidLimit(random);

        final List<SelectOption<RoundLimitChoice>> entries =
            buildRoundLimitEntries(roundLimit);
        final List<SelectOption<RoundLimitChoice>> disabled =
            <SelectOption<RoundLimitChoice>>[
              for (final SelectOption<RoundLimitChoice> entry in entries)
                if (!entry.isEnabled) entry,
            ];

        if (roundLimit == null) {
          expect(disabled, hasLength(1));
          expect(identical(entries.first, disabled.single), isTrue);
          expect(disabled.single.label, chooseRoundsLabel);
          expect(disabled.single.value, const RoundLimitChoice(null));
        } else {
          expect(disabled, isEmpty);
        }
      }
    },
  );

  test('test_build_round_limit_entries_property_current_value_once', () {
    final Random random = seededRandom(117918);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int? roundLimit = _randomValidLimit(random);

      final int matches = buildRoundLimitEntries(roundLimit)
          .where(
            (SelectOption<RoundLimitChoice> entry) =>
                entry.value == RoundLimitChoice(roundLimit),
          )
          .length;

      expect(matches, 1, reason: '$roundLimit');
    }
  });
}
