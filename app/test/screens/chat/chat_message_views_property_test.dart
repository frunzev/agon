import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/chat/chat_message_views.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

import '../../bridge/support/random_moments.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/random_chat_conversations.dart';

const double _tolerance = 0.5;
const List<String> _otherRunnerVerbs = <String>[
  'Wrote',
  'Read',
  'Used',
  'Searched for',
  'Searched the web for',
  'Looked for files matching',
  'Fetched',
  'Listed',
  'Changed',
  'Deleted',
  'Could not change',
];
const List<String> _wordContinuations = <String>['ked', 'dom', 'ness', 's'];

ChatMessage _randomToolMessage(Random random, {required String text}) {
  return ChatMessage(
    at: randomPreciseMoment(random),
    author: ChatAuthor.tool,
    text: text,
    isError: random.nextBool(),
    waitingToSend: false,
  );
}

ChatMessage _toolMessageSaying(String text) {
  return ChatMessage(
    at: DateTime.utc(2026, 11, 8),
    author: ChatAuthor.tool,
    text: text,
    isError: false,
    waitingToSend: false,
  );
}

Finder _findInToolStep(Finder matching) {
  return find.descendant(of: find.byType(ToolStepView), matching: matching);
}

Future<double> _pumpToolStep(
  WidgetTester tester,
  Random random,
  ChatMessage message,
) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: ToolStepView(message: message),
  );
  return width;
}

void main() {
  test(
    'test_choose_tool_step_icon_property_runner_verbs_pick_their_icons',
    () {
      final Random random = seededRandom(97401);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String detail = 'x${randomText(random)}';
        final String otherVerb = pickOne(random, _otherRunnerVerbs);

        final AppIconKind ran = chooseToolStepIcon(
          _toolMessageSaying('Ran $detail'),
        );
        final AppIconKind edited = chooseToolStepIcon(
          _toolMessageSaying('Edited $detail'),
        );
        final AppIconKind other = chooseToolStepIcon(
          _toolMessageSaying('$otherVerb $detail'),
        );

        expect(ran, AppIconKind.terminal);
        expect(edited, AppIconKind.edit);
        expect(other, AppIconKind.check);
      }
    },
  );

  test('test_choose_tool_step_icon_property_only_the_whole_verb_counts', () {
    final Random random = seededRandom(97402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String verb = pickOne(random, <String>['Ran', 'Edited']);
      final String continuation = pickOne(random, _wordContinuations);
      final String text = '$verb$continuation ${randomText(random)}';

      final AppIconKind icon = chooseToolStepIcon(_toolMessageSaying(text));

      expect(icon, AppIconKind.check, reason: text);
    }
  });

  test('test_tool_step_view_constructor_property_keeps_the_message', () {
    final Random random = seededRandom(97403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatMessage message = _randomToolMessage(
        random,
        text: randomChatText(random),
      );

      final ToolStepView view = ToolStepView(message: message);

      expect(identical(view.message, message), isTrue);
    }
  });

  testWidgets('test_tool_step_view_constructor_property_shows_exactly_the_'
      'message_text', (WidgetTester tester) async {
    final Random random = seededRandom(97404);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final ChatMessage message = _randomToolMessage(
        random,
        text: markChatText(i, randomChatText(random)),
      );

      await _pumpToolStep(tester, random, message);

      final Finder text = _findInToolStep(find.byType(Text));
      final Text shown = tester.widget<Text>(text);
      expect(shown.data, message.text);
    }
  });

  testWidgets('test_tool_step_view_constructor_property_a_new_message_'
      'replaces_the_old_one', (WidgetTester tester) async {
    final Random random = seededRandom(97405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ChatMessage first = _randomToolMessage(
        random,
        text: markChatText(0, randomChatText(random)),
      );
      final ChatMessage second = _randomToolMessage(
        random,
        text: markChatText(1, randomChatText(random)),
      );
      final double width = await _pumpToolStep(tester, random, first);

      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: ToolStepView(message: second),
      );

      expect(find.text(first.text), findsNothing);
      expect(find.text(second.text), findsOneWidget);
    }
  });

  testWidgets('test_tool_step_view_build_property_icon_and_colour_follow_'
      'the_message', (WidgetTester tester) async {
    final Random random = seededRandom(97406);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final String verb = pickOne(random, <String>['Ran', 'Edited', 'Read']);
      final ChatMessage message = _randomToolMessage(
        random,
        text: '$verb ${randomChatText(random)}',
      );

      await _pumpToolStep(tester, random, message);

      final Finder iconFinder = _findInToolStep(find.byType(AppIcon));
      final AppIcon icon = tester.widget(iconFinder);
      final Text text = tester.widget(_findInToolStep(find.byType(Text)));
      final Color expected = message.isError
          ? AppColors.danger
          : AppColors.inkMuted;
      expect(icon.kind, chooseToolStepIcon(message));
      expect(icon.color, expected);
      expect(text.style?.color, expected);
    }
  });

  testWidgets('test_tool_step_view_build_property_long_lines_wrap_inside_'
      'the_width', (WidgetTester tester) async {
    final Random random = seededRandom(97407);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final ChatMessage message = _randomToolMessage(
        random,
        text: randomChatText(random),
      );

      final double width = await _pumpToolStep(tester, random, message);

      final Rect text = tester.getRect(_findInToolStep(find.byType(Text)));
      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(text.right, lessThanOrEqualTo(width + _tolerance));
    }
  });

  testWidgets('test_tool_step_view_build_property_icon_leads_monospace_'
      'text', (WidgetTester tester) async {
    final Random random = seededRandom(97408);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ChatMessage message = _randomToolMessage(
        random,
        text: markChatText(i, randomChatText(random)),
      );

      await _pumpToolStep(tester, random, message);

      final Finder iconFinder = _findInToolStep(find.byType(AppIcon));
      final Finder textFinder = _findInToolStep(find.byType(Text));
      final Rect icon = tester.getRect(iconFinder);
      final Text text = tester.widget(textFinder);
      expect(icon.right, lessThanOrEqualTo(tester.getRect(textFinder).left));
      expect(text.style?.fontFamily, AppTextStyles.monospace.fontFamily);
    }
  });
}
