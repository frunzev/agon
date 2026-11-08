import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/folders/folder_picker_choice.dart';

import '../support/random_inputs.dart';
import '../support/sample_folder_paths.dart';
import 'support/folder_channel_calls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('test_build_platform_folder_picker_property_only_macos_asks_the_'
      'runner_channel', () async {
    final Random random = seededRandom(91101);

    for (final TargetPlatform platform in TargetPlatform.values) {
      final String chosenFolder = buildTemporaryFolderPath(
        randomText(random),
      );
      final FolderChannels channels = answerBothFolderChannels(
        chosenFolder: chosenFolder,
      );

      final String? answered = await buildPlatformFolderPicker(
        platform,
      ).chooseFolder();

      final bool isMacos = platform == TargetPlatform.macOS;
      expect(answered, chosenFolder, reason: platform.name);
      expect(channels.runner.calls.length, isMacos ? 1 : 0);
      expect(channels.fileSelector.calls.length, isMacos ? 0 : 1);
    }
  });

  test('test_build_platform_folder_picker_property_same_platform_gives_the_'
      'same_picker', () {
    final Random random = seededRandom(91102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TargetPlatform platform = pickOne(random, TargetPlatform.values);

      final FolderPicker first = buildPlatformFolderPicker(platform);
      final FolderPicker second = buildPlatformFolderPicker(platform);

      expect(identical(first, second), isTrue, reason: platform.name);
    }
  });

  test('test_build_platform_folder_picker_property_every_platform_prepares_'
      'the_same_folder', () async {
    final Set<String> preparedFolders = <String>{};
    final List<String> createdPaths = <String>[];

    for (final TargetPlatform platform in TargetPlatform.values) {
      final FolderPicker picker = buildPlatformFolderPicker(platform);
      final FolderChannels channels = answerBothFolderChannels(
        chosenFolder: null,
      );

      preparedFolders.add(
        await recordFolderCreations(
          createdPaths,
          picker.prepareNewProjectsFolder,
        ),
      );

      expect(channels.runner.calls, isEmpty, reason: platform.name);
      expect(channels.fileSelector.calls, isEmpty, reason: platform.name);
    }

    expect(preparedFolders.length, 1);
    expect(createdPaths.toSet(), preparedFolders);
  });
}
