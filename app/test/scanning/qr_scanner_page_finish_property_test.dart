import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/scanning/qr_scanner_page.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../support/random_inputs.dart';
import 'support/scanner_page_scene.dart';

const int _largestDetectionCount = 5;
const int _largestCancelCount = 4;

void _pressCancelAtOnce(WidgetTester tester) {
  final AppButton cancel = tester.widget<AppButton>(
    find.widgetWithText(AppButton, cancelLabel),
  );
  cancel.onPressed!();
}

void main() {
  testWidgets('test_finish_with_capture_property_a_found_code_answers_the_'
      'caller', (WidgetTester tester) async {
    final Random random = seededRandom(96210);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScanRecord record = await pumpScannerCaller(
        tester,
        size: randomScannerWindowSize(random),
        place: pickOne(random, ScannerCallerPlace.values),
      );
      await openScannerPage(tester);
      final String scannedText = randomScannedText(random);

      detectBarcodes(tester, <String?>[
        ...randomBlankValues(random),
        scannedText,
        randomScannedText(random),
      ]);
      await settleRoutes(tester);

      expect(record.results, <String?>[scannedText]);
      expect(find.byType(QrScannerPage), findsNothing);
      expect(find.text(scanButtonLabel), findsOneWidget);
    }
  });

  testWidgets('test_finish_with_capture_property_blank_codes_keep_'
      'scanning', (WidgetTester tester) async {
    final Random random = seededRandom(96211);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScanRecord record = await pumpScannerCaller(
        tester,
        size: randomScannerWindowSize(random),
        place: pickOne(random, ScannerCallerPlace.values),
      );
      await openScannerPage(tester);

      detectBarcodes(tester, randomBlankValues(random));
      await settleRoutes(tester);

      expect(record.results, isEmpty);
      expect(find.byType(QrScannerPage), findsOneWidget);
      await tester.tap(find.text(cancelLabel));
      await settleRoutes(tester);
      expect(record.results, <String?>[null]);
    }
  });

  testWidgets('test_finish_with_capture_property_many_detections_answer_'
      'once', (WidgetTester tester) async {
    final Random random = seededRandom(96212);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScanRecord record = await pumpScannerCaller(
        tester,
        size: randomScannerWindowSize(random),
        place: pickOne(random, ScannerCallerPlace.values),
      );
      await openScannerPage(tester);
      final String firstText = randomScannedText(random);
      final int detectionCount = 1 + random.nextInt(_largestDetectionCount);

      detectBarcodes(tester, <String?>[firstText]);
      for (int detection = 1; detection < detectionCount; detection += 1) {
        detectBarcodes(tester, <String?>[randomScannedText(random)]);
      }
      await settleRoutes(tester);

      expect(record.results, <String?>[firstText]);
      expect(find.text(scanButtonLabel), findsOneWidget);
    }
  });

  testWidgets('test_finish_property_a_late_code_after_cancel_is_ignored', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(96214);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScanRecord record = await pumpScannerCaller(
        tester,
        size: randomScannerWindowSize(random),
        place: pickOne(random, ScannerCallerPlace.values),
      );
      await openScannerPage(tester);

      _pressCancelAtOnce(tester);
      detectBarcodes(tester, <String?>[randomScannedText(random)]);
      await settleRoutes(tester);

      expect(tester.takeException(), isNull);
      expect(record.results, <String?>[null]);
      expect(find.text(scanButtonLabel), findsOneWidget);
    }
  });

  testWidgets('test_finish_property_cancel_after_a_code_is_ignored', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(96215);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScanRecord record = await pumpScannerCaller(
        tester,
        size: randomScannerWindowSize(random),
        place: pickOne(random, ScannerCallerPlace.values),
      );
      await openScannerPage(tester);
      final String scannedText = randomScannedText(random);

      detectBarcodes(tester, <String?>[scannedText]);
      _pressCancelAtOnce(tester);
      await settleRoutes(tester);

      expect(tester.takeException(), isNull);
      expect(record.results, <String?>[scannedText]);
      expect(find.text(scanButtonLabel), findsOneWidget);
    }
  });

  testWidgets('test_finish_property_repeated_cancel_leaves_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(96216);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScanRecord record = await pumpScannerCaller(
        tester,
        size: randomScannerWindowSize(random),
        place: pickOne(random, ScannerCallerPlace.values),
      );
      await openScannerPage(tester);
      final int cancelCount = 1 + random.nextInt(_largestCancelCount);

      for (int cancel = 0; cancel < cancelCount; cancel += 1) {
        _pressCancelAtOnce(tester);
      }
      await settleRoutes(tester);

      expect(tester.takeException(), isNull);
      expect(record.results, <String?>[null]);
      expect(find.byType(QrScannerPage), findsNothing);
      expect(find.text(scanButtonLabel), findsOneWidget);
    }
  });
}
