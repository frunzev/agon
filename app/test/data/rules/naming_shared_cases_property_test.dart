import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/naming.dart';

import '../../support/random_inputs.dart';
import 'support/mirrored_rule_tables.dart';

const Map<String, String> _problemByKind = <String, String>{
  'empty': 'Give it a name',
  'invalid_character': 'Use lowercase letters, digits and dashes',
  'too_long': 'Use at most $nameMaximumLength characters',
};
const String _nameCharacters = 'abcdefghijklmnopqrstuvwxyz0123456789-';
const List<String> _foreignCharacters = <String>[
  'A',
  ' ',
  '_',
  'é',
  '\u212A',
  '😀',
  '\n',
  '\u0000',
];

String? _describeKind(String? kind) {
  if (kind == null) {
    return null;
  }
  return _problemByKind[kind]!;
}

String _randomNameOfLength(Random random, int length) {
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    buffer.write(_nameCharacters[random.nextInt(_nameCharacters.length)]);
  }
  return buffer.toString();
}

void main() {
  final List<SharedNamingCase> sharedCases = readSharedNamingCases();

  test('test_describe_name_problem_property_agrees_with_shared_table', () {
    for (final SharedNamingCase sharedCase in sharedCases) {
      final String? problem = describeNameProblem(sharedCase.name);

      final String? expected = _describeKind(sharedCase.problem);
      expect(problem, expected, reason: sharedCase.name.runes.toString());
    }
  });

  test('test_convert_to_project_name_property_agrees_with_shared_table', () {
    for (final SharedNamingCase sharedCase in sharedCases) {
      final String projectName = convertToProjectName(sharedCase.name);

      final String reason = sharedCase.name.runes.toString();
      expect(projectName, sharedCase.projectName, reason: reason);
    }
  });

  test('test_describe_name_problem_property_character_beats_length', () {
    final Random random = seededRandom(87011);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int length = nameMaximumLength + 1 + random.nextInt(30);
      final String name = _randomNameOfLength(random, length);
      final int cut = random.nextInt(name.length + 1);
      final String foreign = pickOne(random, _foreignCharacters);
      final String spoiled =
          '${name.substring(0, cut)}$foreign${name.substring(cut)}';

      final String? problem = describeNameProblem(spoiled);

      expect(problem, _problemByKind['invalid_character'], reason: spoiled);
    }
  });

  test('test_describe_name_problem_property_accepts_exactly_the_limit', () {
    final Random random = seededRandom(87012);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int length = 1 + random.nextInt(nameMaximumLength * 2);
      final String name = _randomNameOfLength(random, length);

      final String? problem = describeNameProblem(name);

      final bool fits = length <= nameMaximumLength;
      expect(problem, fits ? null : _problemByKind['too_long'], reason: name);
    }
  });
}
