import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/screens/settings.dart';

import '../../data/rules/support/protected_pattern_inputs.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/protected_files_section_harness.dart';

void main() {
  testWidgets(
    'test_protected_files_section_constructor_property_keeps_repository',
    (WidgetTester tester) async {
      final Random random = seededRandom(310901);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final FakeWorkspaceRepository repository =
            await buildRepositoryWithPatterns(randomStoredPatterns(random));
        final Key key = ValueKey<int>(random.nextInt(1000));

        final ProtectedFilesSection section = ProtectedFilesSection(
          workspaceRepository: repository,
          key: key,
        );

        expect(identical(section.workspaceRepository, repository), isTrue);
        expect(section.key, key);
      }
    },
  );

  testWidgets(
    'test_protected_files_section_constructor_property_shows_own_list',
    (WidgetTester tester) async {
      final Random random = seededRandom(310902);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final List<String> patterns = randomStoredPatterns(random);
        final FakeWorkspaceRepository repository =
            await buildRepositoryWithPatterns(patterns);

        await pumpProtectedFiles(
          tester,
          width: randomSectionWidth(random),
          repository: repository,
        );

        final Finder removeButtons = findPatternButton(removePatternLabel);
        expect(removeButtons, findsNWidgets(patterns.length));
        for (final String pattern in patterns) {
          expect(findInProtectedFiles(find.text(pattern)), findsOneWidget);
        }
      }
    },
  );

  testWidgets(
    'test_protected_files_section_constructor_property_needs_no_key',
    (WidgetTester tester) async {
      final FakeWorkspaceRepository repository =
          await buildRepositoryWithPatterns(const <String>[]);

      final ProtectedFilesSection section = ProtectedFilesSection(
        workspaceRepository: repository,
      );

      expect(section.key, isNull);
    },
  );

  testWidgets(
    'test_protected_files_section_create_state_property_new_state_each_call',
    (WidgetTester tester) async {
      final FakeWorkspaceRepository repository =
          await buildRepositoryWithPatterns(const <String>[]);
      final ProtectedFilesSection section = ProtectedFilesSection(
        workspaceRepository: repository,
      );

      final State<ProtectedFilesSection> first = section.createState();
      final State<ProtectedFilesSection> second = section.createState();

      expect(identical(first, second), isFalse);
      expect(first.mounted, isFalse);
      expect(second.mounted, isFalse);
    },
  );

  testWidgets(
    'test_protected_files_section_create_state_property_state_survives_rebuild',
    (WidgetTester tester) async {
      final Random random = seededRandom(310903);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final FakeWorkspaceRepository repository =
            await buildRepositoryWithPatterns(randomStoredPatterns(random));
        final double width = randomSectionWidth(random);
        await pumpProtectedFiles(tester, width: width, repository: repository);
        final String typed = randomValidPattern(random);
        await typeIntoPatternEntry(tester, typed);

        await pumpScrollableAtWidth(
          tester,
          width: width,
          child: ProtectedFilesSection(workspaceRepository: repository),
        );

        expect(readPatternEntry(tester), typed);
      }
    },
  );

  testWidgets(
    'test_protected_files_section_create_state_property_new_key_starts_clean',
    (WidgetTester tester) async {
      final Random random = seededRandom(310904);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final FakeWorkspaceRepository repository =
            await buildRepositoryWithPatterns(randomStoredPatterns(random));
        final double width = randomSectionWidth(random);
        await pumpProtectedFiles(tester, width: width, repository: repository);
        await typeIntoPatternEntry(tester, randomValidPattern(random));

        await pumpScrollableAtWidth(
          tester,
          width: width,
          child: ProtectedFilesSection(
            key: ValueKey<int>(i),
            workspaceRepository: repository,
          ),
        );

        expect(readPatternEntry(tester), isEmpty);
        expect(readShownProblem(tester), isNull);
      }
    },
  );
}
