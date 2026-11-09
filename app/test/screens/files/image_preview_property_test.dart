import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_file_texts.dart';
import 'package:agent_orchestration/screens/files/file_frames.dart';
import 'package:agent_orchestration/screens/files/image_preview.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_property_inputs.dart';

const double _largestPreviewWidth = 256;
const int _largestSide = 3000;
const int _smallestSide = 1;
const int _thinSide = 12;
const int _largestGarbageLength = 64;
const Duration _decodingTime = Duration(milliseconds: 200);
const List<int> _pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

typedef _ImageSides = ({int width, int height});

_ImageSides _randomSides(Random random) {
  final int longSide = _smallestSide + random.nextInt(_largestSide);
  final int shortSide = _smallestSide + random.nextInt(_thinSide);
  return switch (random.nextInt(3)) {
    0 => (width: longSide, height: shortSide),
    1 => (width: shortSide, height: longSide ~/ 4 + 1),
    _ => (width: shortSide * 20, height: shortSide * 20),
  };
}

Future<Uint8List> _encodePng(_ImageSides sides) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Rect area = Rect.fromLTWH(
    0,
    0,
    sides.width.toDouble(),
    sides.height.toDouble(),
  );
  canvas.drawRect(area, Paint()..color = const Color(0xFF14B8A6));
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(sides.width, sides.height);
  final ByteData? encoded = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  image.dispose();
  picture.dispose();
  return encoded!.buffer.asUint8List();
}

Uint8List _randomUnreadableBytes(Random random) {
  final int length = random.nextInt(_largestGarbageLength);
  final List<int> garbage = <int>[
    for (int index = 0; index < length; index += 1) random.nextInt(256),
  ];
  return switch (random.nextInt(4)) {
    0 => Uint8List(0),
    1 => Uint8List.fromList(<int>[..._pngSignature, ...garbage]),
    2 => Uint8List.fromList(galleryIconBytes.sublist(0, 20 + length)),
    _ => Uint8List.fromList(garbage),
  };
}

Future<void> _pumpAndDecode(
  WidgetTester tester,
  Random random,
  ImagePreview preview,
) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(tester, width: width, child: preview);
  await tester.runAsync(() => Future<void>.delayed(_decodingTime));
  await tester.pump();
  expect(tester.takeException(), isNull, reason: 'width $width');
}

void main() {
  testWidgets('test_image_preview_build_property_keeps_the_shape_within_'
      'the_largest_width', (WidgetTester tester) async {
    final Random random = seededRandom(100501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ImageSides sides = _randomSides(random);
      final Uint8List bytes = (await tester.runAsync(
        () => _encodePng(sides),
      ))!;

      await _pumpAndDecode(
        tester,
        random,
        ImagePreview(bytes: bytes, name: randomHostileFileName(random)),
      );

      final Size shown = tester.getSize(find.byType(RawImage));
      final double windowWidth = tester.view.physicalSize.width;
      expect(shown.width, lessThanOrEqualTo(_largestPreviewWidth));
      expect(shown.width, lessThanOrEqualTo(windowWidth));
      final double shownShape = shown.height / shown.width;
      final double imageShape = sides.height / sides.width;
      expect(shownShape, closeTo(imageShape, imageShape * 0.05 + 0.01));
    }
  });

  testWidgets('test_image_preview_build_property_names_the_file_for_screen_'
      'readers', (WidgetTester tester) async {
    final Random random = seededRandom(100502);
    final SemanticsHandle semantics = tester.ensureSemantics();

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String name = 'image ${randomHostileFileName(random)}';

      await _pumpAndDecode(
        tester,
        random,
        ImagePreview(bytes: galleryIconBytes, name: name),
      );

      final Image image = tester.widget(find.byType(Image));
      expect(image.semanticLabel, name);
      expect(find.bySemanticsLabel(name), findsOneWidget);
    }
    semantics.dispose();
  });

  testWidgets('test_image_preview_build_property_sits_inside_its_frame', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpAndDecode(
        tester,
        random,
        ImagePreview(bytes: galleryIconBytes, name: 'icon.png'),
      );

      final Rect frame = tester.getRect(find.byType(ImageFrame));
      final Rect image = tester.getRect(find.byType(RawImage));
      expect(frame.left, lessThanOrEqualTo(image.left));
      expect(frame.right, greaterThanOrEqualTo(image.right));
      expect(frame.top, lessThanOrEqualTo(image.top));
      expect(frame.bottom, greaterThanOrEqualTo(image.bottom));
    }
  });

  testWidgets('test_build_unreadable_image_property_corrupt_bytes_raise_'
      'nothing', (WidgetTester tester) async {
    final Random random = seededRandom(100504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpAndDecode(
        tester,
        random,
        ImagePreview(
          bytes: _randomUnreadableBytes(random),
          name: randomHostileFileName(random),
        ),
      );

      expect(find.byType(ImageFrame), findsOneWidget);
    }
  });

  testWidgets('test_build_unreadable_image_property_shows_no_broken_'
      'picture', (WidgetTester tester) async {
    final Random random = seededRandom(100505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpAndDecode(
        tester,
        random,
        ImagePreview(
          bytes: _randomUnreadableBytes(random),
          name: randomHostileFileName(random),
        ),
      );

      expect(find.byType(RawImage), findsNothing);
    }
  });

  testWidgets('test_build_unreadable_image_property_frame_stays_inside_the_'
      'window', (WidgetTester tester) async {
    final Random random = seededRandom(100506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpAndDecode(
        tester,
        random,
        ImagePreview(
          bytes: _randomUnreadableBytes(random),
          name: randomHostileFileName(random),
        ),
      );

      final Rect frame = tester.getRect(find.byType(ImageFrame));
      expect(frame.left, greaterThanOrEqualTo(0));
      expect(frame.right, lessThanOrEqualTo(tester.view.physicalSize.width));
      expect(frame.height, greaterThan(0));
    }
  });
}
