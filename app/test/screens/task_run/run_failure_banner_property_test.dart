import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/shared/agent_login_pointer.dart';
import 'package:agent_orchestration/screens/task_run/run_failure_banner.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/node_json_primitives.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';

const String _anyRunnerNote = 'A retry can run on any matching runner.';
final DeviceNames _deviceNames = DeviceNames(galleryDevices);

DeviceId? _randomRunner(Random random) {
  return pickOne<DeviceId?>(random, <DeviceId?>[
    null,
    DeviceId(randomUuidText(random)),
    pickOne(random, galleryDevices).id,
    pickOne(random, galleryDevices).id,
  ]);
}

RunFailure _randomFailure(Random random) {
  return RunFailure(
    stepName: pickOne(random, <String>[
      'build-ios',
      'claude-code',
      randomHostileText(random),
    ]),
    runner: _randomRunner(random),
    reason: pickOne(random, <String>[
      randomHostileText(random),
      'error: ${'No signing certificate found. ' * 40}',
    ]),
    retryRunsOnSameRunner: random.nextBool(),
  );
}

String _describeRunner(DeviceId runner) {
  return _deviceNames.findName(runner) ?? shortenIdentifier(runner.value);
}

Future<void> _pumpBanner(
  WidgetTester tester, {
  required Random random,
  required RunFailure failure,
  required AgentLoginPointer? loginPointer,
}) async {
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SingleChildScrollView(
      child: RunFailureBanner(
        failure: failure,
        deviceNames: _deviceNames,
        loginPointer: loginPointer,
      ),
    ),
  );
}

void main() {
  testWidgets('test_run_failure_banner_build_property_title_names_step_'
      'and_runner', (WidgetTester tester) async {
    final Random random = seededRandom(1141001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunFailure failure = _randomFailure(random);

      await _pumpBanner(
        tester,
        random: random,
        failure: failure,
        loginPointer: null,
      );

      expect(tester.takeException(), isNull);
      final DeviceId? runner = failure.runner;
      final String expectedTitle = runner == null
          ? '${failure.stepName} failed'
          : '${failure.stepName} failed on ${_describeRunner(runner)}';
      final NoticeBanner banner = tester.widget(find.byType(NoticeBanner));
      expect(banner.title, expectedTitle);
      expect(banner.tone, BannerTone.danger);
      expect(banner.icon, AppIconKind.alert);
    }
  });

  testWidgets('test_run_failure_banner_build_property_retry_note_tells_'
      'the_truth', (WidgetTester tester) async {
    final Random random = seededRandom(1141002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunFailure failure = _randomFailure(random);

      await _pumpBanner(
        tester,
        random: random,
        failure: failure,
        loginPointer: null,
      );

      final DeviceId? runner = failure.runner;
      final bool isPinned = failure.retryRunsOnSameRunner && runner != null;
      final String expectedNote = isPinned
          ? 'This step is pinned to ${_describeRunner(runner)}, so a retry '
                'runs there too.'
          : _anyRunnerNote;
      expect(find.text(expectedNote), findsOneWidget);
      expect(find.textContaining('pinned to ,'), findsNothing);
    }
  });

  testWidgets('test_run_failure_banner_build_property_reason_is_shown_'
      'verbatim', (WidgetTester tester) async {
    final Random random = seededRandom(1141003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunFailure failure = _randomFailure(random);

      await _pumpBanner(
        tester,
        random: random,
        failure: failure,
        loginPointer: null,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(failure.reason), findsWidgets);
      expect(find.byType(AppButton), findsNothing);
    }
  });

  testWidgets('test_run_failure_banner_build_property_login_pointer_'
      'offers_connecting', (WidgetTester tester) async {
    final Random random = seededRandom(1141004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TapCounter connects = TapCounter();
      final bool canConnect = random.nextBool();
      final AgentLoginPointer pointer = AgentLoginPointer(
        hint: randomHostileText(random),
        onConnect: canConnect ? connects.countTap : null,
      );

      await _pumpBanner(
        tester,
        random: random,
        failure: _randomFailure(random),
        loginPointer: pointer,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(pointer.hint), findsWidgets);
      final Finder connect = find.widgetWithText(
        AppButton,
        connectClaudeCodeLabel,
      );
      expect(connect, canConnect ? findsOneWidget : findsNothing);
      if (canConnect) {
        await tester.ensureVisible(connect);
        await tester.tap(connect);
        await tester.pump();
        expect(connects.count, 1);
      }
    }
  });
}
