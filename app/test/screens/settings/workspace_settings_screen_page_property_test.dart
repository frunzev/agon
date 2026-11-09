import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/screens/settings.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'support/settings_screen_harness.dart';

void main() {
  testWidgets(
    'test_build_page_property_title_and_summary_name_the_workspace',
    (WidgetTester tester) async {
      final Random random = seededRandom(311047);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final AppDependencies dependencies = buildGalleryDependencies();
        final List<Workspace> workspaces = await createRandomWorkspaces(
          random,
          dependencies,
        );
        final Workspace chosen = pickOne(random, workspaces);
        await dependencies.workspaceRepository.switchWorkspace(chosen.id);

        await pumpSettingsScreen(
          tester,
          size: randomWindowSize(random),
          dependencies: dependencies,
        );

        expect(findInSettingsScreen(find.text(settingsTitle)), findsOne);
        final String summary = describeWorkspaceSummary(chosen.name);
        expect(findInSettingsScreen(find.text(summary)), findsOneWidget);
      }
    },
  );

  testWidgets('test_build_page_property_delete_only_on_the_server_tab', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311048);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpSettingsScreen(
        tester,
        size: randomWindowSize(random),
        dependencies: buildGalleryDependencies(),
      );
      final SettingsTab tab = pickOne(random, SettingsTab.values);

      await selectSettingsTab(tester, tab);

      final Matcher expected = tab == SettingsTab.server
          ? findsOneWidget
          : findsNothing;
      expect(findSettingsDeleteButton(), expected, reason: tab.label);
    }
  });

  testWidgets('test_build_page_property_peer_banner_only_with_a_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311049);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool hasProblem = random.nextBool();
      final String problem =
          'peer address problem $i ${randomWordPhrase(random)}';
      final AppDependencies dependencies = replaceRepositories(
        buildGalleryDependencies(),
        deviceRepository: FakeDeviceRepository(
          devices: galleryDevices,
          currentDeviceId: GalleryDeviceIds.airLaptop,
          peerAddressProblem: hasProblem ? problem : null,
          gitlessFolderPaths: const <String>{},
        ),
      );

      await pumpSettingsScreen(
        tester,
        size: randomWindowSize(random),
        dependencies: dependencies,
      );

      final Matcher expected = hasProblem ? findsOneWidget : findsNothing;
      expect(findInSettingsScreen(find.byType(PeerAddressBanner)), expected);
      expect(find.text(problem), expected);
    }
  });
}
