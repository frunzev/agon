import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/qr_code_scanner.dart';
import 'package:agent_orchestration/scanning/camera_qr_code_scanner.dart';
import 'package:agent_orchestration/scanning/qr_scanner_page.dart';

import '../support/random_inputs.dart';
import 'support/scanner_page_scene.dart';

void main() {
  test('test_camera_qr_code_scanner_new_property_is_a_qr_code_scanner', () {
    const QrCodeScanner scanner = CameraQrCodeScanner();

    expect(scanner, isA<CameraQrCodeScanner>());
  });

  test('test_camera_qr_code_scanner_new_property_const_scanners_are_one_'
      'scanner', () {
    expect(
      identical(const CameraQrCodeScanner(), const CameraQrCodeScanner()),
      isTrue,
    );
  });

  testWidgets('test_camera_qr_code_scanner_new_property_fresh_scanners_'
      'scan_alike', (WidgetTester tester) async {
    final Random random = seededRandom(96301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScanRecord record = await pumpScannerCaller(
        tester,
        size: randomScannerWindowSize(random),
        place: pickOne(random, ScannerCallerPlace.values),
      );
      final String scannedText = randomScannedText(random);

      await openScannerPage(tester);
      detectBarcodes(tester, <String?>[scannedText]);
      await settleRoutes(tester);

      expect(record.results, <String?>[scannedText]);
    }
  });

  testWidgets('test_build_scanner_page_property_opens_on_the_root_'
      'navigator', (WidgetTester tester) async {
    final Random random = seededRandom(96302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScannerCaller(
        tester,
        size: randomScannerWindowSize(random),
        place: ScannerCallerPlace.nestedNavigator,
      );
      await openScannerPage(tester);

      final NavigatorState pageNavigator = Navigator.of(
        tester.element(find.byType(QrScannerPage)),
      );
      final NavigatorState callerNavigator = Navigator.of(
        tester.element(find.text(scanButtonLabel, skipOffstage: false)),
      );
      expect(identical(pageNavigator, callerNavigator), isFalse);
      expect(
        identical(
          pageNavigator,
          Navigator.of(callerNavigator.context, rootNavigator: true),
        ),
        isTrue,
      );
      await tester.tap(find.text(cancelLabel));
      await settleRoutes(tester);
    }
  });

  testWidgets('test_build_scanner_page_property_covers_the_caller_fully', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(96303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScannerCaller(
        tester,
        size: randomScannerWindowSize(random),
        place: pickOne(random, ScannerCallerPlace.values),
      );
      await openScannerPage(tester);

      final ModalRoute<Object?>? route = ModalRoute.of(
        tester.element(find.byType(QrScannerPage)),
      );
      expect(route, isA<PageRoute<String>>());
      expect(route!.opaque, isTrue);
      expect(find.text(scanButtonLabel), findsNothing);
      await tester.tap(find.text(cancelLabel));
      await settleRoutes(tester);
    }
  });

  testWidgets('test_build_scanner_page_property_shows_one_scanner_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(96304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScanRecord record = await pumpScannerCaller(
        tester,
        size: randomScannerWindowSize(random),
        place: pickOne(random, ScannerCallerPlace.values),
      );
      await openScannerPage(tester);

      expect(find.byType(QrScannerPage), findsOneWidget);
      expect(find.text(cameraHint), findsOneWidget);
      await tester.tap(find.text(cancelLabel));
      await settleRoutes(tester);
      expect(find.byType(QrScannerPage), findsNothing);
      expect(record.results, <String?>[null]);
    }
  });
}
