import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/chat/chat_composer.dart';
import 'package:agent_orchestration/screens/chat/chat_page_layout.dart';
import 'package:agent_orchestration/screens/chat/conversation_view.dart';
import 'package:agent_orchestration/theme/page_metrics.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/route_line.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/random_chat_conversations.dart';
import 'support/random_chat_page_layouts.dart';

const Rect _shortWindows = Rect.fromLTRB(320, 300, 932, 520);
const double _tolerance = 0.5;
const double _scrollSnapTolerance = 1;

Size _randomShortWindow(Random random) {
  final double extraWidth = random.nextDouble() * _shortWindows.width;
  final double extraHeight = random.nextDouble() * _shortWindows.height;
  final double width = _shortWindows.left + extraWidth;
  final double height = _shortWindows.top + extraHeight;
  return Size(width, height);
}

ChatPageLayout _layoutAtRandom(Random random) {
  return buildRandomChatPageLayout(
    random,
    onBack: ignoreGoingBack,
    onSend: acceptEveryMessage,
  );
}

Finder _findHeaderScroll() {
  return find.ancestor(
    of: find.byType(PageHeader),
    matching: find.byType(Scrollable),
  );
}

void main() {
  testWidgets('test_build_fitted_page_property_composer_stays_fully_'
      'visible_on_short_windows', (WidgetTester tester) async {
    final Random random = seededRandom(98101);

    for (int i = 0; i < widgetPropertyIterations * 3; i += 1) {
      final Size size = _randomShortWindow(random);

      await pumpChatWidget(tester, size: size, child: _layoutAtRandom(random));

      final Rect composer = tester.getRect(find.byType(ChatComposer));
      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(composer.top, greaterThanOrEqualTo(0), reason: 'size $size');
      expect(composer.bottom, lessThanOrEqualTo(size.height));
    }
  });

  testWidgets('test_build_fitted_page_property_chat_fills_the_rest_below_'
      'the_header', (WidgetTester tester) async {
    final Random random = seededRandom(98102);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Size size = random.nextBool()
          ? _randomShortWindow(random)
          : randomChatWindowSize(random);

      await pumpChatWidget(tester, size: size, child: _layoutAtRandom(random));

      final Rect header = tester.getRect(_findHeaderScroll());
      final Rect conversation = tester.getRect(find.byType(ConversationView));
      final Rect composer = tester.getRect(find.byType(ChatComposer));
      final double expectedTop = header.bottom + pageGap;
      expect(conversation.top, closeTo(expectedTop, _tolerance));
      expect(composer.top, closeTo(conversation.bottom, _tolerance));
      expect(composer.bottom, lessThanOrEqualTo(size.height));
    }
  });

  testWidgets('test_build_fitted_page_property_roomy_windows_show_the_whole_'
      'header', (WidgetTester tester) async {
    final Random random = seededRandom(98103);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Size size = Size(
        randomWidth(random, least: narrowestWidth, most: widestWidth),
        desktopHeight,
      );

      await pumpChatWidget(tester, size: size, child: _layoutAtRandom(random));

      final ScrollableState header = tester.state(_findHeaderScroll());
      expect(header.position.maxScrollExtent, 0, reason: 'size $size');
    }
  });

  testWidgets('test_build_header_property_a_tall_header_scrolls_to_show_'
      'all_of_it', (WidgetTester tester) async {
    final Random random = seededRandom(98104);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Size size = _randomShortWindow(random);
      final ChatPageLayout layout = _layoutAtRandom(random);
      await pumpChatWidget(tester, size: size, child: layout);

      final Finder lastHeaderPart = find.byType(RouteLine).evaluate().isEmpty
          ? find.byType(PageHeader)
          : find.byType(RouteLine);
      final ScrollableState headerScroll = tester.state(_findHeaderScroll());
      headerScroll.position.jumpTo(headerScroll.position.maxScrollExtent);
      await tester.pump();

      final Rect header = tester.getRect(_findHeaderScroll());
      final Rect lastPart = tester.getRect(lastHeaderPart);
      final double lowestBottom = header.bottom + _scrollSnapTolerance;
      expect(lastPart.bottom, lessThanOrEqualTo(lowestBottom));
      expect(tester.takeException(), isNull, reason: 'size $size');
    }
  });

  testWidgets('test_build_header_property_back_link_title_then_route', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(98105);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final ChatPageLayout layout = _layoutAtRandom(random);

      await pumpChatWidget(
        tester,
        size: randomChatWindowSize(random),
        child: layout,
      );

      final Rect backLink = tester.getRect(find.byType(BackLinkButton));
      final Finder titleInHeader = find.descendant(
        of: find.byType(PageHeader),
        matching: find.text(layout.runContext.agentTitle),
      );
      final Rect title = tester.getRect(titleInHeader.first);
      expect(backLink.bottom, lessThanOrEqualTo(title.top + _tolerance));
      if (find.byType(RouteLine).evaluate().isNotEmpty) {
        final Rect route = tester.getRect(find.byType(RouteLine));
        expect(title.bottom, lessThanOrEqualTo(route.top));
      }
    }
  });

  testWidgets('test_build_header_property_route_is_one_page_gap_below_the_'
      'page_header', (WidgetTester tester) async {
    final Random random = seededRandom(98106);

    for (int i = 0; i < widgetPropertyIterations * 3; i += 1) {
      await pumpChatWidget(
        tester,
        size: const Size(desktopWidth, desktopHeight),
        child: _layoutAtRandom(random),
      );
      if (find.byType(RouteLine).evaluate().isEmpty) {
        continue;
      }

      final Rect header = tester.getRect(find.byType(PageHeader));
      final Rect route = tester.getRect(find.byType(RouteLine));
      expect(route.top - header.bottom, closeTo(pageGap, _tolerance));
    }
  });
}
