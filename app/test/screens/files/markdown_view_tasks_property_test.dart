import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as markdown;

import 'package:agent_orchestration/screens/files/markdown_spans.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

import '../../support/random_inputs.dart';
import 'markdown_github_inputs.dart';
import 'markdown_view_inputs.dart';

const String _bullet = '•';
const String _uncheckedBox = '☐';
const String _checkedBox = '☑';
const int _mostItems = 6;
const int _mostNodes = 8;
const List<String> _wrappingTags = <String>['em', 'strong', 'del', 'a'];
const List<TextStyle> _blockStyles = <TextStyle>[
  AppTextStyles.body,
  AppTextStyles.bodyBold,
  AppTextStyles.heading,
];

typedef _InlinePiece = ({markdown.Node node, String shown});

_InlinePiece _randomPiece(Random random) {
  final String word = randomPlainWord(random);
  return switch (random.nextInt(4)) {
    0 => (node: markdown.Text('$word\n'), shown: '$word '),
    1 => (node: markdown.Element.text('code', word), shown: word),
    2 => (node: markdown.Element.empty('br'), shown: '\n'),
    _ => (
      node: markdown.Element(pickOne(random, _wrappingTags), <markdown.Node>[
        markdown.Text(word),
      ]),
      shown: word,
    ),
  };
}

List<String> _readMarkers(WidgetTester tester) {
  return <String>[
    for (final String text in readShownMarkdownTexts(tester))
      if (text == _bullet ||
          text == _uncheckedBox ||
          text == _checkedBox ||
          RegExp(r'^\d+\.$').hasMatch(text))
        text,
  ];
}

TextStyle _readWordStyle(WidgetTester tester, String word) {
  final Text paragraph = tester.widget(findMarkdownTexts().first);
  return mergeWordStyle(paragraph.textSpan!, word, const TextStyle())!;
}

String _renderTaskList(List<bool?> items, {required bool isLoose}) {
  final List<String> lines = <String>[
    for (int index = 0; index < items.length; index += 1)
      switch (items[index]) {
        true => '- [x] item$index',
        false => '- [ ] item$index',
        null => '- item$index [ ]',
      },
  ];
  return lines.join(isLoose ? '\n\n' : '\n');
}

String _expectedMarker(bool? isChecked) {
  return switch (isChecked) {
    true => _checkedBox,
    false => _uncheckedBox,
    null => _bullet,
  };
}

List<bool?> _randomTaskStates(Random random) {
  final int count = 1 + random.nextInt(_mostItems);
  return <bool?>[
    for (int index = 0; index < count; index += 1)
      pickOne(random, <bool?>[true, false, null]),
  ];
}

void main() {
  testWidgets('test_find_task_marker_property_each_box_follows_its_state', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105901);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<bool?> states = _randomTaskStates(random);

      await pumpMarkdown(
        tester,
        random,
        _renderTaskList(states, isLoose: false),
      );

      expect(_readMarkers(tester), <String>[
        for (final bool? state in states) _expectedMarker(state),
      ]);
    }
  });

  testWidgets('test_find_task_marker_property_loose_task_lists_keep_their_'
      'boxes', (WidgetTester tester) async {
    final Random random = seededRandom(105902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<bool?> states = _randomTaskStates(random);

      await pumpMarkdown(
        tester,
        random,
        _renderTaskList(states, isLoose: true),
      );

      expect(_readMarkers(tester), <String>[
        for (final bool? state in states) _expectedMarker(state),
      ]);
    }
  });

  testWidgets('test_find_task_marker_property_brackets_later_in_an_item_'
      'stay_text', (WidgetTester tester) async {
    final Random random = seededRandom(105903);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String word = randomPlainWord(random);
      final String bracket = pickOne(random, <String>['[ ]', '[x]']);
      final String marker = pickOne(random, <String>['-', '1.']);

      await pumpMarkdown(tester, random, '$marker $word $bracket');

      expect(findShownMarkdownText('$word $bracket'), findsOneWidget);
      expect(find.text(_uncheckedBox), findsNothing);
      expect(find.text(_checkedBox), findsNothing);
    }
  });

  testWidgets('test_build_span_property_strikethrough_draws_a_line', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105904);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String word = randomPlainWord(random);

      await pumpMarkdown(tester, random, 'start ~~$word~~ end');

      final TextStyle style = _readWordStyle(tester, word);
      expect(style.decoration, TextDecoration.lineThrough);
      expect(
        _readWordStyle(tester, ' end').decoration,
        isNot(TextDecoration.lineThrough),
      );
    }
  });

  testWidgets('test_build_span_property_strikethrough_keeps_outer_'
      'styles', (WidgetTester tester) async {
    final Random random = seededRandom(105905);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String word = randomPlainWord(random);
      final bool isStrong = random.nextBool();
      final String outer = isStrong ? '**' : '*';

      await pumpMarkdown(tester, random, 'a $outer~~$word~~$outer b');

      final TextStyle style = _readWordStyle(tester, word);
      expect(style.decoration, TextDecoration.lineThrough);
      if (isStrong) {
        expect(style.fontWeight, FontWeight.w700);
      } else {
        expect(style.fontStyle, FontStyle.italic);
      }
    }
  });

  testWidgets('test_build_span_property_a_task_box_adds_no_text_to_the_'
      'item', (WidgetTester tester) async {
    final Random random = seededRandom(105906);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<bool?> states = _randomTaskStates(random);

      await pumpMarkdown(
        tester,
        random,
        _renderTaskList(states, isLoose: random.nextBool()),
      );

      for (int index = 0; index < states.length; index += 1) {
        final String label = states[index] == null
            ? 'item$index [ ]'
            : 'item$index';
        expect(findShownMarkdownText(label), findsOneWidget, reason: label);
      }
    }
  });

  test('test_build_markdown_rich_text_property_reads_as_its_nodes', () {
    final Random random = seededRandom(105907);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = random.nextInt(_mostNodes);
      final List<_InlinePiece> pieces = <_InlinePiece>[
        for (int index = 0; index < count; index += 1) _randomPiece(random),
      ];

      final Text shown = buildMarkdownRichText(<markdown.Node>[
        for (final _InlinePiece piece in pieces) piece.node,
      ], AppTextStyles.body);

      final StringBuffer expected = StringBuffer();
      for (final _InlinePiece piece in pieces) {
        expected.write(piece.shown);
      }
      expect(shown.textSpan!.toPlainText(), expected.toString());
    }
  });

  test('test_build_markdown_rich_text_property_carries_the_given_style', () {
    final Random random = seededRandom(105908);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TextStyle style = pickOne(random, _blockStyles);

      final Text shown = buildMarkdownRichText(<markdown.Node>[
        _randomPiece(random).node,
      ], style);

      expect(shown.style, style);
    }
  });

  test('test_build_markdown_rich_text_property_one_span_per_node', () {
    final Random random = seededRandom(105909);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = random.nextInt(_mostNodes);

      final Text shown = buildMarkdownRichText(<markdown.Node>[
        for (int index = 0; index < count; index += 1)
          _randomPiece(random).node,
      ], AppTextStyles.body);

      final TextSpan root = shown.textSpan! as TextSpan;
      expect(root.children ?? const <InlineSpan>[], hasLength(count));
      expect(shown.data, isNull);
    }
  });
}
