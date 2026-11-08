import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/qr_code_scanner.dart';
import 'package:agent_orchestration/scanning/camera_qr_code_scanner.dart';

import '../support/fixed_qr_code_scanner.dart';
import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const String _scanButtonLabel = 'Scan';
const String _cancelLabel = 'Cancel';
const String _cameraHint =
    'Point the camera at the QR code on your other device.';
const int _largestScanCount = 5;

final class _ScanRecord {
  final List<String?> results = <String?>[];
}

Widget _buildScanButton(QrCodeScanner scanner, _ScanRecord record) {
  return Builder(
    builder: (BuildContext context) => TextButton(
      onPressed: () async {
        record.results.add(await scanner.scanQrCode(context));
      },
      child: const Text(_scanButtonLabel),
    ),
  );
}

Future<void> _pumpScanner(
  WidgetTester tester,
  QrCodeScanner scanner,
  _ScanRecord record, {
  required bool isNested,
}) async {
  useViewSize(tester, const Size(phoneWidth, phoneHeight));
  await tester.pumpWidget(const SizedBox());
  final Widget button = _buildScanButton(scanner, record);
  final Widget body = isNested
      ? Navigator(
          onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
            builder: (BuildContext context) => button,
          ),
        )
      : button;
  await tester.pumpWidget(wrapInApp(body, platform: phonePlatform));
}

String? _randomScannedText(Random random) {
  if (random.nextInt(4) == 0) {
    return null;
  }
  return randomText(random);
}

void main() {
  testWidgets('test_fixed_qr_code_scanner_scan_qr_code_property_returns_the_'
      'fixed_text', (WidgetTester tester) async {
    final Random random = seededRandom(85501);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String? scanned = _randomScannedText(random);
      final _ScanRecord record = _ScanRecord();
      await _pumpScanner(
        tester,
        FixedQrCodeScanner(scanned),
        record,
        isNested: random.nextBool(),
      );

      await tester.tap(find.text(_scanButtonLabel));
      await tester.pump();

      expect(record.results, <String?>[scanned]);
    }
  });

  testWidgets('test_fixed_qr_code_scanner_scan_qr_code_property_counts_every_'
      'scan_and_answers_alike', (WidgetTester tester) async {
    final Random random = seededRandom(85502);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String? scanned = _randomScannedText(random);
      final FixedQrCodeScanner scanner = FixedQrCodeScanner(scanned);
      final _ScanRecord record = _ScanRecord();
      await _pumpScanner(tester, scanner, record, isNested: false);
      final int scanCount = 1 + random.nextInt(_largestScanCount);

      for (int scan = 0; scan < scanCount; scan += 1) {
        await tester.tap(find.text(_scanButtonLabel));
        await tester.pump();
      }

      expect(scanner.scanCount, scanCount);
      expect(record.results, List<String?>.filled(scanCount, scanned));
    }
  });

  testWidgets('test_fixed_qr_code_scanner_scan_qr_code_property_opens_no_'
      'page', (WidgetTester tester) async {
    final Random random = seededRandom(85503);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ScanRecord record = _ScanRecord();
      await _pumpScanner(
        tester,
        FixedQrCodeScanner(_randomScannedText(random)),
        record,
        isNested: random.nextBool(),
      );

      await tester.tap(find.text(_scanButtonLabel));
      await tester.pump();

      expect(find.text(_cameraHint), findsNothing);
      expect(find.text(_scanButtonLabel), findsOneWidget);
    }
  });

  testWidgets(
    'test_camera_qr_code_scanner_scan_qr_code_property_cancel_answers_'
    'nothing',
    (WidgetTester tester) async {
      final Random random = seededRandom(85504);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _ScanRecord record = _ScanRecord();
        await _pumpScanner(
          tester,
          const CameraQrCodeScanner(),
          record,
          isNested: random.nextBool(),
        );

        await tester.tap(find.text(_scanButtonLabel));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text(_cancelLabel));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(record.results, <String?>[null]);
      }
    },
  );

  testWidgets('test_camera_qr_code_scanner_scan_qr_code_property_covers_the_'
      'whole_app_while_scanning', (WidgetTester tester) async {
    final Random random = seededRandom(85505);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ScanRecord record = _ScanRecord();
      await _pumpScanner(
        tester,
        const CameraQrCodeScanner(),
        record,
        isNested: random.nextBool(),
      );

      await tester.tap(find.text(_scanButtonLabel));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(_cameraHint), findsOneWidget);
      expect(find.text(_scanButtonLabel), findsNothing);
      final Rect hint = tester.getRect(find.text(_cameraHint));
      expect(hint.left, greaterThanOrEqualTo(0));
      expect(hint.right, lessThanOrEqualTo(phoneWidth));
      await tester.tap(find.text(_cancelLabel));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('test_camera_qr_code_scanner_scan_qr_code_property_cancelling_'
      'returns_to_the_caller', (WidgetTester tester) async {
    final Random random = seededRandom(85506);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ScanRecord record = _ScanRecord();
      await _pumpScanner(
        tester,
        const CameraQrCodeScanner(),
        record,
        isNested: random.nextBool(),
      );
      final int scanCount = 1 + random.nextInt(3);

      for (int scan = 0; scan < scanCount; scan += 1) {
        await tester.tap(find.text(_scanButtonLabel));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text(_cancelLabel));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.text(_cameraHint), findsNothing);
      expect(find.text(_scanButtonLabel), findsOneWidget);
      expect(record.results, List<String?>.filled(scanCount, null));
    }
  });
}
