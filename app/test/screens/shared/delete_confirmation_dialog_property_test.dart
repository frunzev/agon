import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/shared/delete_confirmation_dialog.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const String _openLabel = 'Open the dialog';
const String _cannotBeUndoneNote = "This can't be undone.";
const int _largestKeyNumber = 1000;
const int _mostFacts = 2;

List<Fact> _randomFacts(Random random) {
  final int factCount = random.nextInt(_mostFacts + 1);
  return <Fact>[
    for (int i = 0; i < factCount; i += 1)
      Fact(
        term: 'Term $i',
        description: <TextSegment>[TextSegment('Fact ${randomText(random)}')],
      ),
  ];
}

DeleteConfirmationDialog _randomDialog(Random random) {
  return DeleteConfirmationDialog(
    title: 'Delete ${randomText(random)}?',
    explanation: 'Explanation ${randomText(random)}',
    facts: _randomFacts(random),
    keepLabel: 'Keep ${randomWordPhrase(random)}',
    deleteLabel: 'Remove ${randomWordPhrase(random)}',
  );
}

final class _DialogLauncher {
  _DialogLauncher(this.dialog);

  final DeleteConfirmationDialog dialog;
  final List<DeleteChoice?> choices = <DeleteChoice?>[];

  Widget build() {
    return Builder(
      builder: (BuildContext context) => AppButton.secondary(
        label: _openLabel,
        onPressed: () => _open(context),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final DeleteChoice? choice = await showAppDialog<DeleteChoice>(
      context: context,
      builder: (BuildContext _) => dialog,
    );
    choices.add(choice);
  }
}

Future<_DialogLauncher> _openRandomDialog(
  WidgetTester tester,
  Random random,
) async {
  final _DialogLauncher launcher = _DialogLauncher(_randomDialog(random));
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  useViewSize(tester, Size(width, desktopHeight));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    wrapInApp(launcher.build(), platform: platformMeantByWidth(width)),
  );
  await tapVisible(tester, find.text(_openLabel));
  await pumpFrames(tester);
  return launcher;
}

void main() {
  test('test_delete_confirmation_dialog_constructor_property_keeps_every_'
      'field', () {
    final Random random = seededRandom(111601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Fact> facts = _randomFacts(random);
      final String title = randomText(random);
      final String explanation = randomText(random);

      final DeleteConfirmationDialog dialog = DeleteConfirmationDialog(
        title: title,
        explanation: explanation,
        facts: facts,
        keepLabel: 'Keep',
        deleteLabel: 'Delete',
      );

      expect(dialog.title, title);
      expect(dialog.explanation, explanation);
      expect(dialog.facts, same(facts));
      expect(dialog.keepLabel, 'Keep');
      expect(dialog.deleteLabel, 'Delete');
    }
  });

  test('test_delete_confirmation_dialog_constructor_property_keeps_the_'
      'key', () {
    final Random random = seededRandom(111602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(_largestKeyNumber));

      final DeleteConfirmationDialog dialog = DeleteConfirmationDialog(
        title: randomText(random),
        explanation: randomText(random),
        facts: const <Fact>[],
        keepLabel: randomText(random),
        deleteLabel: randomText(random),
        key: key,
      );

      expect(dialog.key, key);
    }
  });

  test('test_delete_confirmation_dialog_constructor_property_choices_are_'
      'keep_or_delete', () {
    expect(DeleteChoice.values, <DeleteChoice>[
      DeleteChoice.keep,
      DeleteChoice.delete,
    ]);
    expect(DeleteChoice.keep, isNot(DeleteChoice.delete));
  });

  testWidgets('test_delete_confirmation_dialog_build_property_shows_the_'
      'whole_prompt_at_any_width', (WidgetTester tester) async {
    final Random random = seededRandom(111603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DialogLauncher launcher = await _openRandomDialog(tester, random);
      final DeleteConfirmationDialog dialog = launcher.dialog;

      expect(tester.takeException(), isNull);
      expect(find.text(dialog.title), findsOneWidget);
      expect(find.text(dialog.explanation), findsOneWidget);
      expect(find.text(_cannotBeUndoneNote), findsOneWidget);
      expect(find.text(dialog.keepLabel), findsOneWidget);
      expect(find.text(dialog.deleteLabel), findsOneWidget);
      expect(
        find.byType(FactList),
        findsNWidgets(dialog.facts.isEmpty ? 0 : 1),
      );
    }
  });

  testWidgets('test_delete_confirmation_dialog_build_property_each_button_'
      'answers_its_choice', (WidgetTester tester) async {
    final Random random = seededRandom(111604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DialogLauncher launcher = await _openRandomDialog(tester, random);
      final DeleteChoice expected = pickOne(random, DeleteChoice.values);
      final String label = expected == DeleteChoice.keep
          ? launcher.dialog.keepLabel
          : launcher.dialog.deleteLabel;

      await tapVisible(tester, find.text(label));
      await pumpFrames(tester);

      expect(launcher.choices, <DeleteChoice?>[expected]);
      expect(find.text(launcher.dialog.title), findsNothing);
    }
  });

  testWidgets('test_delete_confirmation_dialog_build_property_dismissing_'
      'never_answers_delete', (WidgetTester tester) async {
    final Random random = seededRandom(111605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DialogLauncher launcher = await _openRandomDialog(tester, random);

      await tester.tapAt(const Offset(1, 1));
      await pumpFrames(tester);

      expect(launcher.choices, <DeleteChoice?>[null]);
    }
  });
}
