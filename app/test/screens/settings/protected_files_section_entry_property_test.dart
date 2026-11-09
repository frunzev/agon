import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

import '../../data/rules/support/protected_pattern_inputs.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/protected_files_section_harness.dart';

Future<void> _pumpListeningSection(
  WidgetTester tester, {
  required double width,
  required FakeWorkspaceRepository repository,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: ListenableBuilder(
      listenable: repository,
      builder: (BuildContext context, Widget? child) =>
          ProtectedFilesSection(workspaceRepository: repository),
    ),
  );
}

List<String> _readShownPatterns(List<String> candidates) {
  return <String>[
    for (final String pattern in candidates)
      if (find.text(pattern).evaluate().isNotEmpty) pattern,
  ];
}

void main() {
  testWidgets('test_read_patterns_property_shows_the_latest_saved_list', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310941);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkspaceRepository repository =
          await buildRepositoryWithPatterns(randomStoredPatterns(random));
      await _pumpListeningSection(
        tester,
        width: randomSectionWidth(random),
        repository: repository,
      );
      final List<String> changed = randomDistinctPatterns(random);

      await repository.saveProtectedFiles(
        workspaceId: GalleryWorkspaceIds.acme,
        patterns: changed,
      );
      await tester.pump();

      expect(
        findPatternButton(removePatternLabel),
        findsNWidgets(changed.length),
      );
      expect(_readShownPatterns(changed), changed);
    }
  });

  testWidgets('test_read_patterns_property_follows_a_workspace_switch', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310942);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkspaceRepository repository =
          await buildRepositoryWithPatterns(randomStoredPatterns(random));
      final List<String> personalPatterns = randomDistinctPatterns(random);
      await repository.saveProtectedFiles(
        workspaceId: GalleryWorkspaceIds.personal,
        patterns: personalPatterns,
      );
      await _pumpListeningSection(
        tester,
        width: randomSectionWidth(random),
        repository: repository,
      );

      await repository.switchWorkspace(GalleryWorkspaceIds.personal);
      await tester.pump();

      expect(_readShownPatterns(personalPatterns), personalPatterns);
      expect(
        findPatternButton(removePatternLabel),
        findsNWidgets(personalPatterns.length),
      );
    }
  });

  testWidgets('test_read_patterns_property_add_appends_to_the_latest_list', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310943);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkspaceRepository repository =
          await buildRepositoryWithPatterns(randomStoredPatterns(random));
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: repository,
      );
      final List<String> changedElsewhere = randomDistinctPatterns(random);
      await repository.saveProtectedFiles(
        workspaceId: GalleryWorkspaceIds.acme,
        patterns: changedElsewhere,
      );
      final String added = 'added-$i/${randomPatternName(random)}';

      await typeAndAddPattern(tester, added);

      expect(readSavedPatterns(repository), <String>[
        ...changedElsewhere,
        added,
      ]);
    }
  });

  testWidgets('test_build_entry_row_property_add_button_has_control_height', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310944);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomSectionWidth(random);
      await pumpProtectedFiles(
        tester,
        width: width,
        repository: await buildRepositoryWithPatterns(const <String>[]),
      );

      final double expectedHeight = AppSizes.controlHeightFor(
        densityMeantByWidth(width),
      );
      final Size button = tester.getSize(findPatternButton(addPatternLabel));
      expect(button.height, closeTo(expectedHeight, 0.01), reason: '$width');
    }
  });

  testWidgets('test_build_entry_row_property_field_is_plain_monospace_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310945);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: await buildRepositoryWithPatterns(const <String>[]),
      );

      final TextField field = tester.widget<TextField>(
        findInProtectedFiles(find.byType(TextField)),
      );
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.style?.fontFamily, AppFontFamilies.monospace);
      expect(field.decoration?.hintText, protectedFilesHint);
    }
  });

  testWidgets('test_build_entry_row_property_field_and_button_fit_the_width', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310946);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomSectionWidth(random);
      await pumpProtectedFiles(
        tester,
        width: width,
        repository: await buildRepositoryWithPatterns(const <String>[]),
      );

      final Rect field = tester.getRect(
        findInProtectedFiles(find.byType(TextField)),
      );
      final Rect button = tester.getRect(findPatternButton(addPatternLabel));
      expect(field.right, lessThanOrEqualTo(button.left), reason: '$width');
      expect(button.right, lessThanOrEqualTo(width), reason: '$width');
      expect(field.left, greaterThanOrEqualTo(0), reason: '$width');
    }
  });
}
