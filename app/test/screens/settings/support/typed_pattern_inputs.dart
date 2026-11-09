import 'dart:math';

import 'package:agent_orchestration/data/rules/protected_patterns.dart';

import '../../../data/rules/support/protected_pattern_inputs.dart';
import '../../../support/random_inputs.dart';
import 'protected_files_section_harness.dart';

const List<String> _forbiddenCharacters = <String>['"', "'", r'\', '(', ')'];
const List<String> _controlCharacters = <String>['\u0001', '\u007F', '\u0090'];
const List<String> _patternsNamingNothing = <String>[
  '/',
  '~',
  '~/',
  '.',
  './',
  '/./',
];
const List<String> _parentFolderPatterns = <String>[
  'a/../b',
  '../secrets',
  '~/..',
];
const List<String> _edgeWhiteSpace = <String>[' ', '　', ' '];
const int _overlongExtra = 20;

String randomRepeatOf(Random random, String listed) {
  final List<String> repeats = <String>[
    listed,
    flipAsciiCase(listed),
    '$listed/',
    '$listed/.',
    '$listed//',
  ];
  return pickOne(random, repeats);
}

String _insertAtRandom(Random random, String text, String inserted) {
  final int position = random.nextInt(text.length + 1);
  return '${text.substring(0, position)}$inserted${text.substring(position)}';
}

String _randomOverlongPattern(Random random) {
  final int length =
      maximumProtectedPatternLength + random.nextInt(_overlongExtra) - 1;
  return 'x' * length;
}

String randomTypedPattern(Random random, List<String> listedPatterns) {
  final String valid = randomValidPattern(random);
  final List<String> candidates = <String>[
    valid,
    padWithBlanks(random, valid),
    '${pickOne(random, _edgeWhiteSpace)}$valid',
    pickOne(random, blankTypedTexts),
    _insertAtRandom(random, valid, pickOne(random, _forbiddenCharacters)),
    _insertAtRandom(random, valid, pickOne(random, _controlCharacters)),
    pickOne(random, _patternsNamingNothing),
    pickOne(random, _parentFolderPatterns),
    _randomOverlongPattern(random),
    randomText(random),
    'my notes/$valid',
  ];
  if (listedPatterns.isNotEmpty) {
    final String listed = pickOne(random, listedPatterns);
    candidates.add(randomRepeatOf(random, listed));
    candidates.add(padWithBlanks(random, randomRepeatOf(random, listed)));
  }
  return pickOne(random, candidates);
}
