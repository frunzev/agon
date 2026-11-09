import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/pairing/fingerprint_words.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const String _rustWordListPath =
    '../rust/crates/orchestration-security/src/pairing/word_list.rs';
const int _rustWordListLength = 256;
const int _fingerprintWordCount = 4;
const double _largestTextScale = 2;
final RegExp _quotedRustWord = RegExp(r'"([a-z]+)"');
final List<String> _nodeWords = _readNodeWordList();

List<String> _readNodeWordList() {
  final String source = File(_rustWordListPath).readAsStringSync();
  return <String>[
    for (final RegExpMatch match in _quotedRustWord.allMatches(source))
      match.group(1)!,
  ];
}

List<String> _randomNodeWords(Random random) {
  return <String>[
    for (int index = 0; index < _fingerprintWordCount; index += 1)
      pickOne(random, _nodeWords),
  ];
}

List<String> _longestNodeWords() {
  final List<String> byLength = List<String>.of(_nodeWords);
  byLength.sort((String first, String second) => second.length - first.length);
  return byLength.sublist(0, _fingerprintWordCount);
}

Future<double> _pumpWords(
  WidgetTester tester,
  Random random,
  List<String> words,
) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  final double textScale = 1 + random.nextDouble() * (_largestTextScale - 1);
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: FingerprintWords(words: words),
    ),
  );
  expect(tester.takeException(), isNull, reason: 'width $width $words');
  return width;
}

typedef _ShownWord = ({Offset start, String word});

int _compareReadingOrder(_ShownWord first, _ShownWord second) {
  if (first.start.dy != second.start.dy) {
    return first.start.dy.compareTo(second.start.dy);
  }
  return first.start.dx.compareTo(second.start.dx);
}

List<String> _readWordsInReadingOrder(WidgetTester tester) {
  final Finder texts = find.descendant(
    of: find.byType(FingerprintWords),
    matching: find.byType(Text),
  );
  final List<_ShownWord> shown = <_ShownWord>[
    for (final Element element in texts.evaluate())
      (
        start: tester.getTopLeft(find.byWidget(element.widget)),
        word: (element.widget as Text).data!,
      ),
  ];
  shown.sort(_compareReadingOrder);
  return <String>[for (final _ShownWord shownWord in shown) shownWord.word];
}

void main() {
  test(
    'test_fingerprint_words_new_property_keeps_the_node_words_in_order',
    () {
      final Random random = seededRandom(104301);
      expect(_nodeWords.toSet(), hasLength(_rustWordListLength));

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<String> words = _randomNodeWords(random);

        final FingerprintWords widget = FingerprintWords(words: words);

        expect(widget.words, orderedEquals(words));
      }
    },
  );

  test('test_fingerprint_words_new_property_keeps_its_key', () {
    final Random random = seededRandom(104302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ValueKey<String> key = ValueKey<String>(randomText(random));

      final FingerprintWords widget = FingerprintWords(
        words: _randomNodeWords(random),
        key: key,
      );

      expect(widget.key, key);
    }
  });

  testWidgets('test_fingerprint_words_new_property_leaves_the_given_words_'
      'unchanged', (WidgetTester tester) async {
    final Random random = seededRandom(104303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> words = _randomNodeWords(random);
      final List<String> copy = List<String>.of(words);

      await _pumpWords(tester, random, words);

      expect(words, orderedEquals(copy));
    }
  });

  testWidgets('test_fingerprint_words_build_property_shows_the_node_words_'
      'in_reading_order', (WidgetTester tester) async {
    final Random random = seededRandom(104304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> words = _randomNodeWords(random);

      await _pumpWords(tester, random, words);

      expect(_readWordsInReadingOrder(tester), orderedEquals(words));
    }
  });

  testWidgets('test_fingerprint_words_build_property_reads_the_words_in_'
      'order_to_screen_readers', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final Random random = seededRandom(104305);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> words = _randomNodeWords(random);

      await _pumpWords(tester, random, words);

      final String label = 'Words in order: ${words.join(', ')}';
      expect(find.bySemanticsLabel(label), findsOneWidget);
      for (final String word in words.toSet()) {
        expect(find.bySemanticsLabel(word), findsNothing, reason: word);
      }
    }
    semantics.dispose();
  });

  testWidgets('test_fingerprint_words_build_property_longest_words_stay_'
      'inside_the_window', (WidgetTester tester) async {
    final Random random = seededRandom(104306);
    final List<String> longest = _longestNodeWords();

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> words = List<String>.of(longest)..shuffle(random);

      final double width = await _pumpWords(tester, random, words);

      for (final Element word
          in find
              .descendant(
                of: find.byType(FingerprintWords),
                matching: find.byType(Container),
              )
              .evaluate()) {
        final Rect area = tester.getRect(find.byWidget(word.widget));
        expect(area.left, greaterThanOrEqualTo(0));
        expect(area.right, lessThanOrEqualTo(width));
      }
    }
  });
}
