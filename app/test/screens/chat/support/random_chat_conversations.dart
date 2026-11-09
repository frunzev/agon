import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../support/random_inputs.dart';
import '../../../support/widget_harness.dart';

const RunId chatPropertyRunId = RunId('chat-property-run');
const int largestChatMessageCount = 30;
const int largestFullyShownMessageCount = 5;
const double _shortestWindowHeight = 480;
const double _tallestWindowHeight = 1200;
const int _largestMessageGapSeconds = 90;
const int _repeatedWordCount = 120;
const int _unbrokenWordLength = 600;
final DateTime _firstMessageMoment = DateTime.utc(2026, 11, 8, 14);

final List<String> _awkwardChatTexts = <String>[
  'שלום, הבנייה עברה בהצלחה',
  'مرحبا، فشل البناء في الخطوة الثانية',
  '\u202eright to left override',
  '\u{1F469}\u{200D}\u{1F4BB} pushed the fix',
  'é and ñ',
  'line one\nline two\n\nline four',
  'release ' * _repeatedWordCount,
  'x' * _unbrokenWordLength,
];

String randomChatText(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _awkwardChatTexts);
  }
  return randomHostileText(random);
}

String markChatText(int index, String text) => 'm$index $text';

Size randomChatWindowSize(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  const double heightSpan = _tallestWindowHeight - _shortestWindowHeight;
  final double extraHeight = random.nextDouble() * heightSpan;
  return Size(width, _shortestWindowHeight + extraHeight);
}

ChatMessage buildChatMessage({
  required DateTime at,
  required ChatAuthor author,
  required String text,
}) {
  return ChatMessage(
    at: at,
    author: author,
    text: text,
    isError: false,
    waitingToSend: false,
  );
}

List<ChatMessage> randomChronologicalMessages(
  Random random, {
  required int count,
}) {
  final List<ChatMessage> messages = <ChatMessage>[];
  DateTime moment = _firstMessageMoment;

  for (int index = 0; index < count; index += 1) {
    final Duration gap = Duration(
      seconds: random.nextInt(_largestMessageGapSeconds),
    );
    moment = moment.add(gap);
    final ChatAuthor author = pickOne(random, ChatAuthor.values);
    messages.add(
      ChatMessage(
        at: moment,
        author: author,
        text: markChatText(index, randomChatText(random)),
        isError: random.nextBool(),
        waitingToSend: author == ChatAuthor.you && random.nextBool(),
      ),
    );
  }

  return messages;
}

DateTime? randomLinkLostAt(Random random, List<ChatMessage> messages) {
  final int choice = random.nextInt(4);
  if (choice == 0) {
    return null;
  }
  if (choice == 1 && messages.isNotEmpty) {
    return pickOne(random, messages).at;
  }

  final int spanSeconds = messages.length * _largestMessageGapSeconds;
  final int offsetSeconds =
      random.nextInt(spanSeconds + 2 * _largestMessageGapSeconds) -
      _largestMessageGapSeconds;
  return _firstMessageMoment.add(Duration(seconds: offsetSeconds));
}

Conversation buildChatConversation({
  required List<ChatMessage> messages,
  required DateTime? linkLostAt,
  required AgentActivity agentActivity,
  required RunnerLink link,
}) {
  return Conversation(
    runId: chatPropertyRunId,
    messages: messages,
    link: link,
    linkLostAt: linkLostAt,
    agentActivity: agentActivity,
  );
}

Conversation randomConversationOfAtMost(Random random, int largestCount) {
  final List<ChatMessage> messages = randomChronologicalMessages(
    random,
    count: random.nextInt(largestCount + 1),
  );
  return buildChatConversation(
    messages: messages,
    linkLostAt: randomLinkLostAt(random, messages),
    agentActivity: pickOne(random, AgentActivity.values),
    link: pickOne(random, RunnerLink.values),
  );
}

Conversation randomChatConversation(Random random) {
  final int largestCount = pickOne(random, <int>[
    0,
    2,
    largestFullyShownMessageCount,
    largestChatMessageCount,
  ]);
  return randomConversationOfAtMost(random, largestCount);
}

Conversation randomFullyShownConversation(Random random) {
  return randomConversationOfAtMost(random, largestFullyShownMessageCount);
}

Future<void> pumpChatWidget(
  WidgetTester tester, {
  required Size size,
  required Widget child,
}) async {
  useViewSize(tester, size);
  await tester.pumpWidget(
    wrapInApp(child, platform: platformMeantByWidth(size.width)),
  );
  await tester.pump();
}

Conversation randomShortConversation(Random random) {
  final Conversation conversation = randomFullyShownConversation(random);
  final List<ChatMessage> messages = conversation.messages;
  final List<ChatMessage> shortMessages = <ChatMessage>[
    for (int index = 0; index < messages.length; index += 1)
      ChatMessage(
        at: messages[index].at,
        author: messages[index].author,
        text: markChatText(index, randomWordPhrase(random)),
        isError: messages[index].isError,
        waitingToSend: messages[index].waitingToSend,
      ),
  ];
  return conversation.withMessages(shortMessages);
}
