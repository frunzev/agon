import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/devices/workspace_devices_section.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/inline_link.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'support/random_devices_page.dart';

const String _removalNoteStart =
    'Removing a device here only takes it out of acme. '
    'To cut it off everywhere, revoke it in ';

void main() {
  testWidgets('test_build_removal_note_property_names_workspace_and_link', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73110);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpDevicesPage(
        tester,
        random: random,
        dependencies: buildRandomDevicesDependencies(random),
      );

      final Finder note = find.textContaining(
        _removalNoteStart,
        findRichText: true,
      );
      final Finder link = find.widgetWithText(InlineLink, allDevicesTitle);
      expect(note, findsOneWidget);
      expect(find.descendant(of: note, matching: link), findsOneWidget);
    }
  });

  testWidgets('test_build_removal_note_property_link_shows_all_devices', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73111);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = await pumpDevicesPage(
        tester,
        random: random,
        dependencies: buildRandomDevicesDependencies(random),
      );
      final AppRoute routeBefore = navigation.currentRoute;
      final Finder link = find.widgetWithText(InlineLink, allDevicesTitle);
      await tester.ensureVisible(link);
      await pumpFrames(tester);

      await tester.tap(link);
      await pumpFrames(tester);

      final Finder heading = find.descendant(
        of: findDevicesSection(allDevicesSectionTitle),
        matching: find.text(allDevicesSectionTitle),
      );
      final double headingTop = tester.getTopLeft(heading.first).dy;
      final double windowHeight = tester.view.physicalSize.height;
      expect(headingTop, inInclusiveRange(0, windowHeight));
      expect(navigation.currentRoute, routeBefore);
    }
  });

  testWidgets('test_build_removal_note_property_note_ends_in_a_full_stop', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73112);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpDevicesPage(
        tester,
        random: random,
        dependencies: buildRandomDevicesDependencies(random),
      );

      final RichText note = tester.widget<RichText>(
        find.textContaining(_removalNoteStart, findRichText: true),
      );
      final String plainNote = note.text.toPlainText(
        includePlaceholders: false,
      );
      expect(plainNote, '$_removalNoteStart.');
    }
  });
}
