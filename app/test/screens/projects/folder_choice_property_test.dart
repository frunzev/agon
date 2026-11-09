import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/screens/projects/folder_choice.dart';
import 'package:agent_orchestration/screens/projects/new_project_repos_field.dart';
import 'package:agent_orchestration/screens/setup/code_scanning.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/random_inputs.dart';

const Set<TargetPlatform> _computerPlatforms = <TargetPlatform>{
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.linux,
};

void main() {
  test('test_can_choose_folders_property_exactly_the_computers_choose', () {
    final Random random = seededRandom(104201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TargetPlatform platform = pickOne(random, TargetPlatform.values);

      expect(
        canChooseFolders(platform),
        _computerPlatforms.contains(platform),
        reason: '$platform',
      );
    }
  });

  test('test_can_choose_folders_property_never_overlaps_qr_scanning', () {
    final Random random = seededRandom(104202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TargetPlatform platform = pickOne(random, TargetPlatform.values);

      final bool choosesFolders = canChooseFolders(platform);
      final bool scansCodes = canScanQrCodes(platform);
      expect(choosesFolders && scansCodes, isFalse, reason: '$platform');
      if (platform != TargetPlatform.fuchsia) {
        expect(choosesFolders || scansCodes, isTrue, reason: '$platform');
      }
    }
  });

  testWidgets('test_can_choose_folders_property_new_project_offers_folders_'
      'only_where_allowed', (WidgetTester tester) async {
    final Random random = seededRandom(104203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TargetPlatform platform = pickOne(random, TargetPlatform.values);
      debugDefaultTargetPlatformOverride = platform;
      final AppDependencies dependencies = replaceRepositories(
        buildGalleryDependencies(),
        folderPicker: FixedFolderPicker(null),
      );
      await pumpApp(
        tester,
        size: pickOne(random, const <Size>[phoneSize, desktopSize]),
        route: const NewProjectRoute(),
        dependencies: dependencies,
      );

      final int expectedButtons = canChooseFolders(platform) ? 1 : 0;
      expect(find.text(chooseFolderLabel), findsNWidgets(expectedButtons));
      expect(find.text(createNewFolderLabel), findsNWidgets(expectedButtons));
      final String placeholder = canChooseFolders(platform)
          ? computerRepositoryPlaceholder
          : phoneRepositoryPlaceholder;
      expect(find.text(placeholder), findsOneWidget, reason: '$platform');
      expect(tester.takeException(), isNull, reason: '$platform');
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
