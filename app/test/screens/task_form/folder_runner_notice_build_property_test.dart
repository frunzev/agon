import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/task_form/folder_runner_notice.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

import '../../presentation/support/plain_shown_text.dart';
import '../../support/random_inputs.dart';
import 'task_form_scene.dart';

const String _designPage = 'task-new-no-runner';
const MissingFolderRunner _designMissing = MissingFolderRunner(
  deviceName: 'air-laptop',
  folderName: 'billing-ui',
  projectName: 'billing',
);

MissingFolderRunner _randomMissing(Random random) {
  return MissingFolderRunner(
    deviceName: 'device-${randomText(random)}',
    folderName: 'folder-${randomText(random)}',
    projectName: 'project-${randomText(random)}',
  );
}

String _describeBody(MissingFolderRunner missing) {
  final String device = missing.deviceName;
  return '${missing.folderName} is a folder on $device, so only $device can '
      'work on ${missing.projectName}. The task waits until it runs tasks.';
}

void main() {
  testWidgets('test_folder_runner_notice_build_property_names_all_three', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1132301);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final MissingFolderRunner missing = _randomMissing(random);

      await pumpScrollingPage(
        tester,
        random: random,
        page: FolderRunnerNotice(missing: missing),
      );

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(find.text('${missing.deviceName} has no runner'), findsOneWidget);
      expect(find.text(_describeBody(missing)), findsOneWidget);
    }
  });

  testWidgets('test_folder_runner_notice_build_property_is_an_offline_alert', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1132302);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScrollingPage(
        tester,
        random: random,
        page: FolderRunnerNotice(missing: _randomMissing(random)),
      );

      final NoticeBanner banner = tester.widget(find.byType(NoticeBanner));
      expect(banner.tone, BannerTone.attention);
      expect(banner.icon, AppIconKind.offline);
      expect(banner.actions, isEmpty);
      expect(banner.body, hasLength(1));
    }
  });

  testWidgets('test_folder_runner_notice_build_property_matches_design', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1132303);
    final String designText = readDesignPageText(_designPage);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScrollingPage(
        tester,
        random: random,
        page: const FolderRunnerNotice(missing: _designMissing),
      );

      final NoticeBanner banner = tester.widget(find.byType(NoticeBanner));
      final Text body = tester.widget(
        find.descendant(
          of: find.byType(NoticeBanner),
          matching: find.text(_describeBody(_designMissing)),
        ),
      );
      expect(designText, contains(' ${banner.title} '));
      expect(designText, contains(' ${body.data} '));
    }
  });
}
