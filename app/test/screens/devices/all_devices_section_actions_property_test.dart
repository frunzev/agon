import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/screens/devices/revoke_device_dialog.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_scopes.dart';
import '../support/refused_action_properties.dart';
import 'support/random_devices_page.dart';

const String _pairLabel = 'Pair a device';
const String _revokeLabel = 'Revoke';
const String _keepLabel = 'Keep device';
const String _confirmRevokeLabel = 'Revoke device';
const int _mostMinutesAway = 30;

AppDependencies _withPairingSession(
  AppDependencies base,
  PairingSession? session,
) {
  return replaceRepositories(
    base,
    pairingRepository: FakePairingRepository(
      session: session,
      request: null,
      clock: base.clock,
      deviceRepository: base.deviceRepository as FakeDeviceRepository,
      joinOutcome: galleryPairingOutcome,
      startedPairingRendezvousProblem: null,
    ),
  );
}

PairingSession _sessionEndingIn(Random random, DateTime end) {
  return PairingSession(
    code: 'CODE-${random.nextInt(1 << 20)}',
    createdAt: end.subtract(const Duration(minutes: 5)),
    expiresAt: end,
    rendezvousProblem: null,
  );
}

Duration _randomMinutes(Random random) {
  return Duration(minutes: 1 + random.nextInt(_mostMinutesAway));
}

Future<AppNavigation> _pressPair(
  WidgetTester tester,
  Random random,
  AppDependencies dependencies,
) async {
  final AppNavigation navigation = await pumpDevicesPage(
    tester,
    random: random,
    dependencies: dependencies,
  );
  await tapButtonLabelled(tester, _pairLabel);
  return navigation;
}

Device? _pickOtherLiveDevice(Random random, AppDependencies dependencies) {
  final Device thisDevice = dependencies.deviceRepository.currentDevice();
  final List<Device> others = <Device>[
    for (final Device device in dependencies.deviceRepository.listDevices())
      if (!device.revoked && device.id != thisDevice.id) device,
  ];
  if (others.isEmpty) {
    return null;
  }
  return pickOne(random, others);
}

Finder _findInDialog(String text) {
  return find.descendant(
    of: find.byType(RevokeDeviceDialog),
    matching: find.text(text, findRichText: true),
  );
}

Future<void> _openRevokeDialog(WidgetTester tester, Device device) async {
  final Finder row = findSectionRow(allDevicesSectionTitle, device.id);
  final Finder revoke = findTextInRow(row, _revokeLabel);
  await tester.ensureVisible(revoke);
  await tester.tap(revoke);
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_show_pairing_code_property_starts_a_code_if_none_shows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73401);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = _withPairingSession(
        buildRandomDevicesDependencies(random),
        null,
      );

      final AppNavigation navigation = await _pressPair(
        tester,
        random,
        dependencies,
      );

      expect(dependencies.pairingRepository.findActiveSession(), isNotNull);
      expect(navigation.currentRoute, const PairingCodeRoute());
    }
  });

  testWidgets('test_show_pairing_code_property_keeps_the_showing_code', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies base = buildRandomDevicesDependencies(random);
      final DateTime end = base.clock.now().add(_randomMinutes(random));
      final PairingSession showing = _sessionEndingIn(random, end);
      final AppDependencies dependencies = _withPairingSession(base, showing);

      final AppNavigation navigation = await _pressPair(
        tester,
        random,
        dependencies,
      );

      final PairingSession? active = dependencies.pairingRepository
          .findActiveSession();
      expect(active?.code, showing.code);
      expect(navigation.currentRoute, const PairingCodeRoute());
    }
  });

  testWidgets('test_show_pairing_code_property_replaces_an_expired_code', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies base = buildRandomDevicesDependencies(random);
      final DateTime now = base.clock.now();
      final PairingSession expired = _sessionEndingIn(
        random,
        now.subtract(_randomMinutes(random)),
      );
      final AppDependencies dependencies = _withPairingSession(base, expired);

      await _pressPair(tester, random, dependencies);

      final PairingSession? active = dependencies.pairingRepository
          .findActiveSession();
      expect(active, isNotNull);
      expect(active!.expiresAt.isAfter(now), isTrue);
      expect(active.code, isNot(expired.code));
    }
  });

  testWidgets('test_review_revoke_property_dialog_states_the_device_facts', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildRandomDevicesDependencies(
        random,
      );
      await pumpCompactDevicesPage(
        tester,
        random: random,
        dependencies: dependencies,
      );
      final Device? device = _pickOtherLiveDevice(random, dependencies);
      if (device == null) {
        continue;
      }

      await _openRevokeDialog(tester, device);

      final DateTime now = dependencies.clock.now();
      final List<Device> devices = dependencies.deviceRepository.listDevices();
      final String workspaceNames = describeWorkspaceNames(
        device.workspaces,
        galleryCatalog,
      );
      final List<String> facts = <String>[
        'Revoke ${device.name}?',
        device.role.label,
        describeLastSeen(device.lastSeen, now),
        describeDevicePairing(device, DeviceNames(devices)),
        if (workspaceNames.isNotEmpty) workspaceNames,
      ];
      for (final String fact in facts) {
        expect(_findInDialog(fact), findsOneWidget, reason: fact);
      }
      await tapButtonLabelled(tester, _keepLabel);
    }
  });

  testWidgets('test_review_revoke_property_keeping_changes_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildRandomDevicesDependencies(
        random,
      );
      await pumpCompactDevicesPage(
        tester,
        random: random,
        dependencies: dependencies,
      );
      final Device? device = _pickOtherLiveDevice(random, dependencies);
      if (device == null) {
        continue;
      }

      await _openRevokeDialog(tester, device);
      await tapButtonLabelled(tester, _keepLabel);

      final Device kept = dependencies.deviceRepository.findDevice(device.id);
      expect(kept.revoked, isFalse);
      expect(find.text(_confirmRevokeLabel), findsNothing);
      expect(
        findSectionRow(allDevicesSectionTitle, device.id),
        findsOneWidget,
      );
    }
  });

  testWidgets('test_review_revoke_property_revoked_device_leaves_both_lists', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildRandomDevicesDependencies(
        random,
      );
      await pumpCompactDevicesPage(
        tester,
        random: random,
        dependencies: dependencies,
      );
      final Device? device = _pickOtherLiveDevice(random, dependencies);
      if (device == null) {
        continue;
      }

      await _openRevokeDialog(tester, device);
      await tapButtonLabelled(tester, _confirmRevokeLabel);

      final Device revoked = dependencies.deviceRepository.findDevice(
        device.id,
      );
      expect(tester.takeException(), isNull);
      expect(revoked.revoked, isTrue);
      expect(findSectionRow(allDevicesSectionTitle, device.id), findsNothing);
      expect(findSectionRow(workspaceSectionTitle, device.id), findsNothing);
    }
  });
}
