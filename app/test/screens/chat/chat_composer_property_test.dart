import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/shared/action_refusal.dart';

import '../../support/chat_composer_harness.dart';
import '../../support/random_inputs.dart';
import 'support/scripted_message_sends.dart';

void main() {
  testWidgets('test_clear_sent_message_property_a_refused_send_keeps_the_'
      'typed_text', (WidgetTester tester) async {
    final Random random = seededRandom(94501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = ScriptedMessageSends();
      await pumpScriptedComposerAtRandomWidth(
        tester,
        random: random,
        sends: sends,
      );
      final String typedMessage = randomTypedChatMessage(random);

      await typeAndSendChatMessage(tester, typedMessage);
      sends.pending.single.complete(ActionOutcome.refused);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(sends.sentMessages, <String>[typedMessage.trim()]);
      expect(readComposerText(tester), typedMessage);
      expect(isComposerSendOffered(tester), isTrue);
    }
  });

  testWidgets('test_clear_sent_message_property_a_successful_send_clears_'
      'the_text', (WidgetTester tester) async {
    final Random random = seededRandom(94502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = ScriptedMessageSends();
      await pumpScriptedComposerAtRandomWidth(
        tester,
        random: random,
        sends: sends,
      );
      final String typedMessage = randomTypedChatMessage(random);

      await typeAndSendChatMessage(tester, typedMessage);
      sends.pending.single.complete(ActionOutcome.done);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(sends.sentMessages, <String>[typedMessage.trim()]);
      expect(readComposerText(tester), isEmpty);
      expect(readComposerInput(tester).focusNode.hasFocus, isTrue);
    }
  });

  testWidgets('test_clear_sent_message_property_text_typed_during_the_send_'
      'survives_it', (WidgetTester tester) async {
    final Random random = seededRandom(94505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = ScriptedMessageSends();
      await pumpScriptedComposerAtRandomWidth(
        tester,
        random: random,
        sends: sends,
      );
      final String typedMessage = randomTypedChatMessage(random);
      final String nextMessage = '${typedMessage}next ${randomText(random)}';

      await typeAndSendChatMessage(tester, typedMessage);
      await tester.enterText(findComposerField(), nextMessage);
      sends.pending.single.complete(pickOne(random, ActionOutcome.values));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(readComposerText(tester), nextMessage);
      expect(sends.sentMessages, <String>[typedMessage.trim()]);
    }
  });

  testWidgets('test_send_property_a_pending_send_keeps_the_text_and_sends_'
      'once', (WidgetTester tester) async {
    final Random random = seededRandom(94503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = ScriptedMessageSends();
      await pumpScriptedComposerAtRandomWidth(
        tester,
        random: random,
        sends: sends,
      );
      final String typedMessage = randomTypedChatMessage(random);
      final int extraTaps = 1 + random.nextInt(3);

      await typeAndSendChatMessage(tester, typedMessage);
      for (int tap = 0; tap < extraTaps; tap += 1) {
        await tester.tap(findComposerSendButton());
        await tester.pump();
      }

      expect(sends.sentMessages, hasLength(1));
      expect(readComposerText(tester), typedMessage);
      sends.pending.single.complete(ActionOutcome.done);
      await tester.pump();
      expect(readComposerText(tester), isEmpty);
    }
  });

  testWidgets('test_send_property_a_failed_send_keeps_the_text_and_allows_'
      'another', (WidgetTester tester) async {
    final Random random = seededRandom(94504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = ScriptedMessageSends();
      await pumpScriptedComposerAtRandomWidth(
        tester,
        random: random,
        sends: sends,
      );
      final String typedMessage = randomTypedChatMessage(random);
      final List<Object> escapedProblems = <Object>[];

      await runZonedGuarded(() async {
        await typeAndSendChatMessage(tester, typedMessage);
        sends.pending.single.completeError(
          FormatException(randomText(random)),
        );
        await tester.pump();
      }, (Object problem, StackTrace _) => escapedProblems.add(problem));

      expect(escapedProblems, <Matcher>[isA<FormatException>()]);
      expect(readComposerText(tester), typedMessage);
      expect(isComposerSendOffered(tester), isTrue);
      await tester.tap(findComposerSendButton());
      await tester.pump();
      expect(sends.sentMessages, <String>[
        typedMessage.trim(),
        typedMessage.trim(),
      ]);
    }
  });

  testWidgets('test_send_property_a_send_ending_after_leaving_is_harmless', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(94507);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = ScriptedMessageSends();
      await pumpScriptedComposerAtRandomWidth(
        tester,
        random: random,
        sends: sends,
      );

      await typeAndSendChatMessage(tester, randomTypedChatMessage(random));
      await tester.pumpWidget(const SizedBox.shrink());
      sends.pending.single.complete(pickOne(random, ActionOutcome.values));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(sends.sentMessages, hasLength(1));
    }
  });

  testWidgets('test_send_property_blank_text_is_never_sent', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(94506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = ScriptedMessageSends();
      await pumpScriptedComposerAtRandomWidth(
        tester,
        random: random,
        sends: sends,
      );
      final String blankMessage =
          '${pickOne(random, surroundingBlanks)}'
          '${pickOne(random, surroundingBlanks)}';

      await typeAndSendChatMessage(tester, blankMessage);

      expect(tester.takeException(), isNull);
      expect(sends.sentMessages, isEmpty);
      expect(readComposerText(tester), blankMessage);
      expect(isComposerSendOffered(tester), isTrue);
    }
  });
}
