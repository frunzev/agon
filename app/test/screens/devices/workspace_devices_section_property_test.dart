import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/rules/device_runners.dart';
import 'package:agent_orchestration/screens/devices/workspace_devices_section.dart';

import '../../support/random_device_records.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_scopes.dart';
import 'support/random_devices_page.dart';

const String _removeLabel = 'Remove';
const String _addLabel = 'Add a device';

List<Device> _filterMembersByModel(List<Device> devices, WorkspaceId id) {
  final List<Device> members = <Device>[];
  for (final Device device in devices) {
    if (!device.revoked && device.workspaces.contains(id)) {
      members.add(device);
    }
  }
  return members;
}

List<Runner> _randomRunnersOn(Random random, List<DeviceId> deviceIds) {
  final List<Runner> runners = <Runner>[];
  final int count = random.nextInt(6);
  for (int i = 0; i < count; i += 1) {
    runners.add(randomRunnerOn(random, pickOne(random, deviceIds)));
  }
  return runners;
}

List<DeviceId> _randomDeviceIds(Random random) {
  return <DeviceId>[
    for (final Device device in randomPageDevices(random)) device.id,
  ];
}

void main() {
  test('test_list_workspace_members_property_matches_a_filter_model', () {
    final Random random = seededRandom(73101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Device> devices = randomDeviceRecords(random);
      final WorkspaceId workspaceId = pickOne(random, sampleWorkspaceIds);

      final List<Device> members = listWorkspaceMembers(
        devices: devices,
        workspaceId: workspaceId,
      );

      expect(members, _filterMembersByModel(devices, workspaceId));
    }
  });

  test('test_list_workspace_members_property_is_idempotent', () {
    final Random random = seededRandom(73102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceId workspaceId = pickOne(random, sampleWorkspaceIds);
      final List<Device> members = listWorkspaceMembers(
        devices: randomDeviceRecords(random),
        workspaceId: workspaceId,
      );

      final List<Device> membersAgain = listWorkspaceMembers(
        devices: members,
        workspaceId: workspaceId,
      );

      expect(membersAgain, members);
    }
  });

  test('test_list_workspace_members_property_splits_over_joined_lists', () {
    final Random random = seededRandom(73103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceId workspaceId = pickOne(random, sampleWorkspaceIds);
      final List<Device> first = randomDeviceRecords(random);
      final List<Device> second = randomDeviceRecords(random);

      final List<Device> joined = listWorkspaceMembers(
        devices: <Device>[...first, ...second],
        workspaceId: workspaceId,
      );

      expect(joined, <Device>[
        ...listWorkspaceMembers(devices: first, workspaceId: workspaceId),
        ...listWorkspaceMembers(devices: second, workspaceId: workspaceId),
      ]);
    }
  });

  test('test_find_device_runner_property_null_only_without_a_runner', () {
    final Random random = seededRandom(73104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<DeviceId> deviceIds = _randomDeviceIds(random);
      final List<Runner> runners = _randomRunnersOn(random, deviceIds);
      final DeviceId asked = pickOne(random, deviceIds);

      final Runner? found = findDeviceRunner(
        runners: runners,
        deviceId: asked,
      );

      final bool hasRunner = runners.any(
        (Runner runner) => runner.deviceId == asked,
      );
      expect(found != null, hasRunner);
    }
  });

  test('test_find_device_runner_property_gives_the_first_runner_there', () {
    final Random random = seededRandom(73105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<DeviceId> deviceIds = _randomDeviceIds(random);
      final List<Runner> runners = _randomRunnersOn(random, deviceIds);
      if (runners.isEmpty) {
        continue;
      }
      final DeviceId asked = pickOne(random, runners).deviceId;

      final Runner? found = findDeviceRunner(
        runners: runners,
        deviceId: asked,
      );

      final Runner firstThere = runners.firstWhere(
        (Runner runner) => runner.deviceId == asked,
      );
      expect(identical(found, firstThere), isTrue);
    }
  });

  test('test_find_device_runner_property_other_devices_change_nothing', () {
    final Random random = seededRandom(73106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<DeviceId> deviceIds = _randomDeviceIds(random);
      final List<Runner> runners = _randomRunnersOn(random, deviceIds);
      final DeviceId asked = pickOne(random, deviceIds);
      final List<Runner> others = <Runner>[
        for (final Runner runner in _randomRunnersOn(random, deviceIds))
          if (runner.deviceId != asked) runner,
      ];

      final Runner? alone = findDeviceRunner(
        runners: runners,
        deviceId: asked,
      );
      final Runner? amongOthers = findDeviceRunner(
        runners: <Runner>[...others, ...runners, ...others],
        deviceId: asked,
      );

      expect(identical(amongOthers, alone), isTrue);
    }
  });

  testWidgets('test_workspace_devices_section_build_property_member_rows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73107);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildRandomDevicesDependencies(
        random,
      );
      await pumpCompactDevicesPage(
        tester,
        random: random,
        dependencies: dependencies,
      );

      expect(tester.takeException(), isNull);
      final List<Device> members = listLiveMembers(dependencies);
      for (final Device device
          in dependencies.deviceRepository.listDevices()) {
        final Finder row = findSectionRow(workspaceSectionTitle, device.id);
        expect(row, members.contains(device) ? findsOneWidget : findsNothing);
      }
    }
  });

  testWidgets(
    'test_workspace_devices_section_build_property_remove_but_self',
    (WidgetTester tester) async {
      final Random random = seededRandom(73108);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final AppDependencies dependencies = buildRandomDevicesDependencies(
          random,
        );
        await pumpCompactDevicesPage(
          tester,
          random: random,
          dependencies: dependencies,
        );

        final DeviceId thisDeviceId = dependencies.deviceRepository
            .currentDevice()
            .id;
        for (final Device device in listLiveMembers(dependencies)) {
          final Finder row = findSectionRow(workspaceSectionTitle, device.id);
          final bool isThisDevice = device.id == thisDeviceId;
          expect(
            findTextInRow(row, _removeLabel),
            isThisDevice ? findsNothing : findsOneWidget,
          );
        }
      }
    },
  );

  testWidgets('test_workspace_devices_section_build_property_heading_shown', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73109);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildRandomDevicesDependencies(
        random,
      );
      await pumpDevicesPage(
        tester,
        random: random,
        dependencies: dependencies,
      );

      final Finder section = findDevicesSection(workspaceSectionTitle);
      expect(section, findsOneWidget);
      expect(findTextInRow(section, _addLabel), findsOneWidget);
    }
  });
}
