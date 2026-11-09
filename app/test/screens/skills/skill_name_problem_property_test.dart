import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/skill_names.dart';
import 'package:agent_orchestration/screens/skills/skill_name_problem.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../data/rules/support/mirrored_rule_tables.dart';
import '../../support/random_inputs.dart';
import 'random_skills.dart';

String? _describeRepositoryRefusal({
  required String name,
  required List<Skill> existingSkills,
}) {
  try {
    requireValidSkillName(name);
    requireFreeSkillName(name: name, otherSkills: existingSkills);
  } on Object catch (problem) {
    if (problem is! PeopleFacingRefusal) {
      rethrow;
    }
    return problem.message;
  }
  return null;
}

String _randomCandidateName(Random random, List<Skill> existingSkills) {
  final int choice = random.nextInt(4);
  if (choice == 0) {
    return pickOne(random, existingSkills).name;
  }
  if (choice == 1) {
    return randomValidSkillName(random);
  }
  if (choice == 2) {
    final String taken = pickOne(random, existingSkills).name;
    return '${randomHostileText(random)}$taken';
  }
  return randomHostileText(random);
}

Skill _buildSkillNamed(Random random, String name, int index) {
  return randomSkill(random, id: SkillId('named-$index'), name: name);
}

void main() {
  final List<SharedNamingCase> sharedCases = readSharedNamingCases();

  test('test_describe_skill_name_problem_property_agrees_with_the_shared_'
      'naming_table', () {
    final Random random = seededRandom(1120401);

    for (final SharedNamingCase sharedCase in sharedCases) {
      final List<Skill> others = <Skill>[
        for (final Skill skill in randomSkills(random))
          if (skill.name != sharedCase.name) skill,
      ];

      final String? problem = describeSkillNameProblem(
        name: sharedCase.name,
        existingSkills: others,
      );

      final String reason = sharedCase.name.runes.toString();
      expect(problem, describeNameProblem(sharedCase.name), reason: reason);
      expect(problem == null, sharedCase.problem == null, reason: reason);
    }
  });

  test('test_describe_skill_name_problem_property_agrees_with_the_'
      'repository_name_rules', () {
    final Random random = seededRandom(1120402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> existingSkills = randomSkills(random);
      final String name = _randomCandidateName(random, existingSkills);

      final String? problem = describeSkillNameProblem(
        name: name,
        existingSkills: existingSkills,
      );

      final String? refusal = _describeRepositoryRefusal(
        name: name,
        existingSkills: existingSkills,
      );
      expect(problem, refusal, reason: name.runes.toString());
    }
  });

  test('test_describe_skill_name_problem_property_only_an_exact_valid_'
      'match_is_taken', () {
    final Random random = seededRandom(1120403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomValidSkillName(random);
      final List<Skill> unrelated = <Skill>[
        for (final Skill skill in randomSkills(random))
          if (skill.name != name) skill,
      ];
      final List<Skill> withTwin = <Skill>[
        ...unrelated,
        _buildSkillNamed(random, name, i),
      ];

      final String? free = describeSkillNameProblem(
        name: name,
        existingSkills: unrelated,
      );
      final String? taken = describeSkillNameProblem(
        name: name,
        existingSkills: withTwin,
      );
      final String? spaced = describeSkillNameProblem(
        name: ' $name',
        existingSkills: withTwin,
      );

      expect(free, isNull, reason: name);
      expect(taken, 'A skill named $name already exists');
      expect(spaced, describeNameProblem(' $name'));
      expect(spaced, isNot(taken));
    }
  });
}
