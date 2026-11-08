import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/folders/runner_folder_picker.dart';

import '../support/random_inputs.dart';
import '../support/sample_folder_paths.dart';
import 'support/folder_channel_calls.dart';

const String _runnerChannelConstant = 'channelName';
const String _runnerMethodConstant = 'chooseFolderMethod';

String? _randomChoice(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return buildTemporaryFolderPath(randomText(random));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('test_runner_folder_picker_constructor_property_asks_only_when_'
      'asked_and_creates_nothing', () async {
    final Random random = seededRandom(91301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderChannels channels = answerBothFolderChannels(
        chosenFolder: _randomChoice(random),
      );
      final List<String> createdPaths = <String>[];

      const FolderPicker picker = RunnerFolderPicker();
      final int callsBeforeAsking = channels.runner.calls.length;
      await recordFolderCreations(createdPaths, picker.chooseFolder);

      expect(callsBeforeAsking, 0);
      expect(channels.runner.calls.length, 1);
      expect(channels.fileSelector.calls, isEmpty);
      expect(createdPaths, isEmpty);
    }
  });

  test('test_runner_folder_picker_constructor_property_holds_no_state_'
      'between_asks', () async {
    final Random random = seededRandom(91302);
    const FolderPicker picker = RunnerFolderPicker();

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String? chosenFolder = _randomChoice(random);
      answerBothFolderChannels(chosenFolder: chosenFolder);

      final String? answered = await picker.chooseFolder();

      expect(answered, chosenFolder);
    }
  });

  test('test_runner_folder_picker_constructor_property_asks_only_the_'
      'runner', () async {
    final Random random = seededRandom(91303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderChannels channels = answerBothFolderChannels(
        chosenFolder: _randomChoice(random),
      );

      await const RunnerFolderPicker().chooseFolder();

      expect(channels.fileSelector.calls, isEmpty);
      expect(channels.runner.calls.length, 1);
    }
  });

  test('test_runner_folder_picker_choose_folder_property_names_match_the_'
      'runner_and_send_no_arguments', () async {
    final Random random = seededRandom(91304);

    expect(folderChannel.name, readRunnerSwiftConstant(_runnerChannelConstant));
    expect(chooseFolderMethod, readRunnerSwiftConstant(_runnerMethodConstant));
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FolderChannels channels = answerBothFolderChannels(
        chosenFolder: _randomChoice(random),
      );

      await const RunnerFolderPicker().chooseFolder();

      final List<MethodCall> calls = channels.runner.calls;
      expect(calls.single.method, chooseFolderMethod);
      expect(calls.single.arguments, isNull);
    }
  });

  test('test_runner_folder_picker_choose_folder_property_runner_failures_'
      'reach_the_caller', () async {
    final Random random = seededRandom(91305);
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(folderChannel, null));

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String errorCode = 'code ${randomText(random)}';
      messenger.setMockMethodCallHandler(
        folderChannel,
        (MethodCall call) => throw PlatformException(code: errorCode),
      );

      await expectLater(
        const RunnerFolderPicker().chooseFolder(),
        throwsA(
          isA<PlatformException>().having(
            (PlatformException error) => error.code,
            'code',
            errorCode,
          ),
        ),
      );
    }
  });
}
