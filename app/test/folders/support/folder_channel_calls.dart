import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/folders/runner_folder_picker.dart';

const MethodChannel fileSelectorChannel = MethodChannel(
  'plugins.flutter.io/file_selector',
);
const String runnerFolderChannelSource = 'macos/Runner/FolderChannel.swift';

final class AnsweringFolderChannel {
  AnsweringFolderChannel({required this.chosenFolder});

  final String? chosenFolder;
  final List<MethodCall> calls = <MethodCall>[];

  Future<Object?> answer(MethodCall call) async {
    calls.add(call);
    return chosenFolder;
  }
}

typedef FolderChannels = ({
  AnsweringFolderChannel runner,
  AnsweringFolderChannel fileSelector,
});

AnsweringFolderChannel answerFolderChannel(
  MethodChannel channel, {
  required String? chosenFolder,
}) {
  final AnsweringFolderChannel answering = AnsweringFolderChannel(
    chosenFolder: chosenFolder,
  );
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(channel, answering.answer);
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return answering;
}

FolderChannels answerBothFolderChannels({required String? chosenFolder}) {
  return (
    runner: answerFolderChannel(folderChannel, chosenFolder: chosenFolder),
    fileSelector: answerFolderChannel(
      fileSelectorChannel,
      chosenFolder: chosenFolder,
    ),
  );
}

Future<T> recordFolderCreations<T>(
  List<String> createdPaths,
  Future<T> Function() body,
) {
  return IOOverrides.runZoned(
    body,
    createDirectory: (String path) =>
        _RecordingDirectory(path: path, createdPaths: createdPaths),
  );
}

String readRunnerSwiftConstant(String constantName) {
  final String source = File(runnerFolderChannelSource).readAsStringSync();
  final RegExp declaration = RegExp('let $constantName = "([^"]*)"');
  final RegExpMatch? match = declaration.firstMatch(source);
  if (match == null) {
    throw StateError('$runnerFolderChannelSource has no $constantName');
  }
  return match.group(1)!;
}

final class _RecordingDirectory extends Fake implements Directory {
  _RecordingDirectory({required this.path, required this.createdPaths});

  @override
  final String path;
  final List<String> createdPaths;

  @override
  Future<Directory> create({bool recursive = false}) async {
    createdPaths.add(path);
    return this;
  }
}
