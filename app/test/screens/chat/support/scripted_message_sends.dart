import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/chat/chat_composer.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../../support/chat_composer_harness.dart';
import '../../../support/random_inputs.dart';
import '../../../support/widget_harness.dart';

const String composerSendLabel = 'Send';
const List<String> surroundingBlanks = <String>['', ' ', '\n', ' \t '];

final class ScriptedMessageSends {
  final List<String> sentMessages = <String>[];
  final List<Completer<ActionOutcome>> pending =
      <Completer<ActionOutcome>>[];

  Future<ActionOutcome> send(String message) {
    sentMessages.add(message);
    final Completer<ActionOutcome> outcome = Completer<ActionOutcome>();
    pending.add(outcome);
    return outcome.future;
  }
}

String randomTypedChatMessage(Random random) {
  final String blankBefore = pickOne(random, surroundingBlanks);
  final String blankAfter = pickOne(random, surroundingBlanks);
  return '${blankBefore}message ${randomText(random)}$blankAfter';
}

Future<void> pumpScriptedComposer(
  WidgetTester tester, {
  required double width,
  required TargetPlatform platform,
  required ScriptedMessageSends sends,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScrollableOnPlatform(
    tester,
    width: width,
    platform: platform,
    child: ChatComposer(onSend: sends.send),
  );
}

Future<void> pumpScriptedComposerAtRandomWidth(
  WidgetTester tester, {
  required Random random,
  required ScriptedMessageSends sends,
}) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  return pumpScriptedComposer(
    tester,
    width: width,
    platform: platformMeantByWidth(width),
    sends: sends,
  );
}

Finder findComposerSendButton() {
  return find.widgetWithText(AppButton, composerSendLabel);
}

Future<void> typeAndSendChatMessage(
  WidgetTester tester,
  String typedMessage,
) async {
  await tester.enterText(findComposerField(), typedMessage);
  await tester.pump();
  await tester.tap(findComposerSendButton());
  await tester.pump();
}

String readComposerText(WidgetTester tester) {
  return readComposerInput(tester).controller.text;
}

bool isComposerSendOffered(WidgetTester tester) {
  final AppButton sendButton = tester.widget<AppButton>(
    findComposerSendButton(),
  );
  return sendButton.onPressed != null;
}
