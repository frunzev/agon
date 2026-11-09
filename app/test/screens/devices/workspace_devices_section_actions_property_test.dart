import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/screens/devices/add_workspace_device_dialog.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'support/random_devices_page.dart';

const String _addDeviceLabel = 'Add a device';
const String _addLabel = 'Add';
const String _removeLabel = 'Remove';

List<Device> _listLiveOutsiders(AppDependencies dependencies) {
  return <Device>[
    for (final Device device in dependencies.deviceRepository.listDevices())
      if (!device.revoked &&
          !device.workspaces.contains(devicesPageWorkspaceId))
        device,
  ];
}

Set<DeviceId> _listMemberIds(AppDependencies dependencies) {
  return <DeviceId>{
    for (final Device device in listLiveMembers(dependencies)) device.id,
  };
}

Finder _findDialogAddButtons() {
  return find.descendant(
    of: find.byType(AddWorkspaceDeviceDialog),
    matching: find.widgetWithText(AppButton, _addLabel),
  );
}

Future<AppDependencies> _openAddDialog(
  WidgetTester tester,
  Random random,
) async {
  final AppDependencies dependencies = buildRandomDevicesDependencies(random);
  await pumpCompactDevicesPage(
    tester,
    random: random,
    dependencies: dependencies,
  );
  await tapButtonLabelled(tester, _addDeviceLabel);
  return dependencies;
}

void main() {
  testWidgets('test_add_device_property_offers_only_live_outsiders', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(74001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await _openAddDialog(
        tester,
        random,
      );

      final int outsiderCount = _listLiveOutsiders(dependencies).length;
      expect(_findDialogAddButtons(), findsNWidgets(outsiderCount));
    }
  });

  testWidgets('test_add_device_property_adds_exactly_the_chosen_device', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(74002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await _openAddDialog(
        tester,
        random,
      );
      final List<Device> outsiders = _listLiveOutsiders(dependencies);
      if (outsiders.isEmpty) {
        continue;
      }
      final int chosenIndex = random.nextInt(outsiders.length);
      final Set<DeviceId> membersBefore = _listMemberIds(dependencies);

      final Finder chosenButton = _findDialogAddButtons().at(chosenIndex);
      await tester.ensureVisible(chosenButton);
      await tester.tap(chosenButton);
      await pumpFrames(tester);

      final DeviceId addedId = outsiders[chosenIndex].id;
      expect(tester.takeException(), isNull);
      expect(_listMemberIds(dependencies), <DeviceId>{
        ...membersBefore,
        addedId,
      });
      expect(findSectionRow(workspaceSectionTitle, addedId), findsOneWidget);
    }
  });

  testWidgets('test_remove_device_property_takes_out_only_that_device', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(74003);

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
      final Set<DeviceId> membersBefore = _listMemberIds(dependencies);
      final List<DeviceId> removable = <DeviceId>[
        for (final DeviceId memberId in membersBefore)
          if (memberId != thisDeviceId) memberId,
      ];
      if (removable.isEmpty) {
        continue;
      }
      final DeviceId removedId = pickOne(random, removable);

      final Finder row = findSectionRow(workspaceSectionTitle, removedId);
      final Finder remove = findTextInRow(row, _removeLabel);
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(
        _listMemberIds(dependencies),
        membersBefore.difference(<DeviceId>{removedId}),
      );
      expect(findSectionRow(workspaceSectionTitle, removedId), findsNothing);
      expect(
        findSectionRow(allDevicesSectionTitle, removedId),
        findsOneWidget,
      );
    }
  });
}
