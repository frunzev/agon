import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../data/rules/support/protected_pattern_inputs.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'support/protected_files_section_harness.dart';

const String _workspaceKind = 'workspace';

List<VoidCallback?> _readButtonActions(WidgetTester tester) {
  final Iterable<AppButton> buttons = tester.widgetList<AppButton>(
    findInProtectedFiles(find.byType(AppButton)),
  );
  return <VoidCallback?>[
    for (final AppButton button in buttons) button.onPressed,
  ];
}

Future<void> _startRandomChange(WidgetTester tester, Random random) async {
  final Finder remove = findPatternButton(removePatternLabel);
  final int choice = random.nextInt(3);
  if (choice == 0) {
    await typeAndAddPattern(tester, 'held-${randomPatternName(random)}');
    return;
  }
  if (choice == 1 && remove.evaluate().isNotEmpty) {
    await tapPatternButton(tester, remove.first);
    return;
  }
  await tapPatternButton(tester, findPatternButton(resetPatternsLabel));
}

Object _randomExplainedRefusal(Random random, int position) {
  final String reason = 'reason $position ${randomWordPhrase(random)}x';
  final List<Object> refusals = <Object>[
    PeopleFacingRefusal(reason),
    RecordNotFound(kind: _workspaceKind, identifier: reason),
  ];
  return pickOne(random, refusals);
}

void main() {
  testWidgets('test_apply_change_property_refusal_shown_and_list_unchanged', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310970);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> patterns = randomDistinctPatterns(random);
      final FakeWorkspaceRepository inner = await buildRepositoryWithPatterns(
        patterns,
      );
      final Object refusal = _randomExplainedRefusal(random, i);
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: FailingProtectedFilesRepository(
          inner: inner,
          failure: refusal,
        ),
      );

      await _startRandomChange(tester, random);

      expect(readShownProblem(tester), describeProblemForPeople(refusal));
      expect(readSavedPatterns(inner), patterns);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_apply_change_property_unexplained_problem_escapes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310971);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: FailingProtectedFilesRepository(
          inner: await buildRepositoryWithPatterns(
            randomDistinctPatterns(random),
          ),
          failure: FormatException('broken reply $i'),
        ),
      );
      final List<Object> escaped = <Object>[];

      await runZonedGuarded<Future<void>>(
        () => _startRandomChange(tester, random),
        (Object problem, StackTrace _) => escaped.add(problem),
      );
      await pumpFrames(tester);

      expect(escaped, <Matcher>[isA<FormatException>()]);
      expect(readShownProblem(tester), isNull);
      for (final VoidCallback? action in _readButtonActions(tester)) {
        expect(action, isNotNull);
      }
    }
  });

  testWidgets('test_apply_change_property_success_clears_an_old_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310972);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> patterns = randomDistinctPatterns(random);
      final FakeWorkspaceRepository repository =
          await buildRepositoryWithPatterns(patterns);
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: repository,
      );
      await typeAndAddPattern(tester, pickOne(random, patterns));
      expect(readShownProblem(tester), isNotNull);

      await tapPatternButton(tester, findPatternButton(resetPatternsLabel));

      expect(readShownProblem(tester), isNull);
    }
  });
}
