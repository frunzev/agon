import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:agent_orchestration/scanning/qr_scanner_page.dart';

import '../support/random_inputs.dart';
import 'support/scanner_page_scene.dart';

BarcodeCapture _captureOf(List<String?> rawValues) {
  return BarcodeCapture(
    barcodes: <Barcode>[
      for (final String? rawValue in rawValues) Barcode(rawValue: rawValue),
    ],
  );
}

List<String?> _randomRawValues(Random random) {
  final int count = random.nextInt(5);
  return <String?>[
    for (int i = 0; i < count; i += 1)
      pickOne<String?>(random, <String?>[null, '', ' ', randomText(random)]),
  ];
}

void main() {
  test('test_find_first_scanned_text_property_blank_codes_before_never_'
      'change_it', () {
    final Random random = seededRandom(96201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String?> rawValues = _randomRawValues(random);
      final List<String?> withBlanksFirst = <String?>[
        ...randomBlankValues(random),
        ...rawValues,
      ];

      expect(
        findFirstScannedText(_captureOf(withBlanksFirst)),
        findFirstScannedText(_captureOf(rawValues)),
      );
    }
  });

  test('test_find_first_scanned_text_property_later_codes_never_change_'
      'a_found_text', () {
    final Random random = seededRandom(96202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String?> rawValues = <String?>[
        ...randomBlankValues(random),
        randomScannedText(random),
      ];
      final String? found = findFirstScannedText(_captureOf(rawValues));
      final List<String?> withMoreAfter = <String?>[
        ...rawValues,
        ..._randomRawValues(random),
      ];

      expect(found, rawValues.last);
      expect(findFirstScannedText(_captureOf(withMoreAfter)), found);
    }
  });

  test('test_find_first_scanned_text_property_nothing_only_when_every_'
      'code_is_blank', () {
    final Random random = seededRandom(96203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String?> rawValues = _randomRawValues(random);
      final String? found = findFirstScannedText(_captureOf(rawValues));
      bool hasText = false;
      for (final String? rawValue in rawValues) {
        if (rawValue != null && rawValue.isNotEmpty) {
          hasText = true;
        }
      }

      expect(found != null, hasText);
      if (found != null) {
        expect(found, isNotEmpty);
        expect(rawValues, contains(found));
      }
    }
  });

  test('test_qr_scanner_page_new_property_keeps_the_key', () {
    final Random random = seededRandom(96204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomText(random));

      expect(QrScannerPage(key: key).key, key);
      expect(const QrScannerPage().key, isNull);
    }
  });

  test('test_qr_scanner_page_new_property_a_key_never_changes_the_page_'
      'kind', () {
    final Random random = seededRandom(96213);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(1 << 31));
      final Type keyedStateKind = QrScannerPage(key: key)
          .createState()
          .runtimeType;

      expect(keyedStateKind, const QrScannerPage().createState().runtimeType);
    }
  });

  test('test_qr_scanner_page_new_property_is_a_stateful_page', () {
    expect(const QrScannerPage(), isA<StatefulWidget>());
  });

  test('test_qr_scanner_page_create_state_property_every_call_is_fresh', () {
    const QrScannerPage page = QrScannerPage();
    final List<State<QrScannerPage>> states = <State<QrScannerPage>>[];

    for (int i = 0; i < propertyIterations; i += 1) {
      final State<QrScannerPage> state = page.createState();
      for (final State<QrScannerPage> earlier in states) {
        expect(identical(state, earlier), isFalse);
      }
      states.add(state);
    }
  });

  testWidgets('test_qr_scanner_page_create_state_property_shown_state_'
      'belongs_to_the_page', (WidgetTester tester) async {
    final Random random = seededRandom(96205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScannerCaller(
        tester,
        size: randomScannerWindowSize(random),
        place: pickOne(random, ScannerCallerPlace.values),
      );
      await openScannerPage(tester);

      final State<QrScannerPage> state = tester.state(
        find.byType(QrScannerPage),
      );
      expect(state.mounted, isTrue);
      expect(state.widget, isA<QrScannerPage>());
      await tester.tap(find.text(cancelLabel));
      await settleRoutes(tester);
    }
  });

  testWidgets('test_qr_scanner_page_create_state_property_each_scan_'
      'answers_again', (WidgetTester tester) async {
    final Random random = seededRandom(96206);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScanRecord record = await pumpScannerCaller(
        tester,
        size: randomScannerWindowSize(random),
        place: pickOne(random, ScannerCallerPlace.values),
      );
      final List<String> scannedTexts = <String>[];
      final int scanCount = 1 + random.nextInt(3);

      for (int scan = 0; scan < scanCount; scan += 1) {
        final String scannedText = randomScannedText(random);
        scannedTexts.add(scannedText);
        await openScannerPage(tester);
        detectBarcodes(tester, <String?>[scannedText]);
        await settleRoutes(tester);
      }

      expect(record.results, scannedTexts);
    }
  });

  testWidgets('test_qr_scanner_page_build_property_hint_and_cancel_fit_'
      'any_window', (WidgetTester tester) async {
    final Random random = seededRandom(96207);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = randomScannerWindowSize(random);
      await pumpScannerCaller(
        tester,
        size: size,
        place: ScannerCallerPlace.rootNavigator,
      );
      await openScannerPage(tester);

      expect(tester.takeException(), isNull, reason: 'size $size');
      for (final String text in <String>[cameraHint, cancelLabel]) {
        final Rect area = tester.getRect(find.text(text));
        expect(area.left, greaterThanOrEqualTo(0), reason: 'size $size');
        expect(area.right, lessThanOrEqualTo(size.width));
        expect(area.top, greaterThanOrEqualTo(0));
        expect(area.bottom, lessThanOrEqualTo(size.height));
      }
      await tester.tap(find.text(cancelLabel));
      await settleRoutes(tester);
    }
  });

  testWidgets('test_qr_scanner_page_build_property_hint_above_cancel', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(96208);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScannerCaller(
        tester,
        size: randomScannerWindowSize(random),
        place: pickOne(random, ScannerCallerPlace.values),
      );
      await openScannerPage(tester);

      final Rect hint = tester.getRect(find.text(cameraHint));
      final Rect cancel = tester.getRect(find.text(cancelLabel));
      expect(hint.bottom, lessThanOrEqualTo(cancel.top));
      await tester.tap(find.text(cancelLabel));
      await settleRoutes(tester);
    }
  });

  testWidgets('test_qr_scanner_page_build_property_camera_fills_the_'
      'window', (WidgetTester tester) async {
    final Random random = seededRandom(96209);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = randomScannerWindowSize(random);
      await pumpScannerCaller(
        tester,
        size: size,
        place: pickOne(random, ScannerCallerPlace.values),
      );
      await openScannerPage(tester);

      final Rect camera = tester.getRect(find.byType(MobileScanner));
      expect(camera, Offset.zero & size);
      await tester.tap(find.text(cancelLabel));
      await settleRoutes(tester);
    }
  });
}
