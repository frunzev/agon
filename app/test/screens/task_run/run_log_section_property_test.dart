import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/task_run/run_log_section.dart';
import 'package:agent_orchestration/widgets/log_block.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/route_line.dart';

import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'support/random_run_records.dart';

const String _nothingLogged = 'Nothing logged yet.';
final DeviceNames _deviceNames = DeviceNames(galleryDevices);

Future<void> _pumpLog(
  WidgetTester tester, {
  required Random random,
  required Run run,
  required Device thisDevice,
}) async {
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SingleChildScrollView(
      child: RunLogSection(
        run: run,
        deviceNames: _deviceNames,
        thisDevice: thisDevice,
      ),
    ),
  );
}

List<LogLine> _listCurrentStepLines(Run run) {
  final String currentName = findCurrentStep(run).name;
  return <LogLine>[
    for (final LogLine line in run.log)
      if (line.stepName == currentName) line,
  ];
}

void main() {
  testWidgets('test_run_log_section_build_property_shows_only_the_current_'
      'step_in_order', (WidgetTester tester) async {
    final Random random = seededRandom(1141101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Device thisDevice = pickOne(random, galleryDevices);
      final Run run = randomRunRecord(random, thisDevice: thisDevice);

      await _pumpLog(tester, random: random, run: run, thisDevice: thisDevice);

      expect(tester.takeException(), isNull);
      final PageSection section = tester.widget(find.byType(PageSection));
      expect(section.title, '${findCurrentStep(run).name} log');
      final List<LogLine> expected = _listCurrentStepLines(run);
      if (expected.isEmpty) {
        expect(find.byType(LogBlock), findsNothing);
        continue;
      }
      final LogBlock block = tester.widget(find.byType(LogBlock));
      expect(block.lines.length, expected.length);
      for (int index = 0; index < expected.length; index += 1) {
        final LogLine line = expected[index];
        expect(block.lines[index].text, line.text);
        expect(block.lines[index].time, formatLogTime(line.at));
        expect(
          block.lines[index].tone,
          line.isError ? LineTone.danger : LineTone.normal,
        );
      }
    }
  });

  testWidgets('test_run_log_section_build_property_empty_logs_say_so_and_'
      'cursor_follows_activity', (WidgetTester tester) async {
    final Random random = seededRandom(1141102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Device thisDevice = pickOne(random, galleryDevices);
      final Run run = randomRunRecord(random, thisDevice: thisDevice);

      await _pumpLog(tester, random: random, run: run, thisDevice: thisDevice);

      final bool isEmpty = _listCurrentStepLines(run).isEmpty;
      expect(
        find.text(_nothingLogged),
        isEmpty ? findsOneWidget : findsNothing,
      );
      if (!isEmpty) {
        final LogBlock block = tester.widget(find.byType(LogBlock));
        expect(
          block.cursor,
          isRunActive(run) ? CursorVisibility.shown : CursorVisibility.hidden,
        );
      }
    }
  });

  testWidgets('test_run_log_section_build_property_route_only_for_a_'
      'remote_active_runner', (WidgetTester tester) async {
    final Random random = seededRandom(1141103);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Device thisDevice = pickOne(random, galleryDevices);
      final Run run = randomRunRecord(random, thisDevice: thisDevice);

      await _pumpLog(tester, random: random, run: run, thisDevice: thisDevice);

      expect(tester.takeException(), isNull);
      final DeviceId? runner = findCurrentStep(run).runner;
      final bool showsRoute =
          isRunActive(run) && runner != null && runner != thisDevice.id;
      expect(
        find.byType(RouteLine),
        showsRoute ? findsOneWidget : findsNothing,
      );
      if (showsRoute) {
        final RouteLine route = tester.widget(find.byType(RouteLine));
        final String runnerName =
            _deviceNames.findName(runner) ?? shortenIdentifier(runner.value);
        expect(route.startName, runnerName);
        expect(route.endName, thisDevice.name);
      }
    }
  });
}
