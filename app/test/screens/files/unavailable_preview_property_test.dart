import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/file_text.dart';
import 'package:agent_orchestration/screens/files/unavailable_preview.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_property_inputs.dart';

const String _designTitle = "Can't preview this file";

UnavailablePreview _randomPreview(Random random) {
  return UnavailablePreview(
    fileName: randomHostileFileName(random),
    reason: pickOne(random, PreviewUnavailableReason.values),
    repositoryPath: randomHostileText(random),
  );
}

Future<void> _pumpPreview(
  WidgetTester tester,
  Random random,
  UnavailablePreview preview,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: preview,
  );
}

void main() {
  test('test_unavailable_preview_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(1020301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String fileName = randomHostileFileName(random);
      final PreviewUnavailableReason reason = pickOne(
        random,
        PreviewUnavailableReason.values,
      );
      final String repositoryPath = randomHostileText(random);

      final UnavailablePreview preview = UnavailablePreview(
        fileName: fileName,
        reason: reason,
        repositoryPath: repositoryPath,
      );

      expect(preview.fileName, fileName);
      expect(preview.reason, reason);
      expect(preview.repositoryPath, repositoryPath);
    }
  });

  test('test_unavailable_preview_constructor_property_no_key_unless_'
      'given', () {
    final Random random = seededRandom(1020302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(i);
      final UnavailablePreview keyless = _randomPreview(random);
      final UnavailablePreview keyed = UnavailablePreview(
        fileName: keyless.fileName,
        reason: keyless.reason,
        repositoryPath: keyless.repositoryPath,
        key: key,
      );

      expect(keyless.key, isNull);
      expect(keyed.key, key);
    }
  });

  test('test_unavailable_preview_constructor_property_title_matches_'
      'design', () {
    expect(unavailablePreviewTitle, _designTitle);
    expect(unavailablePreviewTitle.trim(), unavailablePreviewTitle);
  });

  testWidgets('test_unavailable_preview_build_property_shows_title_reason_'
      'and_hint', (WidgetTester tester) async {
    final Random random = seededRandom(1020303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final UnavailablePreview preview = _randomPreview(random);

      await _pumpPreview(tester, random, preview);

      expect(tester.takeException(), isNull);
      expect(find.text(unavailablePreviewTitle), findsOneWidget);
      expect(
        find.text(
          describeUnavailablePreview(
            fileName: preview.fileName,
            reason: preview.reason,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(describeOwnCloneHint(preview.repositoryPath)),
        findsOneWidget,
      );
    }
  });

  testWidgets('test_unavailable_preview_build_property_title_comes_first_'
      'and_is_a_header', (WidgetTester tester) async {
    final Random random = seededRandom(1020304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final UnavailablePreview preview = _randomPreview(random);

      await _pumpPreview(tester, random, preview);

      final double titleTop = tester
          .getTopLeft(find.text(unavailablePreviewTitle))
          .dy;
      final double hintTop = tester
          .getTopLeft(find.text(describeOwnCloneHint(preview.repositoryPath)))
          .dy;
      expect(titleTop, lessThan(hintTop));
      expect(
        tester.getSemantics(find.text(unavailablePreviewTitle)),
        isSemantics(label: unavailablePreviewTitle, isHeader: true),
      );
    }
  });

  testWidgets('test_unavailable_preview_build_property_stays_inside_the_'
      'window', (WidgetTester tester) async {
    final Random random = seededRandom(1020305);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final UnavailablePreview preview = UnavailablePreview(
        fileName: '${'long-name' * random.nextInt(40)}.mp4',
        reason: pickOne(random, PreviewUnavailableReason.values),
        repositoryPath: 'github.com/acme/${'deep' * random.nextInt(60)}',
      );

      await _pumpPreview(tester, random, preview);

      expect(tester.takeException(), isNull);
      final Rect frame = tester.getRect(find.byType(UnavailablePreview));
      final double windowWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(frame.left, greaterThanOrEqualTo(0));
      expect(frame.right, lessThanOrEqualTo(windowWidth));
    }
  });
}
