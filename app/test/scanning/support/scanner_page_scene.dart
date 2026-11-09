import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:agent_orchestration/scanning/camera_qr_code_scanner.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const String scanButtonLabel = 'Scan';
const String cancelLabel = 'Cancel';
const String cameraHint =
    'Point the camera at the QR code on your other device.';
const Duration routeSettleTime = Duration(seconds: 1);
const double _lowestWindowHeight = 480;

enum ScannerCallerPlace { rootNavigator, nestedNavigator }

final class ScanRecord {
  final List<String?> results = <String?>[];

  Future<void> scan(BuildContext context) async {
    results.add(await const CameraQrCodeScanner().scanQrCode(context));
  }
}

Size randomScannerWindowSize(Random random) {
  return Size(
    randomWidth(random, least: narrowestWidth, most: widestWidth),
    randomWidth(random, least: _lowestWindowHeight, most: desktopHeight),
  );
}

Widget _buildScanButton(ScanRecord record) {
  return Builder(
    builder: (BuildContext context) => TextButton(
      onPressed: () => record.scan(context),
      child: const Text(scanButtonLabel),
    ),
  );
}

Widget _buildNestedNavigator(Widget child) {
  return Navigator(
    onGenerateRoute: (RouteSettings settings) =>
        MaterialPageRoute<void>(builder: (BuildContext context) => child),
  );
}

Future<ScanRecord> pumpScannerCaller(
  WidgetTester tester, {
  required Size size,
  required ScannerCallerPlace place,
}) async {
  final ScanRecord record = ScanRecord();
  final Widget button = _buildScanButton(record);
  final Widget body = switch (place) {
    ScannerCallerPlace.rootNavigator => button,
    ScannerCallerPlace.nestedNavigator => _buildNestedNavigator(button),
  };
  useViewSize(tester, size);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    wrapInApp(body, platform: platformMeantByWidth(size.width)),
  );
  return record;
}

Future<void> settleRoutes(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(routeSettleTime);
}

Future<void> openScannerPage(WidgetTester tester) async {
  await tester.tap(find.text(scanButtonLabel));
  await settleRoutes(tester);
}

void detectBarcodes(WidgetTester tester, List<String?> rawValues) {
  final MobileScanner scanner = tester.widget<MobileScanner>(
    find.byType(MobileScanner),
  );
  final BarcodeCapture capture = BarcodeCapture(
    barcodes: <Barcode>[
      for (final String? rawValue in rawValues) Barcode(rawValue: rawValue),
    ],
  );
  scanner.onDetect!(capture);
}

String randomScannedText(Random random) {
  return 'code ${randomText(random)}';
}

List<String?> randomBlankValues(Random random) {
  final int count = random.nextInt(4);
  return <String?>[
    for (int i = 0; i < count; i += 1)
      pickOne<String?>(random, <String?>[null, '']),
  ];
}
