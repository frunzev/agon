import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/rules/protected_patterns.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../data/rules/support/protected_pattern_inputs.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'support/protected_files_section_harness.dart';

List<String> _readShownPatterns(List<String> candidates) {
  return <String>[
    for (final String pattern in candidates)
      if (find.text(pattern).evaluate().isNotEmpty) pattern,
  ];
}

Future<void> _performRandomChange(
  WidgetTester tester,
  Random random,
  FakeWorkspaceRepository repository,
) async {
  final int patternCount = readSavedPatterns(repository).length;
  final bool removes = patternCount > 0 && random.nextBool();
  if (removes) {
    final Finder remove = findPatternButton(removePatternLabel);
    await tapPatternButton(tester, remove.at(random.nextInt(patternCount)));
    return;
  }
  await typeAndAddPattern(tester, randomValidPattern(random));
}

void main() {
  testWidgets('test_save_patterns_property_changes_only_the_current_space', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310947);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkspaceRepository repository =
          await buildRepositoryWithPatterns(randomStoredPatterns(random));
      if (random.nextBool()) {
        await repository.switchWorkspace(GalleryWorkspaceIds.personal);
      }
      final Workspace current = repository.currentWorkspace();
      final Map<String, List<String>> othersBefore = <String, List<String>>{
        for (final Workspace workspace in repository.listWorkspaces())
          if (workspace.id != current.id)
            workspace.id.value: workspace.protectedFiles,
      };
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: repository,
      );

      await _performRandomChange(tester, random, repository);

      final Map<String, List<String>> othersAfter = <String, List<String>>{
        for (final Workspace workspace in repository.listWorkspaces())
          if (workspace.id != current.id)
            workspace.id.value: workspace.protectedFiles,
      };
      expect(othersAfter, othersBefore);
      expect(repository.currentWorkspace().id, current.id);
    }
  });

  testWidgets('test_save_patterns_property_saved_list_always_passes_rules', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310948);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkspaceRepository repository =
          await buildRepositoryWithPatterns(randomStoredPatterns(random));
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: repository,
      );
      final int changeCount = 1 + random.nextInt(4);

      for (int change = 0; change < changeCount; change += 1) {
        await _performRandomChange(tester, random, repository);
        final List<String> saved = readSavedPatterns(repository);
        expect(describeProtectedFilesProblem(saved), isNull);
      }
    }
  });

  testWidgets('test_save_patterns_property_rows_always_equal_saved_list', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310949);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkspaceRepository repository =
          await buildRepositoryWithPatterns(randomStoredPatterns(random));
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: repository,
      );
      final int changeCount = 1 + random.nextInt(4);

      for (int change = 0; change < changeCount; change += 1) {
        await _performRandomChange(tester, random, repository);
        final List<String> saved = readSavedPatterns(repository);
        expect(_readShownPatterns(saved), saved);
        expect(
          findPatternButton(removePatternLabel),
          findsNWidgets(saved.length),
        );
      }
    }
  });

  testWidgets(
    'test_save_patterns_then_clear_entry_property_cleared_after_success',
    (WidgetTester tester) async {
      final Random random = seededRandom(310950);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final List<String> patterns = randomStoredPatterns(random);
        final String added = 'added-$i/${randomPatternName(random)}';
        final FakeWorkspaceRepository repository =
            await buildRepositoryWithPatterns(patterns);
        await pumpProtectedFiles(
          tester,
          width: randomSectionWidth(random),
          repository: repository,
        );

        await typeAndAddPattern(tester, padWithBlanks(random, added));

        expect(readPatternEntry(tester), isEmpty);
        expect(readSavedPatterns(repository), <String>[...patterns, added]);
      }
    },
  );

  testWidgets(
    'test_save_patterns_then_clear_entry_property_kept_after_refusal',
    (WidgetTester tester) async {
      final Random random = seededRandom(310951);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final String refusal = 'refused $i: ${randomWordPhrase(random)}x';
        await pumpProtectedFiles(
          tester,
          width: randomSectionWidth(random),
          repository: FailingProtectedFilesRepository(
            inner: await buildRepositoryWithPatterns(const <String>[]),
            failure: PeopleFacingRefusal(refusal),
          ),
        );
        final String typed = randomValidPattern(random);

        await typeAndAddPattern(tester, typed);

        expect(readPatternEntry(tester), typed);
        expect(readShownProblem(tester), refusal);
      }
    },
  );

  testWidgets(
    'test_save_patterns_then_clear_entry_property_kept_until_save_finishes',
    (WidgetTester tester) async {
      final Random random = seededRandom(310952);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final HeldProtectedFilesRepository repository =
            HeldProtectedFilesRepository(
              inner: await buildRepositoryWithPatterns(const <String>[]),
            );
        await pumpProtectedFiles(
          tester,
          width: randomSectionWidth(random),
          repository: repository,
        );
        final String typed = randomValidPattern(random);

        await typeAndAddPattern(tester, typed);
        expect(readPatternEntry(tester), typed);
        final AppButton add = tester.widget<AppButton>(
          findPatternButton(addPatternLabel),
        );
        expect(add.onPressed, isNull);

        repository.releaseChanges();
        await pumpFrames(tester);
        expect(readPatternEntry(tester), isEmpty);
      }
    },
  );
}
