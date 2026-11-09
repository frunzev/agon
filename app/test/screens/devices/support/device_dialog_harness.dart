import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/random_inputs.dart';
import '../../../support/widget_harness.dart';

const Key _launchSurfaceKey = ValueKey<String>('device-dialog-launch-surface');

typedef OpenDeviceDialog<Choice> = Future<Choice?> Function(
  BuildContext context,
);

final class OpenedDeviceDialog<Choice> {
  Choice? chosen;
  bool hasClosed = false;

  void close(Choice? choice) {
    chosen = choice;
    hasClosed = true;
  }
}

Future<OpenedDeviceDialog<Choice>> openDeviceDialog<Choice>(
  WidgetTester tester, {
  required Random random,
  required OpenDeviceDialog<Choice> open,
}) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  useViewSize(tester, Size(width, desktopHeight));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    wrapInApp(
      const SizedBox.expand(key: _launchSurfaceKey),
      platform: platformMeantByWidth(width),
    ),
  );

  final BuildContext context = tester.element(find.byKey(_launchSurfaceKey));
  final OpenedDeviceDialog<Choice> opened = OpenedDeviceDialog<Choice>();
  unawaited(open(context).then(opened.close));
  await pumpFrames(tester);
  return opened;
}
