import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/chat/chat_composer.dart';

import '../../support/chat_composer_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/scripted_message_sends.dart';

double _randomComposerWidth(Random random) {
  return randomWidth(random, least: narrowestWidth, most: widestWidth);
}

Future<void> _pumpComposers(
  WidgetTester tester, {
  required double width,
  required List<Widget> composers,
}) async {
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: Column(children: composers),
  );
}

Finder _findFieldOf(Key composerKey) {
  return find.descendant(
    of: find.byKey(composerKey),
    matching: find.byType(TextField),
  );
}

String _readFieldText(WidgetTester tester, Key composerKey) {
  final TextField field = tester.widget(_findFieldOf(composerKey));
  return field.controller!.text;
}

Future<void> _sendThenLeaveBeforeItFails(
  WidgetTester tester,
  Random random,
  ScriptedMessageSends sends,
) async {
  await pumpScriptedComposerAtRandomWidth(
    tester,
    random: random,
    sends: sends,
  );
  await typeAndSendChatMessage(tester, randomTypedChatMessage(random));
  await tester.pumpWidget(const SizedBox.shrink());
  sends.pending.single.completeError(FormatException(randomText(random)));
  await tester.pump();
}

void main() {
  testWidgets('test_chat_composer_create_state_property_a_new_composer_'
      'starts_empty', (WidgetTester tester) async {
    final Random random = seededRandom(98201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = ScriptedMessageSends();
      final double width = _randomComposerWidth(random);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpComposers(
        tester,
        width: width,
        composers: <Widget>[
          ChatComposer(key: const ValueKey<int>(0), onSend: sends.send),
        ],
      );
      final String typedMessage = randomTypedChatMessage(random);
      await tester.enterText(findComposerField(), typedMessage);
      final String keptBeforeSwap = readComposerText(tester);

      await _pumpComposers(
        tester,
        width: width,
        composers: <Widget>[
          ChatComposer(key: const ValueKey<int>(1), onSend: sends.send),
        ],
      );

      expect(keptBeforeSwap, typedMessage);
      expect(readComposerText(tester), isEmpty);
      expect(isComposerSendOffered(tester), isTrue);
    }
  });

  testWidgets('test_chat_composer_create_state_property_a_rebuilt_composer_'
      'keeps_text_and_uses_the_new_sender', (WidgetTester tester) async {
    final Random random = seededRandom(98202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends oldSends = ScriptedMessageSends();
      final ScriptedMessageSends newSends = ScriptedMessageSends();
      const Key composerKey = ValueKey<String>('composer');
      final double width = _randomComposerWidth(random);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpComposers(
        tester,
        width: width,
        composers: <Widget>[
          ChatComposer(key: composerKey, onSend: oldSends.send),
        ],
      );
      final String typedMessage = randomTypedChatMessage(random);
      await tester.enterText(findComposerField(), typedMessage);

      await _pumpComposers(
        tester,
        width: width,
        composers: <Widget>[
          ChatComposer(key: composerKey, onSend: newSends.send),
        ],
      );
      await tester.tap(findComposerSendButton());
      await tester.pump();

      expect(oldSends.sentMessages, isEmpty);
      expect(newSends.sentMessages, <String>[typedMessage.trim()]);
    }
  });

  testWidgets('test_chat_composer_create_state_property_two_composers_keep_'
      'their_own_text', (WidgetTester tester) async {
    final Random random = seededRandom(98203);
    const Key firstKey = ValueKey<String>('first');
    const Key secondKey = ValueKey<String>('second');

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = ScriptedMessageSends();
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpComposers(
        tester,
        width: _randomComposerWidth(random),
        composers: <Widget>[
          ChatComposer(key: firstKey, onSend: sends.send),
          ChatComposer(key: secondKey, onSend: sends.send),
        ],
      );
      final String firstText = 'first ${randomText(random)}';
      final String secondText = 'second ${randomText(random)}';

      await tester.enterText(_findFieldOf(firstKey), firstText);
      await tester.enterText(_findFieldOf(secondKey), secondText);

      expect(_readFieldText(tester, firstKey), firstText);
      expect(_readFieldText(tester, secondKey), secondText);
    }
  });

  testWidgets('test_chat_composer_state_init_state_property_field_has_focus_'
      'on_open', (WidgetTester tester) async {
    final Random random = seededRandom(98204);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScriptedComposerAtRandomWidth(
        tester,
        random: random,
        sends: ScriptedMessageSends(),
      );

      expect(readComposerInput(tester).focusNode.hasFocus, isTrue);
    }
  });

  testWidgets('test_chat_composer_state_init_state_property_opens_empty_and_'
      'ready', (WidgetTester tester) async {
    final Random random = seededRandom(98205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScriptedComposerAtRandomWidth(
        tester,
        random: random,
        sends: ScriptedMessageSends(),
      );

      expect(readComposerText(tester), isEmpty);
      expect(isComposerSendOffered(tester), isTrue);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_chat_composer_state_init_state_property_typing_right_'
      'away_reaches_the_composer', (WidgetTester tester) async {
    final Random random = seededRandom(98206);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScriptedComposerAtRandomWidth(
        tester,
        random: random,
        sends: ScriptedMessageSends(),
      );
      final String typedMessage = randomTypedChatMessage(random);

      tester.testTextInput.enterText(typedMessage);
      await tester.pump();

      expect(readComposerText(tester), typedMessage);
    }
  });

  testWidgets('test_chat_composer_state_dispose_property_releases_text_and_'
      'focus', (WidgetTester tester) async {
    final Random random = seededRandom(98207);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScriptedComposerAtRandomWidth(
        tester,
        random: random,
        sends: ScriptedMessageSends(),
      );
      final EditableText input = readComposerInput(tester);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(
        () => ChangeNotifier.debugAssertNotDisposed(input.controller),
        throwsFlutterError,
      );
      expect(
        () => ChangeNotifier.debugAssertNotDisposed(input.focusNode),
        throwsFlutterError,
      );
    }
  });

  testWidgets('test_chat_composer_state_dispose_property_focus_leaves_with_'
      'the_composer', (WidgetTester tester) async {
    final Random random = seededRandom(98208);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScriptedComposerAtRandomWidth(
        tester,
        random: random,
        sends: ScriptedMessageSends(),
      );
      final FocusNode composerFocus = readComposerInput(tester).focusNode;

      await tester.pumpWidget(const SizedBox.shrink());

      final FocusNode? focused = FocusManager.instance.primaryFocus;
      expect(identical(focused, composerFocus), isFalse);
    }
  });

  testWidgets('test_chat_composer_state_dispose_property_a_failure_after_'
      'leaving_surfaces_once', (WidgetTester tester) async {
    final Random random = seededRandom(98209);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = ScriptedMessageSends();
      final List<Object> escapedProblems = <Object>[];

      await runZonedGuarded(
        () => _sendThenLeaveBeforeItFails(tester, random, sends),
        (Object problem, StackTrace _) => escapedProblems.add(problem),
      );

      expect(tester.takeException(), isNull);
      expect(escapedProblems, <Matcher>[isA<FormatException>()]);
      expect(sends.sentMessages, hasLength(1));
    }
  });
}
