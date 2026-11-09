import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/screens/shared/run_label_lookup.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/random_inputs.dart';
import 'random_skills.dart';
import 'skill_history_harness.dart';

const List<RunId> _knownRunIds = <RunId>[
  GalleryRunIds.release41,
  GalleryRunIds.release42,
];

SkillChange _buildChange(SkillChangeOrigin origin, int daysAgo) {
  return SkillChange(
    origin: origin,
    savedAt: galleryDaysAgo(daysAgo),
    replacedInstructions: 'Before $daysAgo',
  );
}

SkillChangeOrigin _randomAgentOrigin(Random random, RunId runId) {
  if (random.nextBool()) {
    return ApprovedAgentRun(runId);
  }
  return AutomaticAgentRun(runId);
}

List<SkillChange> _randomAgentNewestHistory(Random random) {
  return <SkillChange>[
    ...randomSkillHistory(random),
    _buildChange(_randomAgentOrigin(random, GalleryRunIds.release41), 0),
  ];
}

VoidCallback? _readUndoAction(WidgetTester tester) {
  final AppButton button = tester.widget<AppButton>(
    find.widgetWithText(AppButton, undoLabel),
  );
  return button.onPressed;
}

void main() {
  final AppDependencies gallery = buildGalleryDependencies();

  testWidgets('test_skill_history_section_build_row_property_titles_follow_'
      'the_design_wording', (WidgetTester tester) async {
    final Random random = seededRandom(1121301);
    const Map<Type, String> titleByOrigin = <Type, String>{
      PersonEdit: 'Changed by you',
      ApprovedAgentRun: 'Improved by an agent, approved by you',
      AutomaticAgentRun: 'Improved by an agent automatically',
    };

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<SkillChange> history = randomSkillHistory(random);
      await pumpHistorySection(
        tester,
        random,
        buildHistorySection(history: history, probe: UndoProbe()),
      );

      final List<ShownHistoryRow> rows = readShownHistoryRows(tester);
      final List<SkillChange> newestFirst = history.reversed.toList();
      for (int row = 0; row < rows.length; row += 1) {
        final Type origin = newestFirst[row].origin.runtimeType;
        expect(rows[row].title, titleByOrigin[origin]);
      }
    }
  });

  testWidgets('test_skill_history_section_build_row_property_every_row_'
      'says_when', (WidgetTester tester) async {
    final Random random = seededRandom(1121302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<SkillChange> history = randomSkillHistory(random);
      await pumpHistorySection(
        tester,
        random,
        buildHistorySection(history: history, probe: UndoProbe()),
      );

      for (final ShownHistoryRow row in readShownHistoryRows(tester)) {
        expect(row.subtitle, isNotEmpty);
        expect(row.subtitle.endsWith(momentSeparator), isFalse);
        expect(row.subtitle.startsWith(momentSeparator), isFalse);
      }
    }
  });

  testWidgets('test_skill_history_section_build_row_property_the_design_'
      'example_reads_the_same', (WidgetTester tester) async {
    final Random random = seededRandom(1121303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<SkillChange> history = <SkillChange>[
        _buildChange(const PersonEdit(), 5),
        _buildChange(const AutomaticAgentRun(GalleryRunIds.release42), 3),
        SkillChange(
          origin: const ApprovedAgentRun(GalleryRunIds.release41),
          savedAt: galleryToday(12, 9),
          replacedInstructions: 'Before',
        ),
      ];
      await pumpHistorySection(
        tester,
        random,
        buildHistorySection(history: history, probe: UndoProbe()),
      );

      expect(readShownHistoryRows(tester), <ShownHistoryRow>[
        (
          title: 'Improved by an agent, approved by you',
          subtitle: 'release #41 · 2 h ago',
        ),
        (
          title: 'Improved by an agent automatically',
          subtitle: 'release #42 · 3 days ago',
        ),
        (title: 'Changed by you', subtitle: '5 days ago'),
      ]);
    }
  });

  testWidgets('test_find_change_run_label_property_person_edits_name_no_'
      'run', (WidgetTester tester) async {
    final Random random = seededRandom(1121304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int count = 1 + random.nextInt(shownSkillChangeCount);
      final List<SkillChange> history = <SkillChange>[
        for (int change = 0; change < count; change += 1)
          _buildChange(const PersonEdit(), count - change),
      ];
      await pumpHistorySection(
        tester,
        random,
        buildHistorySection(history: history, probe: UndoProbe()),
      );

      for (final ShownHistoryRow row in readShownHistoryRows(tester)) {
        expect(row.subtitle.contains(momentSeparator), isFalse);
      }
    }
  });

  testWidgets('test_find_change_run_label_property_agrees_with_the_run_'
      'lookup', (WidgetTester tester) async {
    final Random random = seededRandom(1121305);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool isKnown = random.nextBool();
      final RunId runId = isKnown
          ? pickOne(random, _knownRunIds)
          : RunId('gone-${random.nextInt(1000)}');
      await pumpHistorySection(
        tester,
        random,
        buildHistorySection(
          history: <SkillChange>[
            _buildChange(_randomAgentOrigin(random, runId), 2),
          ],
          probe: UndoProbe(),
        ),
      );

      final String? runLabel = findRunLabel(
        runId: runId,
        taskRepository: gallery.taskRepository,
        workflows: gallery.workflowRepository.listWorkflows(),
      );
      final String subtitle = readShownHistoryRows(tester).single.subtitle;
      expect(runLabel == null, !isKnown);
      expect(subtitle.startsWith('$runLabel$momentSeparator'), isKnown);
      expect(subtitle.contains(momentSeparator), isKnown);
    }
  });

  testWidgets('test_find_change_run_label_property_a_gone_run_never_breaks_'
      'the_list', (WidgetTester tester) async {
    final Random random = seededRandom(1121306);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<SkillChange> history = <SkillChange>[
        for (int change = 0; change < shownSkillChangeCount; change += 1)
          _buildChange(
            _randomAgentOrigin(random, RunId(randomText(random))),
            shownSkillChangeCount - change,
          ),
      ];
      await pumpHistorySection(
        tester,
        random,
        buildHistorySection(history: history, probe: UndoProbe()),
      );

      expect(tester.takeException(), isNull);
      expect(readShownHistoryRows(tester), hasLength(shownSkillChangeCount));
      expect(find.text(undoLabel), findsOneWidget);
    }
  });

  testWidgets('test_skill_history_section_undo_latest_change_property_a_'
      'double_tap_undoes_once', (WidgetTester tester) async {
    final Random random = seededRandom(1121307);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final UndoProbe probe = UndoProbe();
      probe.heldUndo = Completer<void>();
      await pumpHistorySection(
        tester,
        random,
        buildHistorySection(
          history: _randomAgentNewestHistory(random),
          probe: probe,
        ),
      );

      await tester.tap(find.text(undoLabel));
      await tester.tap(find.text(undoLabel), warnIfMissed: false);
      await tester.pump();
      probe.heldUndo!.complete();
      await tester.pump();

      expect(probe.undoCount, 1);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_skill_history_section_undo_latest_change_property_undo_'
      'waits_then_comes_back', (WidgetTester tester) async {
    final Random random = seededRandom(1121308);

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
      final VoidCallback? whileUndoing = _readUndoAction(tester);
      held.complete();
      await tester.pump();

      expect(whileUndoing, isNull);
      expect(_readUndoAction(tester), isNotNull);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_skill_history_section_undo_latest_change_property_'
      'leaving_during_an_undo_is_safe', (WidgetTester tester) async {
    final Random random = seededRandom(1121309);

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
      held.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(probe.undoCount, 1);
    }
  });
}
