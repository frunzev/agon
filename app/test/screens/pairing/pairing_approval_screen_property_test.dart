import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/screens/pairing.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';

import '../../support/random_inputs.dart';
import 'pairing_flow_harness.dart';

const String _noDeviceTitle = 'No device is waiting';
const String _noDeviceSummary = 'Show a pairing code to add a device.';

PairingApprovalScreen _buildScreen(AppDependencies dependencies, Key? key) {
  return PairingApprovalScreen(
    pairingRepository: dependencies.pairingRepository,
    deviceRepository: dependencies.deviceRepository,
    workspaceRepository: dependencies.workspaceRepository,
    navigation: AppNavigation(initialRoute: devicesRoute),
    key: key,
  );
}

void _expectRequestShown(PairingRequest request) {
  expect(find.text('Approve ${request.deviceName}?'), findsWidgets);
  expect(
    find.text('It wants to join as ${describeRoleWithArticle(request.role)}.'),
    findsOneWidget,
  );
  expect(find.byType(FingerprintWords), findsOneWidget);
  expect(find.text(_noDeviceTitle), findsNothing);
}

void main() {
  test('test_pairing_approval_screen_new_property_keeps_every_dependency', () {
    final Random random = seededRandom(104801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final ValueKey<int> key = ValueKey<int>(random.nextInt(1 << 20));

      final PairingApprovalScreen screen = _buildScreen(dependencies, key);

      expect(screen.pairingRepository, same(dependencies.pairingRepository));
      expect(screen.deviceRepository, same(dependencies.deviceRepository));
      expect(
        screen.workspaceRepository,
        same(dependencies.workspaceRepository),
      );
      expect(screen.key, key);
    }
  });

  test('test_pairing_approval_screen_new_property_shares_one_navigation', () {
    final Random random = seededRandom(104802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = AppNavigation(
        initialRoute: devicesRoute,
      );

      final List<PairingApprovalScreen> screens = <PairingApprovalScreen>[
        for (int index = 0; index < 1 + random.nextInt(3); index += 1)
          PairingApprovalScreen(
            pairingRepository: dependencies.pairingRepository,
            deviceRepository: dependencies.deviceRepository,
            workspaceRepository: dependencies.workspaceRepository,
            navigation: navigation,
          ),
      ];

      for (final PairingApprovalScreen screen in screens) {
        expect(screen.navigation, same(navigation));
      }
    }
  });

  testWidgets('test_pairing_approval_screen_new_property_shows_the_request_'
      'it_reads', (WidgetTester tester) async {
    final Random random = seededRandom(104803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingRequest request = randomPairingRequest(random);

      await openApprovalPage(
        tester,
        size: randomPairingWindow(random),
        request: request,
        workspaces: randomWorkspaces(random),
      );

      _expectRequestShown(request);
    }
  });

  test('test_pairing_approval_screen_create_state_property_every_call_'
      'makes_a_fresh_state', () {
    final Random random = seededRandom(104804);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingApprovalScreen screen = _buildScreen(
        buildGalleryDependencies(),
        null,
      );
      final int count = 2 + random.nextInt(4);

      final Set<State<PairingApprovalScreen>> states =
          <State<PairingApprovalScreen>>{
            for (int index = 0; index < count; index += 1)
              screen.createState(),
          };

      expect(states, hasLength(count));
    }
  });

  testWidgets('test_pairing_approval_screen_create_state_property_starts_'
      'with_the_current_workspace', (WidgetTester tester) async {
    final Random random = seededRandom(104805);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await openApprovalPage(
        tester,
        size: randomPairingWindow(random),
        request: randomPairingRequest(random),
        workspaces: randomWorkspaces(random),
      );

      final String current = page.dependencies.workspaceRepository
          .currentWorkspace()
          .name;
      expect(find.text(current), findsWidgets);
      expect(find.text('Choose at least one workspace'), findsNothing);
    }
  });

  testWidgets('test_pairing_approval_screen_create_state_property_starts_'
      'ready_to_decide', (WidgetTester tester) async {
    final Random random = seededRandom(104806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openApprovalPage(
        tester,
        size: randomPairingWindow(random),
        request: randomPairingRequest(random),
        workspaces: randomWorkspaces(random),
      );

      for (final String label in <String>['Approve', 'Reject']) {
        expect(isButtonEnabled(tester, label), isTrue, reason: label);
      }
    }
  });

  testWidgets('test_pairing_approval_screen_build_property_without_a_'
      'request_explains_there_is_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(104807);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openApprovalPage(
        tester,
        size: randomPairingWindow(random),
        request: null,
        workspaces: randomWorkspaces(random),
      );

      expect(find.text(_noDeviceTitle), findsWidgets);
      expect(find.text(_noDeviceSummary), findsOneWidget);
      expect(find.byType(FingerprintWords), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_pairing_approval_screen_build_property_names_both_'
      'ends_of_the_link', (WidgetTester tester) async {
    final Random random = seededRandom(104808);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingRequest request = randomPairingRequest(random);

      final PairingPage page = await openApprovalPage(
        tester,
        size: randomPairingWindow(random),
        request: request,
        workspaces: randomWorkspaces(random),
      );

      final String approver = page.dependencies.deviceRepository
          .currentDevice()
          .name;
      expect(find.text(request.deviceName), findsWidgets);
      expect(find.text(approver), findsWidgets);
    }
  });

  testWidgets('test_pairing_approval_screen_build_property_any_request_'
      'fits_any_window', (WidgetTester tester) async {
    final Random random = seededRandom(104809);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = randomPairingWindow(random);
      final PairingRequest request = randomPairingRequest(random);

      await openApprovalPage(
        tester,
        size: size,
        request: request,
        workspaces: randomWorkspaces(random),
      );

      expect(tester.takeException(), isNull, reason: '$size');
      expect(
        find.text(
          '${request.deviceName} shows four words. Approve only if '
          'they match these, in this order.',
        ),
        findsOneWidget,
      );
    }
  });
}
