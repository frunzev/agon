import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/screens/devices/add_workspace_device_dialog.dart';
import 'package:agent_orchestration/screens/devices/devices_screen.dart';
import 'package:agent_orchestration/screens/devices/revoke_device_dialog.dart';
import 'package:agent_orchestration/screens/devices/runner_notices.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_device_records.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/random_devices_page.dart';

RunnerNotices _buildNotices(AppDependencies dependencies) {
  return RunnerNotices(
    runnerRepository: dependencies.runnerRepository,
    deviceRepository: dependencies.deviceRepository,
    workspaceRepository: dependencies.workspaceRepository,
  );
}

List<Type> _listNoticeTypes(List<Widget> notices) {
  return <Type>[for (final Widget notice in notices) notice.runtimeType];
}

List<Object?> _describeRunnerState(AppDependencies dependencies) {
  final AppServerStatus status = dependencies.workspaceRepository
      .findAppServerStatus();
  return <Object?>[
    for (final Runner runner in dependencies.runnerRepository.listRunners())
      runner.deviceId,
    dependencies.runnerRepository.findThisRunnerProblem(),
    dependencies.runnerRepository.findThisDeviceOffers()?.length,
    status.state,
    status.lastConnectedAt,
  ];
}

Widget _randomAddDialog(Random random) {
  return AddWorkspaceDeviceDialog(
    workspaceName: randomHostileText(random),
    candidates: randomDeviceRecords(random),
  );
}

Widget _randomRevokeDialog(Random random) {
  return RevokeDeviceDialog(
    device: randomDeviceRecord(random, approvedBy: null),
    workspaceNames: randomHostileText(random),
    lastSeen: randomHostileText(random),
    pairing: randomHostileText(random),
  );
}

void main() {
  test('test_runner_notices_new_property_keeps_every_repository', () {
    final Random random = seededRandom(74101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildRandomDevicesDependencies(
        random,
      );

      final RunnerNotices notices = _buildNotices(dependencies);

      expect(
        identical(notices.runnerRepository, dependencies.runnerRepository),
        isTrue,
      );
      expect(
        identical(notices.deviceRepository, dependencies.deviceRepository),
        isTrue,
      );
      expect(
        identical(
          notices.workspaceRepository,
          dependencies.workspaceRepository,
        ),
        isTrue,
      );
    }
  });

  testWidgets('test_runner_notices_new_property_twins_build_alike', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(74102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildRandomDevicesDependencies(
        random,
      );
      await pumpDevicesPage(
        tester,
        random: random,
        dependencies: dependencies,
      );
      final BuildContext context = tester.element(find.byType(DevicesScreen));

      final List<Widget> first = _buildNotices(dependencies)
          .buildNotices(context);
      final List<Widget> second = _buildNotices(dependencies)
          .buildNotices(context);

      expect(_listNoticeTypes(second), _listNoticeTypes(first));
    }
  });

  testWidgets('test_runner_notices_new_property_building_changes_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(74103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildRandomDevicesDependencies(
        random,
      );
      await pumpDevicesPage(
        tester,
        random: random,
        dependencies: dependencies,
      );
      final BuildContext context = tester.element(find.byType(DevicesScreen));
      final List<Object?> before = _describeRunnerState(dependencies);

      _buildNotices(dependencies).buildNotices(context);

      expect(_describeRunnerState(dependencies), before);
    }
  });

  test(
    'test_add_workspace_device_dialog_new_property_no_key_unless_given',
    () {
      final Random random = seededRandom(74104);

      expect(_randomAddDialog(random).key, isNull);
    },
  );

  testWidgets('test_add_workspace_device_dialog_new_property_renders_alone', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 74105,
      buildChild: _randomAddDialog,
    );
  });

  test('test_revoke_device_dialog_new_property_no_key_unless_given', () {
    final Random random = seededRandom(74106);

    expect(_randomRevokeDialog(random).key, isNull);
  });

  testWidgets('test_revoke_device_dialog_new_property_renders_alone', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 74107,
      buildChild: _randomRevokeDialog,
    );
  });
}
