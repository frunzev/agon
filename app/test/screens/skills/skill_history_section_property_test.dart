import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/screens/skills/skill_history_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';

import '../../support/random_inputs.dart';
import 'random_skills.dart';
import 'skill_history_harness.dart';

const int _mostHostileExtraChanges = 6;
const int _largestShiftInDays = 400;

String _modelTitle(SkillChangeOrigin origin) {
  return switch (origin) {
    PersonEdit() => 'Changed by you',
    ApprovedAgentRun() => 'Improved by an agent, approved by you',
    AutomaticAgentRun() => 'Improved by an agent automatically',
  };
}

SkillChangeOrigin _randomAgentOrigin(Random random) {
  final RunId runId = RunId('run-agent-${random.nextInt(1000)}');
  if (random.nextBool()) {
    return ApprovedAgentRun(runId);
  }
  return AutomaticAgentRun(runId);
}

List<SkillChange> _randomLongHistory(Random random) {
  final List<SkillChange> kept = randomSkillHistory(random);
  final int extraCount = random.nextInt(_mostHostileExtraChanges);
  return <SkillChange>[
    for (int i = 0; i < extraCount; i += 1)
      SkillChange(
        origin: randomSkillChangeOrigin(random),
        savedAt: galleryDaysAgo(keptSkillChangeCount + extraCount - i),
        replacedInstructions: 'Extra $i',
      ),
    ...kept,
  ];
}

DateTime _shiftByCalendarDays(DateTime moment, int days) {
  final DateTime localMoment = moment.toLocal();
  return DateTime(
    localMoment.year,
    localMoment.month,
    localMoment.day + days,
    localMoment.hour,
    localMoment.minute,
    localMoment.second,
  );
}

List<SkillChange> _shiftHistory(List<SkillChange> history, int days) {
  return <SkillChange>[
    for (final SkillChange change in history)
      SkillChange(
        origin: change.origin,
        savedAt: _shiftByCalendarDays(change.savedAt, days),
        replacedInstructions: change.replacedInstructions,
      ),
  ];
}

void main() {
  test('test_skill_history_section_constructor_property_keeps_every_'
      'field', () {
    final Random random = seededRandom(1121201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final List<SkillChange> history = randomSkillHistory(random);
      final DateTime now = randomLocalMoment(random);
      final UndoProbe probe = UndoProbe();

      final SkillHistorySection section = SkillHistorySection(
        history: history,
        taskRepository: dependencies.taskRepository,
        workflows: dependencies.workflowRepository.listWorkflows(),
        now: now,
        onUndo: probe.undo,
      );

      expect(section.history, same(history));
      expect(section.taskRepository, same(dependencies.taskRepository));
      expect(section.now, now);
      expect(section.onUndo, probe.undo);
      expect(probe.undoCount, 0);
    }
  });

  testWidgets('test_skill_history_section_constructor_property_undo_runs_'
      'the_given_callback_once', (WidgetTester tester) async {
    final Random random = seededRandom(1121202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final UndoProbe probe = UndoProbe();
      final List<SkillChange> history = <SkillChange>[
        ...randomSkillHistory(random),
        SkillChange(
          origin: _randomAgentOrigin(random),
          savedAt: galleryNow,
          replacedInstructions: 'Before',
        ),
      ];
      await pumpHistorySection(
        tester,
        random,
        buildHistorySection(history: history, probe: probe),
      );

      await tapUndo(tester);

      expect(probe.undoCount, 1);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_skill_history_section_constructor_property_moving_now_'
      'and_changes_together_changes_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1121203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<SkillChange> history = randomSkillHistory(random);
      final int shift =
          random.nextInt(_largestShiftInDays) - _largestShiftInDays ~/ 2;
      final UndoProbe probe = UndoProbe();
      await pumpHistorySection(
        tester,
        random,
        buildHistorySection(history: history, probe: probe),
      );
      final List<ShownHistoryRow> before = readShownHistoryRows(tester);

      await pumpHistorySection(
        tester,
        random,
        buildHistorySection(
          history: _shiftHistory(history, shift),
          probe: probe,
          now: _shiftByCalendarDays(galleryNow, shift),
        ),
      );

      expect(readShownHistoryRows(tester), before, reason: '$shift');
    }
  });

  testWidgets('test_skill_history_section_build_property_newest_five_'
      'first_up_to_and_past_the_limit', (WidgetTester tester) async {
    final Random random = seededRandom(1121204);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<SkillChange> history = _randomLongHistory(random);
      final double width = await pumpHistorySection(
        tester,
        random,
        buildHistorySection(history: history, probe: UndoProbe()),
      );

      final List<String> expectedTitles = <String>[
        for (final SkillChange change in history.reversed.take(
          shownSkillChangeCount,
        ))
          _modelTitle(change.origin),
      ];
      final List<String> shownTitles = <String>[
        for (final ShownHistoryRow row in readShownHistoryRows(tester))
          row.title,
      ];
      expect(shownTitles, expectedTitles, reason: '$width');
      expect(
        find.text(noChangesNote),
        history.isEmpty ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull, reason: '$width');
    }
  });

  testWidgets('test_skill_history_section_build_property_undo_only_on_'
      'the_newest_row_when_an_agent_made_it', (WidgetTester tester) async {
    final Random random = seededRandom(1121205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<SkillChange> history = _randomLongHistory(random);
      await pumpHistorySection(
        tester,
        random,
        buildHistorySection(history: history, probe: UndoProbe()),
      );

      final bool isAgentNewest =
          history.isNotEmpty && history.last.origin is AgentRunOrigin;
      final Matcher undoShown = isAgentNewest ? findsOneWidget : findsNothing;
      expect(find.text(undoLabel), undoShown);
      if (isAgentNewest && history.length > 1) {
        final double undoTop = tester.getTopLeft(find.text(undoLabel)).dy;
        final List<double> rowTops = <double>[
          for (final Element row in find.byType(ListRowMain).evaluate())
            tester.getTopLeft(find.byWidget(row.widget)).dy,
        ];
        expect(undoTop, lessThan(rowTops[1]));
      }
    }
  });

  testWidgets('test_skill_history_section_build_property_equal_changes_'
      'all_show', (WidgetTester tester) async {
    final Random random = seededRandom(1121206);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillChange model = SkillChange(
        origin: randomSkillChangeOrigin(random),
        savedAt: galleryDaysAgo(1 + random.nextInt(9)),
        replacedInstructions: randomText(random),
      );
      final int count = 1 + random.nextInt(shownSkillChangeCount + 3);
      final List<SkillChange> history = <SkillChange>[
        for (int copy = 0; copy < count; copy += 1)
          SkillChange(
            origin: model.origin,
            savedAt: model.savedAt,
            replacedInstructions: model.replacedInstructions,
          ),
      ];
      await pumpHistorySection(
        tester,
        random,
        buildHistorySection(history: history, probe: UndoProbe()),
      );

      expect(tester.takeException(), isNull);
      expect(
        readShownHistoryRows(tester),
        hasLength(min(count, shownSkillChangeCount)),
      );
      final int undoCount = model.origin is AgentRunOrigin ? 1 : 0;
      expect(
        find.widgetWithText(AppButton, undoLabel),
        findsNWidgets(undoCount),
      );
    }
  });
}
