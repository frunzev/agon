import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/random_inputs.dart';

const String _actionLabel = 'Save';
const List<String> _blankTexts = <String>[
  '',
  ' ',
  '\t',
  '\n',
  ' \r\n ',
  ' ',
  ' 　',
];

String _randomBlankText(Random random) {
  final int pieceCount = 1 + random.nextInt(3);
  final StringBuffer blank = StringBuffer();
  for (int i = 0; i < pieceCount; i += 1) {
    blank.write(pickOne(random, _blankTexts));
  }
  return blank.toString();
}

Object _throwDartCollectionError(Random random) {
  final int numberCount = random.nextInt(2) * 2;
  final List<int> numbers = <int>[for (int i = 0; i < numberCount; i += 1) i];
  final List<int Function()> mistakes = <int Function()>[
    () => numbers.single,
    () => <int>[].first,
    () => <int>[].last,
    () => <int>[].reduce((int left, int right) => left + right),
  ];
  try {
    pickOne(random, mistakes)();
  } on Object catch (problem) {
    return problem;
  }
  fail('the mistake did not throw');
}

Object _randomCoreError(Random random) {
  final String text = randomHostileText(random);
  return pickOne(random, <Object>[
    StateError(text),
    StateError('No element'),
    ArgumentError(text),
    ArgumentError.value(text, 'name', text),
    ConcurrentModificationError(),
    _throwDartCollectionError(random),
  ]);
}

void main() {
  test('test_describe_problem_for_people_property_blank_refusals_are_'
      'unexplained', () {
    final Random random = seededRandom(615301);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String blank = _randomBlankText(random);

      expect(describeProblemForPeople(PeopleFacingRefusal(blank)), isNull);
    }
  });

  test('test_describe_problem_for_people_property_core_errors_are_bugs', () {
    final Random random = seededRandom(615302);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Object problem = _randomCoreError(random);

      expect(describeProblemForPeople(problem), isNull, reason: '$problem');
    }
  });

  test('test_describe_problem_for_people_property_core_errors_are_'
      'rethrown', () async {
    final Random random = seededRandom(615303);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Object problem = _randomCoreError(random);
      Object? rethrown;

      try {
        await catchRefusal(
          actionLabel: _actionLabel,
          action: () async {
            Error.throwWithStackTrace(problem, StackTrace.current);
          },
        );
      } on Object catch (caught) {
        rethrown = caught;
      }

      expect(rethrown, same(problem));
    }
  });

  test('test_describe_problem_for_people_property_padded_refusals_keep_'
      'their_words', () {
    final Random random = seededRandom(615304);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String sentence =
          '${_randomBlankText(random)}Refused '
          '${randomText(random)}${_randomBlankText(random)}';

      final String? shown = describeProblemForPeople(
        PeopleFacingRefusal(sentence),
      );

      expect(shown, sentence);
    }
  });
}
