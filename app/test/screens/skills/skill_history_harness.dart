import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/screens/skills/skill_history_section.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

typedef ShownHistoryRow = ({String title, String subtitle});

const String undoLabel = 'Undo';
const String noChangesNote = 'No changes yet.';
const String momentSeparator = ' · ';

final class UndoProbe {
  int undoCount = 0;
  Completer<void>? heldUndo;

  Future<void> undo() async {
    undoCount += 1;
    final Completer<void>? held = heldUndo;
    if (held != null) {
      await held.future;
    }
  }
}

SkillHistorySection buildHistorySection({
  required List<SkillChange> history,
  required UndoProbe probe,
  DateTime? now,
}) {
  final AppDependencies dependencies = buildGalleryDependencies();
  return SkillHistorySection(
    history: history,
    taskRepository: dependencies.taskRepository,
    workflows: dependencies.workflowRepository.listWorkflows(),
    now: now ?? galleryNow,
    onUndo: probe.undo,
  );
}

Future<double> pumpHistorySection(
  WidgetTester tester,
  Random random,
  SkillHistorySection section,
) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(tester, width: width, child: section);
  return width;
}

List<ShownHistoryRow> readShownHistoryRows(WidgetTester tester) {
  return <ShownHistoryRow>[
    for (final ListRowMain row in tester.widgetList<ListRowMain>(
      find.byType(ListRowMain),
    ))
      (
        title: row.title,
        subtitle: <String>[
          for (final TextSegment segment in row.subtitle) segment.text,
        ].join(),
      ),
  ];
}

Future<void> tapUndo(WidgetTester tester) async {
  await tester.ensureVisible(find.text(undoLabel));
  await tester.tap(find.text(undoLabel));
  await tester.pump();
}
