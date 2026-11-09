import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/files/file_source_status.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

Future<void> _pumpStatus(
  WidgetTester tester,
  Random random,
  String runnerName,
) async {
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: FileSourceStatus(runnerName: runnerName),
  );
}

void main() {
  test('test_file_source_status_new_property_keeps_the_runner_name', () {
    final Random random = seededRandom(100501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String runnerName = randomHostileText(random);

      expect(FileSourceStatus(runnerName: runnerName).runnerName, runnerName);
    }
  });

  test('test_file_source_status_new_property_keeps_the_key', () {
    final Random random = seededRandom(100502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(1 << 20));

      expect(FileSourceStatus(key: key, runnerName: 'runner').key, key);
    }
  });

  test('test_file_source_status_new_property_huge_names_kept_whole', () {
    final Random random = seededRandom(100503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String runnerName = randomHostileText(random) * 100;

      expect(
        FileSourceStatus(runnerName: runnerName).runnerName,
        same(runnerName),
      );
    }
  });

  testWidgets('test_file_source_status_build_property_reads_like_the_design', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String runnerName = randomHostileText(random);
      await _pumpStatus(tester, random, runnerName);
      final MixedText text = tester.widget<MixedText>(find.byType(MixedText));
      final List<String> faces = <String>[
        for (final TextSegment segment in text.segments)
          '${segment.face.name}:${segment.text}',
      ];

      expect(faces, <String>[
        'body:From ',
        'monospace:$runnerName',
        'body: · encrypted',
      ]);
    }
  });

  testWidgets('test_file_source_status_build_property_lock_comes_first', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpStatus(tester, random, randomHostileText(random));
      final AppIcon icon = tester.widget<AppIcon>(find.byType(AppIcon));

      expect(icon.kind, AppIconKind.lock);
      expect(
        tester.getRect(find.byType(AppIcon)).right,
        lessThanOrEqualTo(tester.getRect(find.byType(MixedText)).left),
      );
    }
  });

  testWidgets('test_file_source_status_build_property_long_names_wrap', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: FileSourceStatus(runnerName: randomHostileText(random) * 40),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(MixedText)).right,
        lessThanOrEqualTo(width + 0.01),
      );
    }
  });
}
