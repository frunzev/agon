import 'dart:math';

import '../../../support/random_inputs.dart';

const List<String> unicodeWhiteSpaces = <String>[
  ' ',
  '\t',
  '\n',
  '\r',
  '\u000B',
  '\u000C',
  '\u0085',
  '\u00A0',
  '\u1680',
  '\u2000',
  '\u2007',
  '\u200A',
  '\u2028',
  '\u2029',
  '\u202F',
  '\u205F',
  '\u3000',
];
const String byteOrderMark = '\uFEFF';
const int _largestPaddingLength = 4;

String randomWhiteSpacePadding(Random random) {
  final int length = random.nextInt(_largestPaddingLength);
  final StringBuffer padding = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    padding.write(pickOne(random, unicodeWhiteSpaces));
  }
  return padding.toString();
}
