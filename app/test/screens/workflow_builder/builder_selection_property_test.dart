import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';

AgentConnection _randomConnection(Random random) {
  final bool isLoop = random.nextBool();
  return AgentConnection(
    from: WorkflowAgentId('from-${randomText(random)}'),
    to: WorkflowAgentId('to-${randomText(random)}'),
    condition: isLoop ? pickOne(random, sampleOutcomes) : null,
    roundLimit: isLoop ? 1 + random.nextInt(mostRoundsInATest) : null,
  );
}

BuilderSelection? _randomSelection(Random random) {
  final AgentConnection connection = _randomConnection(random);
  return pickOne<BuilderSelection?>(random, <BuilderSelection?>[
    null,
    SelectedStep(WorkflowAgentId('step-${randomText(random)}')),
    SelectedConnection(connection),
    DrawnLoop(connection),
  ]);
}

int _countFound(BuilderSelection? selection) {
  final List<Object?> found = <Object?>[
    findSelectedStepId(selection),
    findSelectedConnection(selection),
    findDrawnLoop(selection),
  ];
  int count = 0;
  for (final Object? value in found) {
    if (value != null) {
      count += 1;
    }
  }
  return count;
}

void main() {
  test('test_find_selected_step_id_property_round_trips_the_step', () {
    final Random random = seededRandom(1161601);
    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgentId agentId = WorkflowAgentId(randomText(random));

      expect(findSelectedStepId(SelectedStep(agentId)), agentId);
    }
  });

  test('test_find_selected_step_id_property_only_steps_have_one', () {
    final Random random = seededRandom(1161602);
    for (int i = 0; i < propertyIterations; i += 1) {
      final BuilderSelection? selection = _randomSelection(random);

      final WorkflowAgentId? found = findSelectedStepId(selection);

      expect(found != null, selection is SelectedStep);
    }
  });

  test('test_find_selected_step_id_property_one_finder_answers_at_most', () {
    final Random random = seededRandom(1161603);
    for (int i = 0; i < propertyIterations; i += 1) {
      final BuilderSelection? selection = _randomSelection(random);

      expect(_countFound(selection), selection == null ? 0 : 1);
    }
  });

  test('test_find_selected_connection_property_round_trips_fields', () {
    final Random random = seededRandom(1161604);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentConnection connection = _randomConnection(random);

      final AgentConnection? found = findSelectedConnection(
        SelectedConnection(connection),
      );

      expect(found, connection);
      expect(found!.condition, connection.condition);
      expect(found.roundLimit, connection.roundLimit);
    }
  });

  test('test_find_selected_connection_property_only_connections_have_one', () {
    final Random random = seededRandom(1161605);
    for (int i = 0; i < propertyIterations; i += 1) {
      final BuilderSelection? selection = _randomSelection(random);

      final AgentConnection? found = findSelectedConnection(selection);

      expect(found != null, selection is SelectedConnection);
    }
  });

  test('test_find_selected_connection_property_drawn_loop_is_not_chosen', () {
    final Random random = seededRandom(1161606);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentConnection connection = _randomConnection(random);

      expect(findSelectedConnection(DrawnLoop(connection)), isNull);
      expect(findSelectedStepId(DrawnLoop(connection)), isNull);
    }
  });

  test('test_find_drawn_loop_property_round_trips_the_loop', () {
    final Random random = seededRandom(1161607);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentConnection connection = _randomConnection(random);

      expect(findDrawnLoop(DrawnLoop(connection)), connection);
    }
  });

  test('test_find_drawn_loop_property_only_drawn_loops_have_one', () {
    final Random random = seededRandom(1161608);
    for (int i = 0; i < propertyIterations; i += 1) {
      final BuilderSelection? selection = _randomSelection(random);

      final AgentConnection? found = findDrawnLoop(selection);

      expect(found != null, selection is DrawnLoop);
    }
  });

  test('test_find_drawn_loop_property_nothing_selected_finds_nothing', () {
    expect(findDrawnLoop(null), isNull);
    expect(findSelectedConnection(null), isNull);
    expect(findSelectedStepId(null), isNull);
  });
}
