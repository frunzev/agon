import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/tasks/task_form_screen.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'task_form_screen_inputs.dart';
import 'task_form_screen_scene.dart';

const String _titleLabel = 'What should be done?';

String _readTitleField(WidgetTester tester) {
  final EditableText field = tester.widget<EditableText>(
    find.descendant(
      of: findFieldInput(_titleLabel),
      matching: find.byType(EditableText),
    ),
  );
  return field.controller.text;
}

void main() {
  testWidgets('test_task_form_screen_build_property_header_matches_the_form', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(116407);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Task? existing = randomExistingTask(random);
      await openTaskFormScene(
        tester,
        random: random,
        formRoute: formRouteFor(existing),
      );

      final PageHeader header = tester.widget<PageHeader>(
        find.descendant(
          of: find.byType(TaskFormScreen),
          matching: find.byType(PageHeader),
        ),
      );
      expect(header.title, existing == null ? 'New task' : 'Edit task');
      expect(header.backLink?.label, 'Tasks');
      final Finder delete = find.descendant(
        of: find.byType(TaskFormScreen),
        matching: find.widgetWithText(AppButton, 'Delete'),
      );
      expect(delete, findsNWidgets(existing == null ? 0 : 1));
    }
  });

  testWidgets('test_task_form_screen_build_property_starts_from_the_task', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(116408);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Task? existing = randomExistingTask(random);
      await openTaskFormScene(
        tester,
        random: random,
        formRoute: formRouteFor(existing),
      );

      expect(_readTitleField(tester), existing?.title ?? '');
    }
  });

  testWidgets('test_task_form_screen_build_property_fits_at_random_widths', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(116409);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Task? existing = randomExistingTask(random);
      final TaskFormScene scene = await openTaskFormScene(
        tester,
        random: random,
        formRoute: formRouteFor(existing),
      );
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );

      useViewSize(tester, Size(width, desktopHeight));
      await pumpFrames(tester);

      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(find.byType(TaskFormScreen), findsOneWidget);
      expect(scene.navigation.currentRoute, formRouteFor(existing));
    }
  });
}
