import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_file_texts.dart';
import 'package:agent_orchestration/screens/files/file_frames.dart';
import 'package:agent_orchestration/screens/files/image_preview.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_property_inputs.dart';

const String _unreadableMessage = "Can't preview this image";
const int _largestGarbageLength = 64;
const int _shortestTruncation = 20;
const Duration _decodingTime = Duration(milliseconds: 200);

Uint8List _randomCorruptBytes(Random random) {
  final int length = random.nextInt(_largestGarbageLength);
  if (random.nextBool()) {
    final int kept = _shortestTruncation + length;
    return Uint8List.fromList(galleryIconBytes.sublist(0, kept));
  }
  return Uint8List.fromList(<int>[
    for (int index = 0; index < length; index += 1) random.nextInt(256),
  ]);
}

Future<double> _pumpPreview(
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
  return width;
}

void main() {
  testWidgets('test_build_unreadable_image_property_corrupt_bytes_say_so_'
      'in_words', (WidgetTester tester) async {
    final Random random = seededRandom(106001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpPreview(
        tester,
        random,
        ImagePreview(
          bytes: _randomCorruptBytes(random),
          name: randomHostileFileName(random),
        ),
      );

      expect(find.text(_unreadableMessage), findsOneWidget);
      expect(find.byType(RawImage), findsNothing);
    }
  });

  testWidgets('test_build_unreadable_image_property_readable_images_show_'
      'no_message', (WidgetTester tester) async {
    final Random random = seededRandom(106002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpPreview(
        tester,
        random,
        ImagePreview(
          bytes: galleryIconBytes,
          name: randomHostileFileName(random),
        ),
      );

      expect(find.text(_unreadableMessage), findsNothing);
      expect(find.byType(RawImage), findsOneWidget);
    }
  });

  testWidgets('test_build_unreadable_image_property_message_sits_inside_'
      'the_frame', (WidgetTester tester) async {
    final Random random = seededRandom(106003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = await _pumpPreview(
        tester,
        random,
        ImagePreview(
          bytes: _randomCorruptBytes(random),
          name: randomHostileFileName(random),
        ),
      );

      final Rect frame = tester.getRect(find.byType(ImageFrame));
      final Rect message = tester.getRect(find.text(_unreadableMessage));
      expect(frame.left, lessThanOrEqualTo(message.left));
      expect(frame.right, greaterThanOrEqualTo(message.right));
      expect(frame.top, lessThanOrEqualTo(message.top));
      expect(frame.bottom, greaterThanOrEqualTo(message.bottom));
      expect(frame.right, lessThanOrEqualTo(width));
    }
  });
}
