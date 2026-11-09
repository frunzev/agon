import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/devices/all_devices_section.dart';
import 'package:agent_orchestration/screens/devices/devices_screen.dart';
import 'package:agent_orchestration/screens/devices/workspace_devices_section.dart';
import 'package:agent_orchestration/screens/shared/scope_catalog_lookup.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/random_devices_page.dart';

typedef _ExpectKeepsFields = void Function(
  Widget widget,
  AppDependencies dependencies,
);

typedef _BuildSection = Widget Function(
  AppDependencies dependencies,
  AppNavigation navigation,
  Key? key,
);

final class _SectionCase {
  const _SectionCase({
    required this.typeName,
    required this.build,
    required this.expectKeepsFields,
    required this.placeOnPage,
  });

  final String typeName;
  final _BuildSection build;
  final _ExpectKeepsFields expectKeepsFields;
  final Widget Function(Widget widget) placeOnPage;
}

ScopeCatalog _collectCatalog(AppDependencies dependencies) {
  return collectScopeCatalog(
    workspaceRepository: dependencies.workspaceRepository,
    projectRepository: dependencies.projectRepository,
  );
}

void _ignoreShowAllDevices() {}

Widget _buildAllDevices(
  AppDependencies dependencies,
  AppNavigation navigation,
  Key? key,
) {
  return AllDevicesSection(
    key: key,
    deviceRepository: dependencies.deviceRepository,
    pairingRepository: dependencies.pairingRepository,
    workspaceRepository: dependencies.workspaceRepository,
    catalog: _collectCatalog(dependencies),
    clock: dependencies.clock,
    navigation: navigation,
  );
}

Widget _buildWorkspaceDevices(
  AppDependencies dependencies,
  AppNavigation navigation,
  Key? key,
) {
  return WorkspaceDevicesSection(
    key: key,
    workspaceRepository: dependencies.workspaceRepository,
    deviceRepository: dependencies.deviceRepository,
    runnerRepository: dependencies.runnerRepository,
    clock: dependencies.clock,
    navigation: navigation,
    onShowAllDevices: _ignoreShowAllDevices,
  );
}

Widget _buildDevicesScreen(
  AppDependencies dependencies,
  AppNavigation navigation,
  Key? key,
) {
  return DevicesScreen(
    key: key,
    deviceRepository: dependencies.deviceRepository,
    runnerRepository: dependencies.runnerRepository,
    pairingRepository: dependencies.pairingRepository,
    workspaceRepository: dependencies.workspaceRepository,
    projectRepository: dependencies.projectRepository,
    clock: dependencies.clock,
    navigation: navigation,
  );
}

void _expectSame(Object kept, Object given) {
  expect(identical(kept, given), isTrue);
}

void _expectAllDevicesFields(Widget widget, AppDependencies dependencies) {
  final AllDevicesSection section = widget as AllDevicesSection;
  _expectSame(section.deviceRepository, dependencies.deviceRepository);
  _expectSame(section.pairingRepository, dependencies.pairingRepository);
  _expectSame(section.workspaceRepository, dependencies.workspaceRepository);
  _expectSame(section.clock, dependencies.clock);
}

void _expectWorkspaceDevicesFields(
  Widget widget,
  AppDependencies dependencies,
) {
  final WorkspaceDevicesSection section = widget as WorkspaceDevicesSection;
  _expectSame(section.workspaceRepository, dependencies.workspaceRepository);
  _expectSame(section.deviceRepository, dependencies.deviceRepository);
  _expectSame(section.runnerRepository, dependencies.runnerRepository);
  _expectSame(section.clock, dependencies.clock);
  expect(section.onShowAllDevices, _ignoreShowAllDevices);
}

void _expectDevicesScreenFields(Widget widget, AppDependencies dependencies) {
  final DevicesScreen screen = widget as DevicesScreen;
  _expectSame(screen.deviceRepository, dependencies.deviceRepository);
  _expectSame(screen.runnerRepository, dependencies.runnerRepository);
  _expectSame(screen.pairingRepository, dependencies.pairingRepository);
  _expectSame(screen.workspaceRepository, dependencies.workspaceRepository);
  _expectSame(screen.projectRepository, dependencies.projectRepository);
  _expectSame(screen.clock, dependencies.clock);
}

Widget _placeInScrollingPage(Widget section) {
  return SingleChildScrollView(child: section);
}

Widget _placeAsWholePage(Widget screen) {
  return screen;
}

const List<_SectionCase> _sectionCases = <_SectionCase>[
  _SectionCase(
    typeName: 'all_devices_section',
    build: _buildAllDevices,
    expectKeepsFields: _expectAllDevicesFields,
    placeOnPage: _placeInScrollingPage,
  ),
  _SectionCase(
    typeName: 'workspace_devices_section',
    build: _buildWorkspaceDevices,
    expectKeepsFields: _expectWorkspaceDevicesFields,
    placeOnPage: _placeInScrollingPage,
  ),
  _SectionCase(
    typeName: 'devices_screen',
    build: _buildDevicesScreen,
    expectKeepsFields: _expectDevicesScreenFields,
    placeOnPage: _placeAsWholePage,
  ),
];

AppNavigation _buildNavigation() {
  return AppNavigation(initialRoute: const SectionRoute(AppSection.devices));
}

void _registerSectionProperties(_SectionCase sectionCase, int seed) {
  final String prefix = 'test_${sectionCase.typeName}_new_property';

  test('${prefix}_keeps_every_field', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildRandomDevicesDependencies(
        random,
      );
      final AppNavigation navigation = _buildNavigation();
      final Key key = UniqueKey();

      final Widget widget = sectionCase.build(dependencies, navigation, key);

      expect(widget.key, key);
      sectionCase.expectKeepsFields(widget, dependencies);
    }
  });

  test('${prefix}_has_no_key_unless_given', () {
    final Random random = seededRandom(seed + 1);
    final AppDependencies dependencies = buildRandomDevicesDependencies(
      random,
    );

    final Widget widget = sectionCase.build(
      dependencies,
      _buildNavigation(),
      null,
    );

    expect(widget.key, isNull);
  });

  testWidgets('${prefix}_renders_alone_at_any_width', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildRandomDevicesDependencies(
        random,
      );
      final Widget widget = sectionCase.build(
        dependencies,
        _buildNavigation(),
        null,
      );
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );

      useViewSize(tester, Size(width, desktopHeight));
      await tester.pumpWidget(
        wrapInApp(
          sectionCase.placeOnPage(widget),
          platform: platformMeantByWidth(width),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}

void main() {
  int seed = 73901;
  for (final _SectionCase sectionCase in _sectionCases) {
    _registerSectionProperties(sectionCase, seed);
    seed += 10;
  }
}
