import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/rules/default_protected_patterns.dart';

import '../../data/rules/support/protected_pattern_inputs.dart';
import '../../support/random_inputs.dart';
import 'support/protected_files_section_harness.dart';

const int _rustDefaultPatternCount = 50;

void main() {
  testWidgets('test_remove_pattern_property_removes_exactly_the_tapped_one', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310928);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> patterns = randomDistinctPatterns(random);
      final int removedIndex = random.nextInt(patterns.length);
      final FakeWorkspaceRepository repository =
          await buildRepositoryWithPatterns(patterns);
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: repository,
      );

      await tapPatternButton(
        tester,
        findPatternButton(removePatternLabel).at(removedIndex),
      );

      final List<String> expected = <String>[...patterns]
        ..removeAt(removedIndex);
      expect(readSavedPatterns(repository), expected);
      expect(find.text(patterns[removedIndex]), findsNothing);
    }
  });

  testWidgets('test_remove_pattern_property_removing_all_empties_the_list', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310929);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> patterns = randomDistinctPatterns(random);
      final FakeWorkspaceRepository repository =
          await buildRepositoryWithPatterns(patterns);
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: repository,
      );

      for (int left = patterns.length; left > 0; left -= 1) {
        final int index = random.nextInt(left);
        await tapPatternButton(
          tester,
          findPatternButton(removePatternLabel).at(index),
        );
        expect(readSavedPatterns(repository).length, left - 1);
      }

      expect(readSavedPatterns(repository), isEmpty);
      expect(findPatternButton(removePatternLabel), findsNothing);
    }
  });

  testWidgets('test_remove_pattern_property_keeps_the_typed_entry', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310930);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> patterns = randomDistinctPatterns(random);
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: await buildRepositoryWithPatterns(patterns),
      );
      final String typed = randomValidPattern(random);
      await typeIntoPatternEntry(tester, typed);

      await tapPatternButton(
        tester,
        findPatternButton(removePatternLabel)
            .at(random.nextInt(patterns.length)),
      );

      expect(readPatternEntry(tester), typed);
    }
  });

  testWidgets('test_reset_patterns_property_restores_the_rust_defaults', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310931);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkspaceRepository repository =
          await buildRepositoryWithPatterns(randomStoredPatterns(random));
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: repository,
      );

      await tapPatternButton(tester, findPatternButton(resetPatternsLabel));

      final List<String> saved = readSavedPatterns(repository);
      expect(saved, defaultProtectedPatterns);
      expect(saved.length, _rustDefaultPatternCount);
      expect(
        findPatternButton(removePatternLabel),
        findsNWidgets(_rustDefaultPatternCount),
      );
    }
  });

  testWidgets('test_reset_patterns_property_is_idempotent', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310932);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkspaceRepository repository =
          await buildRepositoryWithPatterns(randomStoredPatterns(random));
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: repository,
      );
      final int resetCount = 1 + random.nextInt(3);

      for (int reset = 0; reset < resetCount; reset += 1) {
        await tapPatternButton(tester, findPatternButton(resetPatternsLabel));
        expect(readSavedPatterns(repository), defaultProtectedPatterns);
      }
      expect(readShownProblem(tester), isNull);
    }
  });

  testWidgets('test_reset_patterns_property_keeps_the_typed_entry', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310933);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: await buildRepositoryWithPatterns(
          randomStoredPatterns(random),
        ),
      );
      final String typed = randomValidPattern(random);
      await typeIntoPatternEntry(tester, typed);

      await tapPatternButton(tester, findPatternButton(resetPatternsLabel));

      expect(readPatternEntry(tester), typed);
    }
  });
}
