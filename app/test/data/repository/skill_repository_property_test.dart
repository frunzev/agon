import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/skill_inputs.dart';
import 'support/contract_step_failures.dart';
import 'support/skill_contract_rigs.dart';
import 'support/skill_contract_steps.dart';

const String _typePrefix = 'test_skill_repository';
const int _sequenceIterations = 25;
const int _longestSequence = 8;

int _randomStepCount(Random random) => 1 + random.nextInt(_longestSequence);

Future<SkillContractWorld> _openAfterRandomSteps(Random random) async {
  final SkillContractWorld world = await openSkillContractWorld(random);
  await performRandomSkillSteps(
    random,
    world,
    stepCount: random.nextInt(_longestSequence),
  );
  return world;
}

Future<void> _expectNotFoundEverywhere(
  SkillContractWorld world,
  SkillId skillId,
) async {
  for (final NamedSkillRepository implementation in world.implementations) {
    final Object? failure = await findStepFailure(
      () async => implementation.repository.findSkill(skillId),
    );
    expect(failure, isA<RecordNotFound>(), reason: implementation.name);
  }
}

void main() {
  test('${_typePrefix}_list_skills_property_every_implementation_lists_'
      'the_same_skills', () async {
    final Random random = seededRandom(86101);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SkillContractWorld world = await openSkillContractWorld(random);
      expectSkillListingsAgree(world);

      await performRandomSkillSteps(
        random,
        world,
        stepCount: _randomStepCount(random),
      );
      closeSkillContractWorld(world);
    }
  });

  test('${_typePrefix}_list_skills_property_lists_unique_names_seen_in_the_'
      'current_workspace', () async {
    final Random random = seededRandom(86102);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SkillContractWorld world = await _openAfterRandomSteps(random);
      final WorkspaceId here = world.rig.workspaces.currentWorkspace().id;

      for (final NamedSkillRepository implementation
          in world.implementations) {
        final List<Skill> listed = implementation.repository.listSkills();
        final Set<String> names = <String>{
          for (final Skill skill in listed) skill.name,
        };
        expect(names, hasLength(listed.length), reason: implementation.name);
        for (final Skill skill in listed) {
          expect(isScopeSeenInWorkspace(skill.scope, here), isTrue);
        }
      }
      closeSkillContractWorld(world);
    }
  });

  test('${_typePrefix}_list_skills_property_callers_cannot_change_the_'
      'listing', () async {
    final Random random = seededRandom(86103);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SkillContractWorld world = await _openAfterRandomSteps(random);

      for (final NamedSkillRepository implementation
          in world.implementations) {
        final List<Skill> listed = implementation.repository.listSkills();
        final List<String> before = describeListedSkills(
          implementation.repository,
        );
        final Object? failure = await findStepFailure(() async {
          listed.clear();
        });

        expect(failure, isA<UnsupportedError>(), reason: implementation.name);
        expect(describeListedSkills(implementation.repository), before);
      }
      closeSkillContractWorld(world);
    }
  });

  test('${_typePrefix}_find_skill_property_finds_every_listed_skill_'
      'unchanged', () async {
    final Random random = seededRandom(86104);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SkillContractWorld world = await _openAfterRandomSteps(random);

      for (final NamedSkillRepository implementation
          in world.implementations) {
        for (final Skill listed in implementation.repository.listSkills()) {
          final Skill found = implementation.repository.findSkill(listed.id);
          expect(found.id, listed.id, reason: implementation.name);
          expect(describeSkillContent(found), describeSkillContent(listed));
        }
      }
      closeSkillContractWorld(world);
    }
  });

  test('${_typePrefix}_find_skill_property_missing_skills_are_not_found_'
      'anywhere', () async {
    final Random random = seededRandom(86105);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SkillContractWorld world = await _openAfterRandomSteps(random);

      await _expectNotFoundEverywhere(
        world,
        missingSkillTarget(random).fixedId,
      );
      closeSkillContractWorld(world);
    }
  });

  test('${_typePrefix}_find_skill_property_skills_outside_the_workspace_are_'
      'not_found', () async {
    final Random random = seededRandom(86106);
    int checkedCount = 0;
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SkillContractWorld world = await _openAfterRandomSteps(random);

      for (final SkillId skillId in listUnlistedSeededSkillIds(world)) {
        checkedCount += 1;
        await _expectNotFoundEverywhere(world, skillId);
      }
      closeSkillContractWorld(world);
    }
    expect(checkedCount, greaterThan(0));
  });

  test('${_typePrefix}_create_skill_property_every_implementation_agrees_'
      'on_the_outcome', () async {
    final Random random = seededRandom(86107);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SkillContractWorld world = await openSkillContractWorld(random);
      final int stepCount = _randomStepCount(random);

      for (int step = 0; step < stepCount; step += 1) {
        expectSkillOutcomesAgree(
          await createRandomlyOnEverySkillRepository(random, world),
        );
        expectSkillListingsAgree(world);
      }
      closeSkillContractWorld(world);
    }
  });

  test('${_typePrefix}_create_skill_property_keeps_the_draft_and_lists_it_'
      'only_where_seen', () async {
    final Random random = seededRandom(86108);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SkillContractWorld world = await _openAfterRandomSteps(random);
      final WorkspaceId here = world.rig.workspaces.currentWorkspace().id;
      final SkillDraft draft = randomContractSkillDraft(
        random,
        world,
        name: randomValidSkillName(random),
        instructions: randomText(random),
      );
      final List<Skill> before = world.rig.skills.listSkills();
      final bool isNameTaken = before.any(
        (Skill skill) => skill.name == draft.name,
      );

      final List<SkillOutcome> outcomes = await createOnEverySkillRepository(
        world,
        draft,
      );

      expectSkillOutcomesAgree(outcomes);
      expect(isSkillRefused(outcomes), isNameTaken);
      final bool isSeenHere = isScopeSeenInWorkspace(draft.scope, here);
      for (final NamedSkillRepository implementation
          in world.implementations) {
        final Skill? listed = findListedSkillNamed(
          implementation.repository,
          draft.name,
        );
        if (isNameTaken) {
          continue;
        }
        expect(listed != null, isSeenHere, reason: implementation.name);
        if (listed != null) {
          expect(listed.summary, draft.summary);
          expect(listed.instructions, draft.instructions);
          expect(listed.usage, draft.usage);
          expect(listed.improvement, draft.improvement);
          expect(listed.source, SkillSource.created);
          expect(listed.history, isEmpty);
        }
      }
      closeSkillContractWorld(world);
    }
  });

  test('${_typePrefix}_create_skill_property_invalid_or_taken_names_change_'
      'nothing', () async {
    final Random random = seededRandom(86109);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final SkillContractWorld world = await _openAfterRandomSteps(random);
      final List<Skill> listed = world.rig.skills.listSkills();
      final String name = listed.isNotEmpty && random.nextBool()
          ? pickOne(random, listed).name
          : randomInvalidSkillName(random);
      final List<String> before = describeListedSkills(world.rig.skills);

      final List<SkillOutcome> outcomes = await createOnEverySkillRepository(
        world,
        randomContractSkillDraft(
          random,
          world,
          name: name,
          instructions: randomText(random),
        ),
      );

      expectSkillOutcomesAgree(outcomes);
      expect(isSkillRefused(outcomes), isTrue);
      for (final NamedSkillRepository implementation
          in world.implementations) {
        expect(
          describeListedSkills(implementation.repository),
          orderedEquals(before),
          reason: implementation.name,
        );
      }
      closeSkillContractWorld(world);
    }
  });
}
