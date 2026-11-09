import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/chat/chat_composer.dart';
import 'package:agent_orchestration/screens/chat/chat_page_layout.dart';
import 'package:agent_orchestration/screens/chat/chat_run_context.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../../support/random_inputs.dart';
import '../../../support/sample_runners.dart';
import '../../../support/widget_harness.dart';
import 'random_chat_conversations.dart';
import 'random_chat_run_contexts.dart';

const List<String> _sampleHosts = <String>[
  'github.com',
  'api.anthropic.com',
  'pypi.org',
];

Future<ActionOutcome> acceptEveryMessage(String text) async {
  return ActionOutcome.done;
}

void ignoreGoingBack() {}

String joinTextSegments(List<TextSegment> segments) {
  final StringBuffer joined = StringBuffer();
  for (final TextSegment segment in segments) {
    joined.write(segment.text);
  }
  return joined.toString();
}

Size randomLargeWindowSize(Random random) {
  final double width = randomWidth(
    random,
    least: LayoutSize.largeMinimumWidth,
    most: widestWidth,
  );
  return Size(width, desktopHeight);
}

Runner? randomRunnerFor(Random random, ChatRunContext context) {
  final DeviceId? runnerId = context.runnerId;
  if (runnerId == null || random.nextInt(4) == 0) {
    return null;
  }

  final Runner base = buildOnlineRunnerOn(runnerId);
  return Runner(
    deviceId: base.deviceId,
    labels: base.labels,
    slotsTotal: base.slotsTotal,
    slotsBusy: base.slotsBusy,
    link: pickOne(random, RunnerLink.values),
    online: random.nextBool(),
    acceptingNewRuns: base.acceptingNewRuns,
    offers: base.offers,
    allowedHosts: <String>[
      for (final String host in _sampleHosts)
        if (random.nextBool()) host,
    ],
  );
}

Device findGalleryDevice(DeviceId deviceId) {
  return galleryDevices.firstWhere((Device device) => device.id == deviceId);
}

Device randomThisDevice(Random random, ChatRunContext context) {
  final DeviceId? runnerId = context.runnerId;
  if (runnerId != null && random.nextInt(4) == 0) {
    return findGalleryDevice(runnerId);
  }
  return pickOne(random, galleryDevices);
}

ChatPageLayout buildRandomChatPageLayout(
  Random random, {
  required VoidCallback onBack,
  required MessageSending onSend,
}) {
  final ChatRunContext context = randomChatRunContext(random);
  return ChatPageLayout(
    runContext: context,
    conversation: randomChatConversation(random),
    runner: randomRunnerFor(random, context),
    thisDevice: randomThisDevice(random, context),
    onBack: onBack,
    onSend: onSend,
  );
}
