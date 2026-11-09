import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _designFolder = '../docs/design';
const String _designPageExtension = '.html';
const Map<String, String> _htmlEntities = <String, String>{
  '&amp;': '&',
  '&gt;': '>',
  '&lt;': '<',
  '&quot;': '"',
  '&#39;': "'",
};
final RegExp _markupTagPattern = RegExp('<[^>]*>');
final RegExp _whitespaceRunPattern = RegExp(r'\s+');
final RegExp _wireNamePattern = RegExp('[a-z0-9]_[a-z]');
final RegExp _camelCaseNamePattern = RegExp('[a-z][A-Z]');
final RegExp _doubleSpacePattern = RegExp(r'\s\s');
final RegExp _capitalStartPattern = RegExp('^[A-Z]');

void expectPlainWords(String shownText) {
  final String reason = 'shown text "$shownText"';

  expect(shownText, isNotEmpty, reason: reason);
  expect(shownText.trim(), shownText, reason: reason);
  expect(shownText, matches(_capitalStartPattern), reason: reason);
  expect(shownText, isNot(contains('\n')), reason: reason);
  expect(shownText, isNot(matches(_doubleSpacePattern)), reason: reason);
  expect(shownText, isNot(matches(_wireNamePattern)), reason: reason);
  expect(shownText, isNot(matches(_camelCaseNamePattern)), reason: reason);
}

void expectPlainLabel(String shownText) {
  expectPlainWords(shownText);
  expect(shownText, isNot(endsWith('.')), reason: 'label "$shownText"');
}

void expectPlainSentences(String shownText) {
  expectPlainWords(shownText);
  expect(shownText, endsWith('.'), reason: 'sentences "$shownText"');
}

String readDesignPageText(String pageName) {
  final File page = File('$_designFolder/$pageName$_designPageExtension');
  final String markup = page.readAsStringSync();

  String pageText = markup.replaceAll(_markupTagPattern, ' ');
  for (final MapEntry<String, String> entity in _htmlEntities.entries) {
    pageText = pageText.replaceAll(entity.key, entity.value);
  }

  return pageText.replaceAll(_whitespaceRunPattern, ' ');
}

String lowerFirstLetter(String shownText) {
  final String firstLetter = shownText.substring(0, 1).toLowerCase();
  return '$firstLetter${shownText.substring(1)}';
}
