import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/screens/skills/skill_history_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'random_skills.dart';
import 'skill_history_harness.dart';

List<SkillChange> _randomAgentNewestHistory(Random random) {
  return <SkillChange>[
    ...randomSkillHistory(random),
    SkillChange(
      origin: AutomaticAgentRun(RunId('run-newest-${random.nextInt(99)}')),
      savedAt: galleryNow,
      replacedInstructions: 'Before ${randomText(random)}',
    ),
  ];
}

VoidCallback? _readUndoAction(WidgetTester tester) {
  final AppButton button = tester.widget<AppButton>(
    find.widgetWithText(AppButton, undoLabel),
  );
  return button.onPressed;
}

Future<void> _pumpSection(
  WidgetTester tester,
  double width,
  SkillHistorySection section,
) {
  return pumpScrollableAtWidth(tester, width: width, child: section);
}

void main() {
  testWidgets('test_skill_history_section_create_state_property_a_new_'
      'section_offers_undo', (WidgetTester tester) async {
    final Random random = seededRandom(1121801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillHistorySection section = buildHistorySection(
        history: _randomAgentNewestHistory(random),
        probe: UndoProbe(),
      );

      final State<SkillHistorySection> state = section.createState();
      await pumpHistorySection(tester, random, section);

      expect(state.mounted, isFalse);
      expect(_readUndoAction(tester), isNotNull);
    }
  });

  testWidgets('test_skill_history_section_create_state_property_new_'
      'history_keeps_a_running_undo', (WidgetTester tester) async {
    final Random random = seededRandom(1121802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final UndoProbe probe = UndoProbe();
      final Completer<void> held = Completer<void>();
      probe.heldUndo = held;
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await _pumpSection(
        tester,
        width,
        buildHistorySection(
          history: _randomAgentNewestHistory(random),
          probe: probe,
        ),
      );
      await tapUndo(tester);

      await _pumpSection(
        tester,
        width,
        buildHistorySection(
          history: _randomAgentNewestHistory(random),
          probe: probe,
        ),
      );
      final VoidCallback? whileUndoing = _readUndoAction(tester);
      held.complete();
      await tester.pump();
      await tester.pump();

      expect(whileUndoing, isNull);
      expect(_readUndoAction(tester), isNotNull);
      expect(probe.undoCount, 1);
    }
  });

  testWidgets('test_skill_history_section_create_state_property_a_fresh_'
      'section_forgets_an_old_undo', (WidgetTester tester) async {
    final Random random = seededRandom(1121803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final UndoProbe probe = UndoProbe();
      final Completer<void> held = Completer<void>();
      probe.heldUndo = held;
      await pumpHistorySection(
        tester,
        random,
        buildHistorySection(
          history: _randomAgentNewestHistory(random),
          probe: probe,
        ),
      );
      await tapUndo(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpHistorySection(
        tester,
        random,
        buildHistorySection(
          history: _randomAgentNewestHistory(random),
          probe: UndoProbe(),
        ),
      );

      expect(_readUndoAction(tester), isNotNull);
      held.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
