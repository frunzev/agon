import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/folders/platform_folder_picker.dart';

import '../support/random_inputs.dart';
import '../support/sample_folder_paths.dart';
import 'support/folder_channel_calls.dart';

const String _getDirectoryPathMethod = 'getDirectoryPath';
const String _confirmButtonArgument = 'confirmButtonText';
const String _runnerButtonTitleConstant = 'chooseButtonTitle';

String? _randomChoice(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return buildTemporaryFolderPath(randomText(random));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('test_platform_folder_picker_constructor_property_asks_only_when_'
      'asked_and_creates_nothing', () async {
    final Random random = seededRandom(91201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderChannels channels = answerBothFolderChannels(
        chosenFolder: _randomChoice(random),
      );
      final List<String> createdPaths = <String>[];

      const FolderPicker picker = PlatformFolderPicker();
      final int callsBeforeAsking = channels.fileSelector.calls.length;
      await recordFolderCreations(createdPaths, picker.chooseFolder);

      expect(callsBeforeAsking, 0);
      expect(channels.fileSelector.calls.length, 1);
      expect(channels.runner.calls, isEmpty);
      expect(createdPaths, isEmpty);
    }
  });

  test('test_platform_folder_picker_constructor_property_holds_no_state_'
      'between_asks', () async {
    final Random random = seededRandom(91202);
    const FolderPicker picker = PlatformFolderPicker();

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String? chosenFolder = _randomChoice(random);
      answerBothFolderChannels(chosenFolder: chosenFolder);

      final String? answered = await picker.chooseFolder();

      expect(answered, chosenFolder);
    }
  });

  test('test_platform_folder_picker_constructor_property_asks_only_the_file_'
      'selector', () async {
    final Random random = seededRandom(91203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderChannels channels = answerBothFolderChannels(
        chosenFolder: _randomChoice(random),
      );

      await const PlatformFolderPicker().chooseFolder();

      expect(channels.runner.calls, isEmpty);
      expect(channels.fileSelector.calls.length, 1);
    }
  });

  test('test_platform_folder_picker_choose_folder_property_confirm_button_'
      'matches_the_runner_panel', () async {
    final Random random = seededRandom(91204);
    final String runnerButtonTitle = readRunnerSwiftConstant(
      _runnerButtonTitleConstant,
    );

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderChannels channels = answerBothFolderChannels(
        chosenFolder: _randomChoice(random),
      );

      await const PlatformFolderPicker().chooseFolder();

      final List<String> askedMethods = <String>[];
      final List<Object?> confirmButtons = <Object?>[];
      for (final MethodCall call in channels.fileSelector.calls) {
        final Map<Object?, Object?> arguments =
            call.arguments as Map<Object?, Object?>;
        askedMethods.add(call.method);
        confirmButtons.add(arguments[_confirmButtonArgument]);
      }
      expect(askedMethods, <String>[_getDirectoryPathMethod]);
      expect(confirmButtons, <Object?>[runnerButtonTitle]);
    }
  });
}
