import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/rules/skill_names.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/skill_inputs.dart';
import 'support/mirrored_rule_tables.dart';

const List<String> _nameNeighbourEndings = <String>['-', '2', 'x', '-copy'];

Skill _renameSkill(Skill skill, String name) {
  return Skill(
    id: skill.id,
    name: name,
    summary: skill.summary,
    instructions: skill.instructions,
    scope: skill.scope,
    usage: skill.usage,
    source: skill.source,
    improvement: skill.improvement,
    history: skill.history,
  );
}

List<Skill> _randomNamedSkills(Random random) {
  return <Skill>[
    for (final Skill skill in randomSeededSkills(random))
      _renameSkill(skill, randomValidSkillName(random)),
  ];
}

Matcher _expectFreedom({required bool isTaken}) {
  if (isTaken) {
    return throwsStateError;
  }
  return returnsNormally;
}

bool _isNameListed(String name, List<Skill> skills) {
  return skills.any((Skill skill) => skill.name == name);
}

String _randomNeighbourName(Random random, String name) {
  final String ending = pickOne(random, _nameNeighbourEndings);
  switch (random.nextInt(3)) {
    case 0:
      return '$name$ending';
    case 1:
      return '$ending$name';
    default:
      return name.toUpperCase();
  }
}

void main() {
  test('test_require_valid_skill_name_property_agrees_with_the_naming_'
      'table', () {
    for (final SharedNamingCase sharedCase in readSharedNamingCases()) {
      final Matcher expected = sharedCase.problem == null
          ? returnsNormally
          : throwsArgumentError;

      expect(
        () => requireValidSkillName(sharedCase.name),
        expected,
        reason: sharedCase.name,
      );
    }
  });

  test('test_require_free_skill_name_property_ignores_the_skill_order', () {
    final Random random = seededRandom(57401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> otherSkills = _randomNamedSkills(random);
      final List<Skill> shuffled = List<Skill>.of(otherSkills);
      shuffled.shuffle(random);
      final String name = otherSkills.isNotEmpty && random.nextBool()
          ? pickOne(random, otherSkills).name
          : randomValidSkillName(random);

      final bool isTaken = _isNameListed(name, otherSkills);

      expect(
        () => requireFreeSkillName(name: name, otherSkills: shuffled),
        _expectFreedom(isTaken: isTaken),
        reason: name,
      );
    }
  });

  test('test_require_free_skill_name_property_near_names_stay_free', () {
    final Random random = seededRandom(57402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String takenName = randomValidSkillName(random);
      final List<Skill> otherSkills = <Skill>[
        for (final Skill skill in randomSeededSkills(random))
          _renameSkill(skill, takenName),
      ];
      final String neighbourName = _randomNeighbourName(random, takenName);
      if (neighbourName == takenName) {
        continue;
      }

      expect(
        () => requireFreeSkillName(
          name: neighbourName,
          otherSkills: otherSkills,
        ),
        returnsNormally,
        reason: neighbourName,
      );
      expect(
        () => requireFreeSkillName(name: takenName, otherSkills: otherSkills),
        _expectFreedom(isTaken: otherSkills.isNotEmpty),
        reason: takenName,
      );
    }
  });

  test('test_require_free_skill_name_property_no_skills_free_every_name', () {
    final Random random = seededRandom(57403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = random.nextBool()
          ? randomText(random)
          : randomValidSkillName(random);

      expect(
        () => requireFreeSkillName(name: name, otherSkills: const <Skill>[]),
        returnsNormally,
        reason: name,
      );
    }
  });
}
