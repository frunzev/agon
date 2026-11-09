import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/presentation/audit_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../support/random_inputs.dart';
import '../support/audit_log_tab_harness.dart';

const String _emptyTitle = 'Nothing logged yet';
const String _emptyMessage =
    'Pairings, signed workflows and other changes show up here, each signed '
    'by the device that made it.';
const List<String> _columnLabels = <String>[
  'Event',
  'Device',
  'Entry',
  'Time',
];

final DeviceNames _deviceNames = DeviceNames(galleryDevices);

List<ListRowData> _readRows(WidgetTester tester) {
  return tester.widget<ResponsiveList>(find.byType(ResponsiveList)).rows;
}

String _readText(Widget widget) {
  final Text text = widget as Text;
  return text.data ?? text.textSpan!.toPlainText();
}

ScriptedAuditRepository _randomAudit(Random random) {
  return ScriptedAuditRepository(
    entries: randomAuditChain(random, length: random.nextInt(30)),
  );
}

void main() {
  testWidgets('test_audit_log_tab_build_property_any_log_fits_any_width', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);

      final double width = await pumpAuditLogTab(tester, random, audit);

      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('test_audit_log_tab_build_property_rows_follow_the_log', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109602);
    final ScriptedAuditRepository audit = _randomAudit(random);
    await pumpAuditLogTab(tester, random, audit);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      audit.replaceEntries(
        randomAuditChain(random, length: random.nextInt(9)),
      );
      await tester.pump();
      await tester.pump();

      final int entryCount = audit.listEntries().length;
      final Matcher shownRows = entryCount == 0
          ? findsNothing
          : findsOneWidget;
      expect(find.byType(ResponsiveList), shownRows);
      if (entryCount > 0) {
        expect(_readRows(tester), hasLength(entryCount));
      }
    }
  });

  testWidgets('test_audit_log_tab_build_property_empty_and_full_alternate', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109603);
    final ScriptedAuditRepository audit = ScriptedAuditRepository(
      entries: const <AuditEntry>[],
    );
    await pumpAuditLogTab(tester, random, audit);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool isEmpty = i.isEven;
      audit.replaceEntries(
        isEmpty ? const <AuditEntry>[] : randomNonEmptyAuditChain(random),
      );
      await tester.pump();

      expect(find.byType(EmptyState), isEmpty ? findsOne : findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_build_log_property_empty_state_uses_design_words', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      await pumpAuditLogTab(tester, random, audit);

      final bool isEmpty = audit.listEntries().isEmpty;
      expect(find.text(_emptyTitle), isEmpty ? findsOne : findsNothing);
      expect(find.text(_emptyMessage), isEmpty ? findsOne : findsNothing);
    }
  });

  testWidgets('test_build_log_property_rows_keep_log_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = ScriptedAuditRepository(
        entries: randomNonEmptyAuditChain(random),
      );
      await pumpAuditLogTab(tester, random, audit);

      final List<LocalKey?> keys = <LocalKey?>[
        for (final ListRowData row in _readRows(tester)) row.key,
      ];
      expect(keys, <LocalKey>[
        for (final AuditEntry entry in audit.listEntries())
          ValueKey<int>(entry.index),
      ]);
    }
  });

  testWidgets('test_build_log_property_columns_follow_the_design', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpAuditLogTab(
        tester,
        random,
        ScriptedAuditRepository(entries: randomNonEmptyAuditChain(random)),
      );

      final ResponsiveList list = tester.widget(find.byType(ResponsiveList));
      expect(<String>[
        for (final ListColumn column in list.columns) column.label,
      ], _columnLabels);
    }
  });

  testWidgets('test_build_row_property_title_and_detail_are_the_entry', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109607);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = ScriptedAuditRepository(
        entries: randomNonEmptyAuditChain(random),
      );
      await pumpAuditLogTab(tester, random, audit);

      final List<ListRowData> rows = _readRows(tester);
      for (int index = 0; index < rows.length; index += 1) {
        final AuditEntry entry = audit.listEntries()[index];
        final ListRowMain main = rows[index].main as ListRowMain;
        expect(main.title, entry.event);
        final List<String> subtitle = <String>[
          for (final TextSegment segment in main.subtitle) segment.text,
        ];
        expect(subtitle, <String>[entry.detail]);
      }
    }
  });

  testWidgets('test_build_row_property_device_and_hash_are_short', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109608);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = ScriptedAuditRepository(
        entries: randomNonEmptyAuditChain(random),
      );
      await pumpAuditLogTab(tester, random, audit);

      final List<ListRowData> rows = _readRows(tester);
      for (int index = 0; index < rows.length; index += 1) {
        final AuditEntry entry = audit.listEntries()[index];
        expect(
          <String>[
            for (final Widget meta in rows[index].meta) _readText(meta),
          ],
          <String>[
            _deviceNames.describeDevice(entry.deviceId),
            shortenIdentifier(entry.hash),
          ],
        );
      }
    }
  });

  testWidgets('test_build_row_property_time_is_relative_to_now', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109609);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = ScriptedAuditRepository(
        entries: randomNonEmptyAuditChain(random),
      );
      await pumpAuditLogTab(tester, random, audit);

      final List<ListRowData> rows = _readRows(tester);
      for (int index = 0; index < rows.length; index += 1) {
        final AuditEntry entry = audit.listEntries()[index];
        expect(
          _readText(rows[index].end!),
          describeAuditTime(entry.at, galleryNow),
        );
      }
    }
  });
}
