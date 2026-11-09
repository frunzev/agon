import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/rules/protected_patterns.dart';

import '../../data/rules/support/protected_pattern_inputs.dart';
import '../../support/random_inputs.dart';
import 'support/protected_files_section_harness.dart';
import 'support/typed_pattern_inputs.dart';

Future<void> _expectTypedPatternFollowsRules(
  WidgetTester tester, {
  required FakeWorkspaceRepository repository,
  required List<String> patternsBefore,
  required String typed,
}) async {
  final String trimmed = typed.trim();
  final List<String> wanted = <String>[...patternsBefore, trimmed];
  final String? problem = describeProtectedFilesProblem(wanted);
  final String reason = 'typed "$typed"';

  if (trimmed.isEmpty) {
    expect(readSavedPatterns(repository), patternsBefore, reason: reason);
    expect(readShownProblem(tester), isNull, reason: reason);
    return;
  }
  if (problem == null) {
    expect(readSavedPatterns(repository), wanted, reason: reason);
    expect(readShownProblem(tester), isNull, reason: reason);
    expect(readPatternEntry(tester), isEmpty, reason: reason);
    return;
  }
  expect(readSavedPatterns(repository), patternsBefore, reason: reason);
  expect(readShownProblem(tester), problem, reason: reason);
  expect(readPatternEntry(tester), typed, reason: reason);
}

void main() {
  testWidgets(
    'test_add_typed_pattern_property_agrees_with_protected_pattern_rules',
    (WidgetTester tester) async {
      final Random random = seededRandom(310921);
      for (int i = 0; i < widgetPropertyIterations * 3; i += 1) {
        final List<String> patterns = randomStoredPatterns(random);
        final FakeWorkspaceRepository repository =
            await buildRepositoryWithPatterns(patterns);
        await pumpProtectedFiles(
          tester,
          width: randomSectionWidth(random),
          repository: repository,
        );
        final String typed = randomTypedPattern(random, patterns);

        await typeAndAddPattern(tester, typed);

        await _expectTypedPatternFollowsRules(
          tester,
          repository: repository,
          patternsBefore: patterns,
          typed: typed,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'test_add_typed_pattern_property_every_repeat_is_refused_with_reason',
    (WidgetTester tester) async {
      final Random random = seededRandom(310922);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final List<String> patterns = randomDistinctPatterns(random);
        final FakeWorkspaceRepository repository =
            await buildRepositoryWithPatterns(patterns);
        await pumpProtectedFiles(
          tester,
          width: randomSectionWidth(random),
          repository: repository,
        );
        final String listed = pickOne(random, patterns);
        final String repeat = randomRepeatOf(random, listed);

        await typeAndAddPattern(tester, padWithBlanks(random, repeat));

        expect(readSavedPatterns(repository), patterns, reason: repeat);
        final String? shown = readShownProblem(tester);
        expect(shown, contains('is listed twice'), reason: repeat);
        expect(shown, contains(listed), reason: repeat);
      }
    },
  );

  testWidgets('test_add_typed_pattern_property_blank_text_saves_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310923);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> patterns = randomStoredPatterns(random);
      final HeldProtectedFilesRepository repository =
          HeldProtectedFilesRepository(
            inner: await buildRepositoryWithPatterns(patterns),
          );
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: repository,
      );

      await typeAndAddPattern(tester, pickOne(random, blankTypedTexts));

      expect(repository.saveCount, 0);
      expect(readSavedPatterns(repository), patterns);
      expect(readShownProblem(tester), isNull);
    }
  });

  testWidgets('test_add_typed_pattern_property_refuses_the_201st_pattern', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310924);
    for (int i = 0; i < 3; i += 1) {
      final int storedCount = maximumProtectedPatternCount - random.nextInt(2);
      final List<String> patterns = <String>[
        for (int position = 0; position < storedCount; position += 1)
          'bulk-$position',
      ];
      final FakeWorkspaceRepository repository =
          await buildRepositoryWithPatterns(patterns);
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: repository,
      );

      await typeAndAddPattern(tester, 'extra-$i');

      final bool fits = storedCount < maximumProtectedPatternCount;
      final int expectedCount = fits ? storedCount + 1 : storedCount;
      final Matcher expectedProblem = fits
          ? isNull
          : contains('at most $maximumProtectedPatternCount patterns');
      expect(readSavedPatterns(repository).length, expectedCount);
      expect(readShownProblem(tester), expectedProblem);
    }
  });

  testWidgets(
    'test_submit_typed_pattern_property_enter_adds_like_the_button',
    (WidgetTester tester) async {
      final Random random = seededRandom(310925);
      for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
        final List<String> patterns = randomStoredPatterns(random);
        final FakeWorkspaceRepository repository =
            await buildRepositoryWithPatterns(patterns);
        await pumpProtectedFiles(
          tester,
          width: randomSectionWidth(random),
          repository: repository,
        );
        final String typed = randomTypedPattern(random, patterns);

        await typeIntoPatternEntry(tester, typed);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        await _expectTypedPatternFollowsRules(
          tester,
          repository: repository,
          patternsBefore: patterns,
          typed: typed,
        );
      }
    },
  );

  testWidgets('test_submit_typed_pattern_property_enter_twice_adds_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310926);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> patterns = randomStoredPatterns(random);
      final String added = 'added-$i/${randomPatternName(random)}';
      final HeldProtectedFilesRepository repository =
          HeldProtectedFilesRepository(
            inner: await buildRepositoryWithPatterns(patterns),
          );
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: repository,
      );

      await typeIntoPatternEntry(tester, added);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      repository.releaseChanges();
      await tester.pump();

      expect(repository.saveCount, 1);
      expect(readSavedPatterns(repository), <String>[...patterns, added]);
    }
  });

  testWidgets('test_submit_typed_pattern_property_enter_on_blank_is_quiet', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310927);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldProtectedFilesRepository repository =
          HeldProtectedFilesRepository(
            inner: await buildRepositoryWithPatterns(
              randomStoredPatterns(random),
            ),
          );
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: repository,
      );

      await typeIntoPatternEntry(tester, pickOne(random, blankTypedTexts));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(repository.saveCount, 0);
      expect(readShownProblem(tester), isNull);
    }
  });
}
