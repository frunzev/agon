import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
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

TextField _readEntryField(WidgetTester tester) {
  return tester.widget<TextField>(
    findInProtectedFiles(find.byType(TextField)),
  );
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

Future<HeldProtectedFilesRepository> _pumpHeldSection(
  WidgetTester tester,
  Random random,
) async {
  final HeldProtectedFilesRepository repository = HeldProtectedFilesRepository(
    inner: await buildRepositoryWithPatterns(randomDistinctPatterns(random)),
  );
  await pumpProtectedFiles(
    tester,
    width: randomSectionWidth(random),
    repository: repository,
  );
  return repository;
}

void main() {
  testWidgets('test_dispose_property_leaving_mid_save_throws_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310961);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldProtectedFilesRepository repository = await _pumpHeldSection(
        tester,
        random,
      );
      await _startRandomChange(tester, random);

      await tester.pumpWidget(const SizedBox.shrink());
      repository.releaseChanges();
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_dispose_property_leaving_mid_refusal_throws_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310962);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldProtectedFilesRepository repository = await _pumpHeldSection(
        tester,
        random,
      );
      final String refused = pickOne(random, readSavedPatterns(repository));

      await typeAndAddPattern(tester, '$refused/');
      await tester.pumpWidget(const SizedBox.shrink());
      repository.releaseChanges();
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_dispose_property_releases_the_entry_controller', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310963);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: await buildRepositoryWithPatterns(const <String>[]),
      );
      final TextEditingController controller = _readEntryField(tester)
          .controller!;

      await tester.pumpWidget(const SizedBox.shrink());

      expect(() => controller.addListener(() {}), throwsFlutterError);
    }
  });

  testWidgets('test_when_idle_property_every_action_is_off_while_saving', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310964);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldProtectedFilesRepository repository = await _pumpHeldSection(
        tester,
        random,
      );

      await _startRandomChange(tester, random);

      for (final VoidCallback? action in _readButtonActions(tester)) {
        expect(action, isNull);
      }
      expect(_readEntryField(tester).onSubmitted, isNull);
      repository.releaseChanges();
      await pumpFrames(tester);
    }
  });

  testWidgets('test_when_idle_property_actions_come_back_after_the_change', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310965);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldProtectedFilesRepository repository = await _pumpHeldSection(
        tester,
        random,
      );
      await _startRandomChange(tester, random);

      repository.releaseChanges();
      await pumpFrames(tester);

      for (final VoidCallback? action in _readButtonActions(tester)) {
        expect(action, isNotNull);
      }
      expect(_readEntryField(tester).onSubmitted, isNotNull);
    }
  });

  testWidgets('test_when_idle_property_taps_while_saving_send_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310966);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldProtectedFilesRepository repository = await _pumpHeldSection(
        tester,
        random,
      );
      await _startRandomChange(tester, random);
      final int changesBefore = repository.saveCount + repository.resetCount;

      final int extraTapCount = 1 + random.nextInt(3);
      for (int tap = 0; tap < extraTapCount; tap += 1) {
        await _startRandomChange(tester, random);
      }

      expect(repository.saveCount + repository.resetCount, changesBefore);
      expect(changesBefore, 1);
      repository.releaseChanges();
      await pumpFrames(tester);
    }
  });

  testWidgets('test_clear_problem_property_typing_clears_the_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310967);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Object refusal = _randomExplainedRefusal(random, i);
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: FailingProtectedFilesRepository(
          inner: await buildRepositoryWithPatterns(const <String>[]),
          failure: refusal,
        ),
      );
      await typeAndAddPattern(tester, randomValidPattern(random));
      expect(readShownProblem(tester), isNotNull);

      await typeIntoPatternEntry(tester, randomText(random));

      expect(readShownProblem(tester), isNull);
    }
  });

  testWidgets('test_clear_problem_property_problem_stays_until_typing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310968);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Object refusal = _randomExplainedRefusal(random, i);
      await pumpProtectedFiles(
        tester,
        width: randomSectionWidth(random),
        repository: FailingProtectedFilesRepository(
          inner: await buildRepositoryWithPatterns(const <String>[]),
          failure: refusal,
        ),
      );
      await typeAndAddPattern(tester, randomValidPattern(random));
      final String? shown = readShownProblem(tester);

      await pumpFrames(tester);

      expect(shown, isNotNull);
      expect(readShownProblem(tester), shown);
      expect(find.text(shown!), findsOneWidget);
    }
  });

  testWidgets('test_clear_problem_property_typing_alone_saves_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310969);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldProtectedFilesRepository repository = await _pumpHeldSection(
        tester,
        random,
      );

      await typeIntoPatternEntry(tester, randomText(random));
      await typeIntoPatternEntry(tester, randomText(random));

      expect(repository.saveCount + repository.resetCount, 0);
      expect(readShownProblem(tester), isNull);
      expect(tester.takeException(), isNull);
    }
  });
}
