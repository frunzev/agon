import 'dart:math';

import 'package:agent_orchestration/screens/files/syntax_highlighting.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

const List<String> everySyntaxExtension = <String>[
  'ts',
  'tsx',
  'js',
  'jsx',
  'mjs',
  'cjs',
  'dart',
  'rs',
  'py',
  'go',
  'java',
  'kt',
  'kts',
  'swift',
  'c',
  'h',
  'cc',
  'cpp',
  'hpp',
  'cs',
  'm',
  'rb',
  'sh',
  'bash',
  'zsh',
  'json',
  'yaml',
  'yml',
  'toml',
];
const List<String> _hostileCodePieces = <String>[
  'const',
  'if',
  'let',
  'fn',
  'def',
  'True',
  'readSession',
  '(',
  ')',
  ' ',
  '\t',
  '"',
  "'",
  '`',
  r'\',
  r'\"',
  r"\'",
  '"done"',
  '/*',
  '*/',
  '//',
  '#',
  '"""',
  'é',
  'e\u0301',
  'ñ',
  'Ω',
  '\u{1F600}',
  '\u{1F469}\u{200D}\u{1F4BB}',
  '\u202e',
  '\u200b',
  '42',
  r'$x',
  '_y',
  'ünïcødé',
];
const int _largestPieceCount = 16;
final RegExp _wordStartCharacter = RegExp(r'[\p{L}_$]', unicode: true);
final RegExp _wordCharacter = RegExp(r'[\p{L}\p{M}\p{N}_$]', unicode: true);

SyntaxLanguage findEverySyntaxLanguage(String extension) {
  final SyntaxLanguage? language = findSyntaxLanguage(extension);
  if (language == null) {
    throw StateError('no syntax language for $extension');
  }
  return language;
}

SyntaxLanguage randomSyntaxLanguage(Random random) {
  return findEverySyntaxLanguage(pickOne(random, everySyntaxExtension));
}

String randomHostileCodeLine(Random random) {
  final StringBuffer line = StringBuffer();
  final int pieceCount = random.nextInt(_largestPieceCount);
  for (int index = 0; index < pieceCount; index += 1) {
    if (random.nextInt(4) == 0) {
      line.write(randomHostileText(random).replaceAll('\n', ' '));
    } else {
      line.write(pickOne(random, _hostileCodePieces));
    }
  }
  return line.toString();
}

bool canStartWord(String character) {
  return _wordStartCharacter.hasMatch(character);
}

bool canContinueWord(String character) {
  return _wordCharacter.hasMatch(character);
}

String joinTokenTexts(List<SyntaxToken> tokens) {
  final StringBuffer text = StringBuffer();
  for (final SyntaxToken token in tokens) {
    text.write(token.text);
  }
  return text.toString();
}
