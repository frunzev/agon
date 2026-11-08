import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/unicode_white_space.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';

import '../../support/chat_composer_harness.dart';
import '../../support/random_inputs.dart';
import 'support/scripted_message_sends.dart';

const List<String> _rustWhiteSpace = <String>[
  ' ',
  '\t',
  '\n',
  ' ',
  '\u0085',
  ' ',
  '　',
  ' ',
];
const List<String> _lookAlikes = <String>['﻿', '​', '᠎'];
const int _largestPaddingLength = 3;

String _randomPadding(Random random) {
  final int length = random.nextInt(_largestPaddingLength + 1);
  final StringBuffer padding = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    padding.write(pickOne(random, _rustWhiteSpace));
  }
  return padding.toString();
}

String _randomEdgedMessage(Random random) {
  final String lookAlike = pickOne(random, _lookAlikes);
  final String core = random.nextBool()
      ? lookAlike
      : '$lookAlike${randomText(random)}';
  return '${_randomPadding(random)}$core${_randomPadding(random)}';
}

Future<ScriptedMessageSends> _pumpComposer(
  WidgetTester tester,
  Random random,
) async {
  final ScriptedMessageSends sends = ScriptedMessageSends();
  await pumpScriptedComposerAtRandomWidth(
    tester,
    random: random,
    sends: sends,
  );
  return sends;
}

void main() {
  testWidgets('test_send_property_a_look_alike_message_is_sent', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(88101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = await _pumpComposer(tester, random);
      final String lookAlike = pickOne(random, _lookAlikes);
      final String typedMessage =
          '${_randomPadding(random)}$lookAlike${_randomPadding(random)}';

      await typeAndSendChatMessage(tester, typedMessage);

      expect(tester.takeException(), isNull);
      expect(sends.sentMessages, <String>[lookAlike]);
    }
  });

  testWidgets('test_send_property_sends_the_unicode_trimmed_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(88102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = await _pumpComposer(tester, random);
      final String typedMessage = _randomEdgedMessage(random);

      await typeAndSendChatMessage(tester, typedMessage);

      expect(tester.takeException(), isNull);
      expect(sends.sentMessages, <String>[
        trimUnicodeWhiteSpace(typedMessage),
      ]);
    }
  });

  testWidgets('test_send_property_only_rust_white_space_is_blank', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(88103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = await _pumpComposer(tester, random);
      final String blankMessage = '${_randomPadding(random)} ';

      await typeAndSendChatMessage(tester, blankMessage);

      expect(tester.takeException(), isNull);
      expect(sends.sentMessages, isEmpty);
      expect(readComposerText(tester), blankMessage);
    }
  });

  testWidgets('test_clear_sent_message_property_clears_a_look_alike', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(88104);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = await _pumpComposer(tester, random);
      final String typedMessage = _randomEdgedMessage(random);

      await typeAndSendChatMessage(tester, typedMessage);
      sends.pending.single.complete(ActionOutcome.done);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(readComposerText(tester), isEmpty);
    }
  });

  testWidgets('test_clear_sent_message_property_new_padding_still_clears', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(88105);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = await _pumpComposer(tester, random);
      final String typedMessage = _randomEdgedMessage(random);
      final String repadded =
          '${_randomPadding(random)}$typedMessage${_randomPadding(random)}';

      await typeAndSendChatMessage(tester, typedMessage);
      await tester.enterText(findComposerField(), repadded);
      sends.pending.single.complete(ActionOutcome.done);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(readComposerText(tester), isEmpty);
    }
  });

  testWidgets('test_clear_sent_message_property_a_look_alike_edit_survives', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(88106);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = await _pumpComposer(tester, random);
      final String typedMessage = randomTypedChatMessage(random);
      final String lookAlike = pickOne(random, _lookAlikes);
      final String editedMessage = random.nextBool()
          ? '$lookAlike$typedMessage'
          : '$typedMessage$lookAlike';

      await typeAndSendChatMessage(tester, typedMessage);
      await tester.enterText(findComposerField(), editedMessage);
      sends.pending.single.complete(ActionOutcome.done);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(readComposerText(tester), editedMessage);
    }
  });
}
