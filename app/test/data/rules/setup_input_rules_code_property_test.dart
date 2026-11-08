import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

const int _codeLength = 6;
const int _firstNonAsciiRune = 0x80;
const int _mostRepeats = 4;
const String _localSuffix = '.local';
const String _codeSymbols = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const String _symbolAliases = 'OoIiLl';
const String _refusedLetters = 'Uu';
const List<String> _separators = <String>[
  '',
  ' ',
  '-',
  '\t',
  '\u00a0',
  '\u0085',
];
const List<String> _refusedLookalikes = <String>[
  '\u{1F600}',
  '\u{1D400}',
  '\u{20000}',
  '\u017f',
  '\u0131',
  '\ufeff',
];
final RegExp _rustSeparators = RegExp('^(?:$unicodeWhiteSpaceCharacter|-)\$');
final RegExp _outsideNames = RegExp('[^a-z0-9]');

bool _isRustPairingCode(String code) {
  int symbolCount = 0;
  for (final int rune in code.runes) {
    final String character = String.fromCharCode(rune);
    if (_rustSeparators.hasMatch(character)) {
      continue;
    }
    final String uppercase = character.toUpperCase();
    final bool isAscii = rune < _firstNonAsciiRune;
    final bool isSymbol =
        isAscii &&
        (_codeSymbols.contains(uppercase) ||
            _symbolAliases.contains(character));
    if (!isSymbol) {
      return false;
    }
    symbolCount += 1;
  }
  return symbolCount == _codeLength;
}

String _randomSymbol(Random random) {
  final String symbols =
      '$_codeSymbols${_codeSymbols.toLowerCase()}'
      '$_symbolAliases';
  return symbols[random.nextInt(symbols.length)];
}

String _randomValidCode(Random random) {
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < _codeLength; i += 1) {
    buffer.write(pickOne(random, _separators));
    buffer.write(_randomSymbol(random));
  }
  buffer.write(pickOne(random, _separators));
  return buffer.toString();
}

String _randomNearCode(Random random) {
  final List<String> pieces = _randomValidCode(random).split('');
  final int position = random.nextInt(pieces.length);
  final String intruder = pickOne(random, <String>[
    pickOne(random, _refusedLookalikes),
    _refusedLetters[random.nextInt(_refusedLetters.length)],
    randomHostileText(random),
    '',
  ]);
  pieces[position] = intruder;
  return pieces.join();
}

void main() {
  test('test_describe_pairing_code_problem_property_agrees_with_the_node_'
      'code_rules', () {
    final Random random = seededRandom(89201);

    for (int i = 0; i < propertyIterations * 2; i += 1) {
      final String code = random.nextBool()
          ? _randomNearCode(random)
          : randomHostileText(random);

      final String? problem = describePairingCodeProblem(code);

      expect(problem == null, _isRustPairingCode(code), reason: code);
    }
  });

  test('test_describe_pairing_code_problem_property_counts_characters_not_'
      'code_units', () {
    final Random random = seededRandom(89202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String astral = pickOne(random, _refusedLookalikes);
      final String halfCode = List<String>.filled(
        _codeLength ~/ 2,
        astral,
      ).join();

      expect(describePairingCodeProblem(halfCode), isNotNull);
      expect(describePairingCodeProblem('ABC$astral'), isNotNull);
    }
  });

  test('test_describe_pairing_code_problem_property_case_spaces_and_'
      'dashes_do_not_matter', () {
    final Random random = seededRandom(89203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String code = _randomValidCode(random);

      expect(describePairingCodeProblem(code), isNull, reason: code);
      expect(describePairingCodeProblem(code.toUpperCase()), isNull);
      expect(describePairingCodeProblem(code.toLowerCase()), isNull);
    }
  });

  test('test_describe_join_input_problem_property_a_bad_code_is_named_'
      'first', () {
    final Random random = seededRandom(89204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String code = _randomNearCode(random);
      final String? codeProblem = describePairingCodeProblem(code);
      final String? serverAddress = random.nextBool()
          ? null
          : randomHostileText(random);

      final String? problem = describeJoinInputProblem(
        serverAddress: serverAddress,
        code: code,
      );

      if (codeProblem != null) {
        expect(problem, codeProblem);
      }
    }
  });

  test('test_describe_join_input_problem_property_a_good_code_leaves_the_'
      'server_problem', () {
    final Random random = seededRandom(89205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String serverAddress = random.nextBool()
          ? 'https://${randomWordPhrase(random)}'
          : randomHostileText(random);

      final String? problem = describeJoinInputProblem(
        serverAddress: serverAddress,
        code: _randomValidCode(random),
      );

      expect(problem, describeServerAddressProblem(serverAddress));
    }
  });

  test('test_suggest_device_name_property_keeps_letters_and_digits_in_'
      'order', () {
    final Random random = seededRandom(89206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String hostName = randomHostileText(random);

      final String suggestion = suggestDeviceName(hostName);

      final String lowercase = hostName.trim().toLowerCase();
      final String kept = lowercase.replaceAll(_outsideNames, '');
      final String suggested = suggestion.replaceAll('-', '');
      if (kept.isNotEmpty) {
        expect(kept.startsWith(suggested), isTrue, reason: hostName);
      }
    }
  });

  test('test_suggest_device_name_property_names_are_tidy_and_short', () {
    final Random random = seededRandom(89207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String bareName =
          randomHostileText(random) * (1 + random.nextInt(_mostRepeats));
      final String hostName = '$bareName$_localSuffix';

      final String suggestion = suggestDeviceName(hostName);

      expect(suggestion.length, lessThanOrEqualTo(nameMaximumLength));
      expect(suggestion, isNot(contains('--')));
      expect(suggestion, isNot(startsWith('-')));
      expect(suggestion, isNot(endsWith('-')));
      if (!bareName.trim().toLowerCase().endsWith(_localSuffix)) {
        expect(suggestion, suggestDeviceName(bareName), reason: hostName);
      }
    }
  });
}
