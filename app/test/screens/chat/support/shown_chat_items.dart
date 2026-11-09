import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/screens/chat/chat_message_views.dart';
import 'package:agent_orchestration/screens/chat/conversation_view.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

import 'random_chat_conversations.dart';

const String lostLinkBannerLabel = 'lost link banner';
const String workingLineLabel = 'working line';

final class ShownChatItem {
  const ShownChatItem({
    required this.label,
    required this.view,
    required this.area,
  });

  final String label;
  final Widget view;
  final Rect area;
}

String? describeChatItem(Widget view) {
  if (view is ToolStepView) {
    return view.message.text;
  }
  if (view is UserMessageView) {
    return view.message.text;
  }
  if (view is AgentMessageView) {
    if (view.text.isEmpty) {
      return workingLineLabel;
    }
    return view.text;
  }
  if (view is NoticeBanner) {
    return lostLinkBannerLabel;
  }
  return null;
}

bool _isChatItem(Widget view) => describeChatItem(view) != null;

int _compareTops(ShownChatItem first, ShownChatItem second) {
  return first.area.top.compareTo(second.area.top);
}

Rect readElementArea(Element element) {
  final RenderBox box = element.renderObject! as RenderBox;
  final Offset topLeft = box.localToGlobal(Offset.zero);
  return topLeft & box.size;
}

List<ShownChatItem> readShownChatItemsTopDown() {
  final List<ShownChatItem> shown = <ShownChatItem>[];
  final Finder chatItems = find.byWidgetPredicate(_isChatItem);

  for (final Element element in chatItems.evaluate()) {
    shown.add(
      ShownChatItem(
        label: describeChatItem(element.widget)!,
        view: element.widget,
        area: readElementArea(element),
      ),
    );
  }

  shown.sort(_compareTops);
  return shown;
}

List<String> labelShownChatItems(List<ShownChatItem> shown) {
  return <String>[for (final ShownChatItem item in shown) item.label];
}

bool isAgentWorkingBeforeItsNextWords(Conversation conversation) {
  if (conversation.agentActivity != AgentActivity.replying) {
    return false;
  }
  final List<ChatMessage> messages = conversation.messages;
  return messages.isEmpty || messages.last.author != ChatAuthor.agent;
}

List<String> listExpectedChatItems(Conversation conversation) {
  final DateTime? linkLostAt = conversation.linkLostAt;
  final List<String> labels = <String>[];

  for (final ChatMessage message in conversation.messages) {
    if (linkLostAt == null || !message.at.isAfter(linkLostAt)) {
      labels.add(message.text);
    }
  }

  if (linkLostAt != null) {
    labels.add(lostLinkBannerLabel);
    for (final ChatMessage message in conversation.messages) {
      if (message.at.isAfter(linkLostAt)) {
        labels.add(message.text);
      }
    }
  }

  if (isAgentWorkingBeforeItsNextWords(conversation)) {
    labels.add(workingLineLabel);
  }
  return labels;
}

List<String> takeNewestLabels(List<String> labels, int count) {
  return labels.sublist(labels.length - count);
}

Future<void> pumpConversationView(
  WidgetTester tester, {
  required Size size,
  required Conversation conversation,
  required String runnerName,
}) {
  return pumpChatWidget(
    tester,
    size: size,
    child: ConversationView(
      conversation: conversation,
      runnerName: runnerName,
    ),
  );
}

Rect readConversationArea(WidgetTester tester) {
  return tester.getRect(find.byType(ConversationView));
}
