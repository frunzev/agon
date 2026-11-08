import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/rules/skill_undo.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/skill_inputs.dart';

SkillChange _randomChangeFrom(Random random, SkillChangeOrigin origin) {
  return SkillChange(
    origin: origin,
    savedAt: randomUtcMoment(random),
    replacedInstructions: randomText(random),
  );
}

AgentRunOrigin _randomAgentOrigin(Random random) {
  final RunId runId = RunId('run-${random.nextInt(1000)}');
  return random.nextBool()
      ? ApprovedAgentRun(runId)
      : AutomaticAgentRun(runId);
}

void main() {
  test('test_find_undoable_agent_change_property_a_person_edit_on_top_'
      'blocks_undo', () {
    final Random random = seededRandom(31907);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SkillChange> history = <SkillChange>[
        ...randomSkillHistory(random),
        _randomChangeFrom(random, const PersonEdit()),
      ];

      expect(findUndoableAgentChange(history), isNull);
    }
  });

  test('test_find_undoable_agent_change_property_a_new_agent_change_is_'
      'the_one_undone', () {
    final Random random = seededRandom(31908);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillChange agentChange = _randomChangeFrom(
        random,
        _randomAgentOrigin(random),
      );
      final List<SkillChange> history = <SkillChange>[
        ...randomSkillHistory(random),
        agentChange,
      ];

      expect(findUndoableAgentChange(history), same(agentChange));
    }
  });

  test('test_find_undoable_agent_change_property_older_changes_never_'
      'matter', () {
    final Random random = seededRandom(31909);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillChange newest = _randomChangeFrom(
        random,
        randomSkillChangeOrigin(random),
      );
      final List<SkillChange> firstHistory = <SkillChange>[
        ...randomSkillHistory(random),
        newest,
      ];
      final List<SkillChange> secondHistory = <SkillChange>[
        ...randomSkillHistory(random),
        newest,
      ];

      expect(
        findUndoableAgentChange(firstHistory),
        same(findUndoableAgentChange(secondHistory)),
      );
      expect(findUndoableAgentChange(const <SkillChange>[]), isNull);
    }
  });
}
