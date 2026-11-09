import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'random_skills.dart';
import 'skill_form_probe.dart';

typedef _TextFieldCase = ({
  String functionName,
  String label,
  int problemPlace,
  String Function(SkillDraft draft) readDraft,
  String Function(String typed) expectReported,
});

const int _ownNameIndex = 99;

String _readName(SkillDraft draft) => draft.name;

String _readSummary(SkillDraft draft) => draft.summary;

String _readInstructions(SkillDraft draft) => draft.instructions;

String _keepTyped(String typed) => typed;

String _trimTyped(String typed) => typed.trim();

const List<_TextFieldCase> _textFieldCases = <_TextFieldCase>[
  (
    functionName: 'change_name',
    label: skillNameLabel,
    problemPlace: 0,
    readDraft: _readName,
    expectReported: _keepTyped,
  ),
  (
    functionName: 'change_summary',
    label: skillSummaryLabel,
    problemPlace: 1,
    readDraft: _readSummary,
    expectReported: _trimTyped,
  ),
  (
    functionName: 'change_instructions',
    label: skillInstructionsLabel,
    problemPlace: 2,
    readDraft: _readInstructions,
    expectReported: _keepTyped,
  ),
];

String _randomTypedText(Random random, _TextFieldCase fieldCase) {
  if (fieldCase.label == skillNameLabel) {
    return randomValidSkillName(random);
  }
  if (fieldCase.label == skillInstructionsLabel) {
    return randomInstructions(random);
  }
  return ' Summary ${randomText(random)} ';
}

void _registerTextFieldProperties(_TextFieldCase fieldCase, int seed) {
  final String prefix = 'test_skill_form_${fieldCase.functionName}_property';

  testWidgets('${prefix}_typing_clears_only_its_own_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(seed);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: randomValidSkillDraft(random),
        otherSkills: const <Skill>[],
      );
      await pumpSkillFormProbe(tester, random, probe);
      await showEveryFieldProblem(tester);
      final List<String?> before = readFieldProblems(tester);

      await enterFieldText(
        tester,
        label: fieldCase.label,
        text: _randomTypedText(random, fieldCase),
      );

      final List<String?> expected = <String?>[...before];
      expected[fieldCase.problemPlace] = null;
      expect(readFieldProblems(tester), expected);
    }
  });

  testWidgets('${prefix}_reports_what_was_typed', (WidgetTester tester) async {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: randomValidSkillDraft(random),
        otherSkills: const <Skill>[],
      );
      await pumpSkillFormProbe(tester, random, probe);
      final String typed = random.nextBool()
          ? _randomTypedText(random, fieldCase)
          : randomText(random);

      await enterFieldText(tester, label: fieldCase.label, text: typed);

      expect(probe.reported, hasLength(1));
      expect(
        fieldCase.readDraft(probe.reported.single),
        fieldCase.expectReported(typed),
      );
    }
  });

  testWidgets('${prefix}_the_last_typed_text_is_saved', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> otherSkills = randomSkills(random);
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: copySkillDraft(
          randomValidSkillDraft(random),
          name: randomUniqueSkillName(random, _ownNameIndex),
        ),
        otherSkills: otherSkills,
      );
      await pumpSkillFormProbe(tester, random, probe);
      String last = fieldCase.readDraft(probe.initialSkill);
      final int typingCount = 1 + random.nextInt(3);
      for (int typing = 0; typing < typingCount; typing += 1) {
        last = _randomTypedText(random, fieldCase);
        await enterFieldText(tester, label: fieldCase.label, text: last);
      }
      final bool isTaken = otherSkills.any(
        (Skill skill) => skill.name == last,
      );

      await tapSaveSkill(tester);

      expect(probe.submitted, hasLength(isTaken ? 0 : 1));
      if (!isTaken) {
        expect(
          fieldCase.readDraft(probe.submitted.single),
          fieldCase.expectReported(last),
        );
      }
    }
  });
}

void main() {
  int seed = 1120801;
  for (final _TextFieldCase fieldCase in _textFieldCases) {
    _registerTextFieldProperties(fieldCase, seed);
    seed += 10;
  }

  testWidgets('test_skill_form_change_name_property_a_taken_name_waits_for_'
      'a_free_one', (WidgetTester tester) async {
    final Random random = seededRandom(1120831);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> otherSkills = randomSkills(random);
      final Skill taken = pickOne(random, otherSkills);
      final SkillFormProbe probe = SkillFormProbe(
        initialSkill: randomValidSkillDraft(random),
        otherSkills: otherSkills,
      );
      await pumpSkillFormProbe(tester, random, probe);
      await enterFieldText(tester, label: skillNameLabel, text: taken.name);
      await tapSaveSkill(tester);
      expect(
        readFieldProblem(tester, skillNameLabel),
        'A skill named ${taken.name} already exists',
      );

      final String free = 'free-$i';
      await enterFieldText(tester, label: skillNameLabel, text: free);
      await tapSaveSkill(tester);

      expect(probe.submitted, hasLength(1));
      expect(probe.submitted.single.name, free);
    }
  });
}
