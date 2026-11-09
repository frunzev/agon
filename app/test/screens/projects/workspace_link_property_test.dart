import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/projects/workspace_link.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';

const int _largestNameRepeat = 40;

String _randomWorkspaceName(Random random) {
  final String piece = 'w${randomHostileText(random)}';
  return piece * (1 + random.nextInt(_largestNameRepeat));
}

Future<TapCounter> _pumpLink(
  WidgetTester tester,
  Random random,
  String workspaceName,
) async {
  final TapCounter taps = TapCounter();
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          WorkspaceLinkButton(
            workspaceName: workspaceName,
            onPressed: taps.countTap,
          ),
        ],
      ),
    ),
  );
  return taps;
}

void main() {
  test('test_workspace_link_button_new_property_keeps_the_name', () {
    final Random random = seededRandom(1061901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomHostileText(random);
      final TapCounter taps = TapCounter();

      final WorkspaceLinkButton link = WorkspaceLinkButton(
        workspaceName: name,
        onPressed: taps.countTap,
      );

      expect(link.workspaceName, name);
    }
  });

  test('test_workspace_link_button_new_property_keeps_the_callback', () {
    final Random random = seededRandom(1061902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TapCounter taps = TapCounter();
      final int pressCount = random.nextInt(5);
      final WorkspaceLinkButton link = WorkspaceLinkButton(
        workspaceName: randomText(random),
        onPressed: taps.countTap,
      );

      for (int press = 0; press < pressCount; press += 1) {
        link.onPressed();
      }

      expect(taps.count, pressCount);
    }
  });

  test('test_workspace_link_button_new_property_keeps_the_key', () {
    final Random random = seededRandom(1061903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomHostileText(random));
      final WorkspaceLinkButton link = WorkspaceLinkButton(
        workspaceName: '',
        onPressed: TapCounter().countTap,
        key: key,
      );

      expect(link.key, key);
    }
  });

  testWidgets('test_workspace_link_button_build_property_names_the_'
      'workspace_without_overflow', (WidgetTester tester) async {
    final Random random = seededRandom(1061904);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String name = _randomWorkspaceName(random);
      await _pumpLink(tester, random, name);

      expect(find.text('$name workspace'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: name);
    }
  });

  testWidgets('test_workspace_link_button_build_property_one_tap_one_press', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1061905);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String name = _randomWorkspaceName(random);
      final TapCounter taps = await _pumpLink(tester, random, name);
      final int tapCount = 1 + random.nextInt(3);

      for (int tap = 0; tap < tapCount; tap += 1) {
        await tester.tap(find.byType(TextButton));
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(taps.count, tapCount);
    }
  });

  testWidgets('test_workspace_link_button_build_property_sits_left_with_'
      'a_chevron', (WidgetTester tester) async {
    final Random random = seededRandom(1061906);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String name = _randomWorkspaceName(random);
      await _pumpLink(tester, random, name);

      final Rect link = tester.getRect(find.byType(TextButton));
      final Rect chevron = tester.getRect(find.byType(AppIcon));
      final AppIcon icon = tester.widget(find.byType(AppIcon));
      expect(link.left, closeTo(0, 0.5));
      expect(chevron.right, lessThanOrEqualTo(link.right + 0.5));
      expect(icon.kind, AppIconKind.chevronDown);
    }
  });
}
