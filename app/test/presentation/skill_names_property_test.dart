import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/presentation/skill_names.dart';

import '../bridge/support/node_json_primitives.dart';
import '../support/random_inputs.dart';
import '../support/random_scope_catalogs.dart';
import '../support/sample_scopes.dart';

const int _mostSkills = 6;

Skill _namedSkill(SkillId skillId, String name) {
  return Skill(
    id: skillId,
    name: name,
    summary: '',
    instructions: '',
    scope: const Scope.everywhere(),
    usage: SkillUsage.whenChosen,
    source: SkillSource.created,
    improvement: SkillImprovement.never,
    history: const <SkillChange>[],
  );
}

List<Skill> _randomSkills(Random random) {
  final int skillCount = random.nextInt(_mostSkills + 1);
  return <Skill>[
    for (int i = 0; i < skillCount; i += 1)
      _namedSkill(
        SkillId(randomUuidText(random)),
        randomUniqueHostileName(random, i),
      ),
  ];
}

List<SkillId> _listIds(List<Skill> skills) {
  return <SkillId>[for (final Skill skill in skills) skill.id];
}

SkillId _randomUnknownSkillId(Random random) {
  return SkillId('unknown-${randomUuidText(random)}');
}

void main() {
  test('test_describe_skill_names_property_names_exactly_chosen_skills', () {
    final Random random = seededRandom(94401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> skills = _randomSkills(random);
      final List<Skill> chosen = pickSome(random, skills);

      final List<String> names = describeSkillNames(
        skills: skills,
        skillIds: _listIds(chosen),
      );

      expect(names.toSet(), <String>{
        for (final Skill skill in chosen) skill.name,
      });
      expect(names.length, chosen.length);
    }
  });

  test('test_describe_skill_names_property_repeats_and_unknowns_add_none', () {
    final Random random = seededRandom(94402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> skills = _randomSkills(random);
      final List<SkillId> chosenIds = _listIds(pickSome(random, skills));
      final List<SkillId> noisyIds = <SkillId>[
        ...chosenIds,
        _randomUnknownSkillId(random),
        ...chosenIds,
      ];

      expect(
        describeSkillNames(skills: skills, skillIds: noisyIds),
        describeSkillNames(skills: skills, skillIds: chosenIds),
      );
      expect(
        describeSkillNames(skills: skills, skillIds: const <SkillId>[]),
        isEmpty,
      );
    }
  });

  test('test_describe_skill_names_property_order_of_ids_is_irrelevant', () {
    final Random random = seededRandom(94403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> skills = _randomSkills(random);
      final List<SkillId> chosenIds = _listIds(pickSome(random, skills));
      final List<SkillId> shuffledIds = List<SkillId>.of(chosenIds);
      shuffledIds.shuffle(random);

      expect(
        describeSkillNames(skills: skills, skillIds: shuffledIds),
        describeSkillNames(skills: skills, skillIds: chosenIds),
      );
    }
  });

  test('test_find_skill_id_by_name_property_round_trips_skill_names', () {
    final Random random = seededRandom(94404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> skills = _randomSkills(random);

      for (final Skill skill in skills) {
        final SkillId foundId = findSkillIdByName(
          skills: skills,
          skillName: skill.name,
        );

        expect(foundId, skill.id);
        expect(
          describeSkillNames(skills: skills, skillIds: <SkillId>[foundId]),
          <String>[skill.name],
        );
      }
    }
  });

  test('test_find_skill_id_by_name_property_only_exact_names_match', () {
    final Random random = seededRandom(94405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> skills = _randomSkills(random);
      if (skills.isEmpty) {
        continue;
      }
      final Skill skill = pickOne(random, skills);
      final String nearMiss = pickOne(random, <String>[
        ' ${skill.name}',
        '${skill.name} ',
        '${skill.name}x',
        skill.id.value,
      ]);

      expect(
        () => findSkillIdByName(skills: skills, skillName: nearMiss),
        throwsArgumentError,
      );
    }
  });

  test('test_find_skill_id_by_name_property_no_skills_finds_nothing', () {
    final Random random = seededRandom(94406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String skillName = randomText(random);

      expect(
        () => findSkillIdByName(skills: const <Skill>[], skillName: skillName),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.invalidValue,
            'invalidValue',
            skillName,
          ),
        ),
      );
    }
  });
}
