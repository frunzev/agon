import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/skill_repository_rig.dart';
import 'support/contract_step_failures.dart';
import 'support/skill_contract_rigs.dart';
import 'support/skill_contract_steps.dart';

const String _typePrefix = 'test_skill_repository';
const int _sequenceIterations = 25;
const int _longestSequence = 8;

typedef _SkillTargetAction = Future<List<SkillOutcome>> Function(
  Random random,
  SkillContractWorld world,
  SkillTarget target,
);

Future<SkillContractWorld> _openAfterRandomSteps(Random random) async {
  final SkillContractWorld world = await openSkillContractWorld(random);
  await performRandomSkillSteps(
    random,
    world,
    stepCount: random.nextInt(_longestSequence),
  );
  return world;
}

Future<List<SkillOutcome>> _update(
  Random random,
  SkillContractWorld world,
  SkillTarget target,
) {
  return updateOnEverySkillRepository(random, world, target);
}

Future<List<SkillOutcome>> _delete(
  Random random,
  SkillContractWorld world,
  SkillTarget target,
) {
  return deleteOnEverySkillRepository(world, target);
}

Future<List<SkillOutcome>> _undo(
  Random random,
  SkillContractWorld world,
  SkillTarget target,
) {
  return undoOnEverySkillRepository(world, target);
}

Future<void> _expectAgreementOnRandomTargets(
  int seed,
  _SkillTargetAction action,
) async {
  final Random random = seededRandom(seed);
  for (int i = 0; i < _sequenceIterations; i += 1) {
    final SkillContractWorld world = await openSkillContractWorld(random);
    final int stepCount = 1 + random.nextInt(_longestSequence);

    for (int step = 0; step < stepCount; step += 1) {
      final SkillTarget target = pickSkillTarget(random, world);
      expectSkillOutcomesAgree(await action(random, world, target));
      expectSkillListingsAgree(world);
    }
    closeSkillContractWorld(world);
  }
}

SkillTarget _refusedTarget(Random random, SkillContractWorld world) {
  final List<SkillId> unlisted = listUnlistedSeededSkillIds(world);
  if (unlisted.isEmpty || random.nextBool()) {
    return missingSkillTarget(random);
  }
  return (listedName: null, fixedId: pickOne(random, unlisted));
}

Future<void> _expectRefusedTargetsChangeNothing(
  int seed,
  _SkillTargetAction action,
) async {
  final Random random = seededRandom(seed);
  for (int i = 0; i < _sequenceIterations; i += 1) {
    final SkillContractWorld world = await _openAfterRandomSteps(random);
    final List<String> listingBefore = describeListedSkills(world.rig.skills);
    final List<Skill> nodeSkillsBefore = readNodeSkills(world.rig);

    final List<SkillOutcome> outcomes = await action(
      random,
      world,
      _refusedTarget(random, world),
    );

    expectSkillOutcomesAgree(outcomes);
    expect(isSkillRefused(outcomes), isTrue);
    expectSkillListingsAgree(world);
    expect(describeListedSkills(world.rig.skills), listingBefore);
    expect(
      <String>[
        for (final Skill skill in readNodeSkills(world.rig)) skill.id.value,
      ],
      <String>[for (final Skill skill in nodeSkillsBefore) skill.id.value],
    );
    closeSkillContractWorld(world);
  }
}

SkillTarget? _pickListedTarget(Random random, SkillContractWorld world) {
  final List<Skill> listed = world.rig.skills.listSkills();
  if (listed.isEmpty) {
    return null;
  }
  final Skill chosen = pickOne(random, listed);
  return (listedName: chosen.name, fixedId: chosen.id);
}

List<String> _describeHistoryModel(List<SkillChange> history) {
  return <String>[
    for (final SkillChange change in history) change.replacedInstructions,
  ];
}

void main() {
  test('${_typePrefix}_update_skill_property_every_implementation_agrees_'
      'on_the_outcome', () async {
    await _expectAgreementOnRandomTargets(86201, _update);
  });

  test('${_typePrefix}_update_skill_property_history_grows_only_when_'
      'instructions_change', () async {
    final Random random = seededRandom(86202);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SkillContractWorld world = await _openAfterRandomSteps(random);
      final SkillTarget? target = _pickListedTarget(random, world);
      if (target == null) {
        closeSkillContractWorld(world);
        continue;
      }
      final Skill before = world.rig.skills.findSkill(target.fixedId);
      final bool isChangingInstructions = random.nextBool();
      final String instructions = isChangingInstructions
          ? '${before.instructions} ${randomText(random)} changed'
          : before.instructions;
      final SkillDraft draft = SkillDraft(
        name: before.name,
        summary: randomText(random),
        instructions: instructions,
        scope: before.scope,
        usage: pickOne(random, SkillUsage.values),
        improvement: pickOne(random, SkillImprovement.values),
      );

      final List<SkillOutcome> outcomes =
          await updateWithDraftOnEverySkillRepository(world, target, draft);

      expectSkillOutcomesAgree(outcomes);
      expect(isSkillRefused(outcomes), isFalse);
      final List<String> expectedHistory = <String>[
        ..._describeHistoryModel(before.history),
        if (isChangingInstructions) before.instructions,
      ];
      final int excess = max(0, expectedHistory.length - rustKeptSkillChanges);
      final Skill after = world.rig.skills.findSkill(target.fixedId);
      expect(
        _describeHistoryModel(after.history),
        expectedHistory.sublist(excess),
      );
      expect(after.instructions, instructions);
      expect(after.source, before.source);
      if (isChangingInstructions) {
        expect(after.history.last.origin, isA<PersonEdit>());
      }
      closeSkillContractWorld(world);
    }
  });

  test('${_typePrefix}_update_skill_property_refused_targets_change_'
      'nothing', () async {
    await _expectRefusedTargetsChangeNothing(86203, _update);
  });

  test('${_typePrefix}_delete_skill_property_every_implementation_agrees_'
      'on_the_outcome', () async {
    await _expectAgreementOnRandomTargets(86204, _delete);
  });

  test('${_typePrefix}_delete_skill_property_removes_exactly_the_deleted_'
      'skill', () async {
    final Random random = seededRandom(86205);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SkillContractWorld world = await _openAfterRandomSteps(random);
      final SkillTarget? target = _pickListedTarget(random, world);
      if (target == null) {
        closeSkillContractWorld(world);
        continue;
      }
      final Skill doomed = world.rig.skills.findSkill(target.fixedId);
      final List<String> expected = describeListedSkills(world.rig.skills);
      expected.remove(describeSkillContent(doomed));

      final List<SkillOutcome> outcomes = await deleteOnEverySkillRepository(
        world,
        target,
      );

      expectSkillOutcomesAgree(outcomes);
      expect(isSkillRefused(outcomes), isFalse);
      for (final NamedSkillRepository implementation
          in world.implementations) {
        expect(describeListedSkills(implementation.repository), expected);
        expect(
          findListedSkillNamed(implementation.repository, doomed.name),
          isNull,
        );
      }
      final Object? failure = await findStepFailure(
        () async => world.rig.skills.findSkill(doomed.id),
      );
      expect(failure, isA<RecordNotFound>());
      closeSkillContractWorld(world);
    }
  });

  test('${_typePrefix}_delete_skill_property_refused_targets_change_'
      'nothing', () async {
    await _expectRefusedTargetsChangeNothing(86206, _delete);
  });

  test('${_typePrefix}_undo_latest_agent_change_property_every_'
      'implementation_agrees_on_the_outcome', () async {
    await _expectAgreementOnRandomTargets(86207, _undo);
  });

  test('${_typePrefix}_undo_latest_agent_change_property_walks_back_agent_'
      'changes_only', () async {
    final Random random = seededRandom(86208);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SkillContractWorld world = await _openAfterRandomSteps(random);
      final SkillTarget? target = _pickListedTarget(random, world);
      if (target == null) {
        closeSkillContractWorld(world);
        continue;
      }
      final int undoCount = 1 + random.nextInt(_longestSequence);

      for (int undo = 0; undo < undoCount; undo += 1) {
        final Skill before = world.rig.skills.findSkill(target.fixedId);
        final bool isUndoable =
            before.history.isNotEmpty &&
            before.history.last.origin is AgentRunOrigin;

        final List<SkillOutcome> outcomes = await undoOnEverySkillRepository(
          world,
          target,
        );

        expectSkillOutcomesAgree(outcomes);
        expectSkillListingsAgree(world);
        expect(isSkillRefused(outcomes), !isUndoable);
        final Skill after = world.rig.skills.findSkill(target.fixedId);
        if (!isUndoable) {
          expect(describeSkillContent(after), describeSkillContent(before));
          continue;
        }
        expect(after.instructions, before.history.last.replacedInstructions);
        expect(
          _describeHistoryModel(after.history),
          _describeHistoryModel(before.history)
              .sublist(0, before.history.length - 1),
        );
      }
      closeSkillContractWorld(world);
    }
  });

  test('${_typePrefix}_undo_latest_agent_change_property_refused_targets_'
      'change_nothing', () async {
    await _expectRefusedTargetsChangeNothing(86209, _undo);
  });
}
