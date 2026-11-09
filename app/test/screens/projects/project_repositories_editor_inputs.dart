import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/screens/projects/agent_access_choices.dart';
import 'package:agent_orchestration/screens/projects/project_repositories_editor.dart';

import '../../support/random_inputs.dart';
import '../../support/random_repository_addresses.dart';

const DeviceId editorDeviceId = GalleryDeviceIds.airLaptop;
const String _unusedByTheEditor = 'the repositories editor never asks this';
const List<String> _folderParents = <String>['/work', '/code/web', '/x'];
const List<String> _hostedPrefixes = <String>['', 'https://', 'HTTPS://'];

final class ScriptedFolderDevices extends ChangeNotifier
    implements DeviceRepository {
  ScriptedFolderDevices({required this.gitlessPaths});

  final Set<String> gitlessPaths;
  final List<String> checkedPaths = <String>[];
  final List<String> createdPaths = <String>[];
  Object? refusal;
  Completer<void>? heldAnswer;

  Future<CheckedFolder> _answer(
    String path, {
    required bool hasStartedGit,
  }) async {
    final Completer<void>? held = heldAnswer;
    if (held != null) {
      await held.future;
    }

    final Object? plannedRefusal = refusal;
    if (plannedRefusal != null) {
      return Future<CheckedFolder>.error(plannedRefusal);
    }
    return CheckedFolder(
      repository: RepositoryDraft(
        address: renderEditorFolderAddress(path),
        defaultBranch: defaultRepositoryBranch,
      ),
      hasStartedGit: hasStartedGit,
    );
  }

  @override
  Future<CheckedFolder> checkLocalFolder(String path) {
    checkedPaths.add(path);
    return _answer(path, hasStartedGit: gitlessPaths.contains(path));
  }

  @override
  Future<CheckedFolder> createLocalFolder({
    required String parent,
    required String name,
  }) {
    final String path = '$parent/$name';
    createdPaths.add(path);
    return _answer(path, hasStartedGit: true);
  }

  @override
  List<Device> listDevices() => throw UnsupportedError(_unusedByTheEditor);

  @override
  Device findDevice(DeviceId deviceId) {
    throw UnsupportedError(_unusedByTheEditor);
  }

  @override
  Device currentDevice() => throw UnsupportedError(_unusedByTheEditor);

  @override
  String? findPeerAddressProblem() {
    throw UnsupportedError(_unusedByTheEditor);
  }

  @override
  Future<Device> revokeDevice(DeviceId deviceId) {
    throw UnsupportedError(_unusedByTheEditor);
  }

  @override
  Future<Device> addDeviceToWorkspace(
    DeviceId deviceId,
    WorkspaceId workspaceId,
  ) {
    throw UnsupportedError(_unusedByTheEditor);
  }

  @override
  Future<Device> removeDeviceFromWorkspace(
    DeviceId deviceId,
    WorkspaceId workspaceId,
  ) {
    throw UnsupportedError(_unusedByTheEditor);
  }
}

final class HeldFolderPicker implements FolderPicker {
  HeldFolderPicker();

  final Completer<String?> chosenPath = Completer<String?>();
  int chooseCount = 0;

  @override
  Future<String?> chooseFolder() {
    chooseCount += 1;
    return chosenPath.future;
  }

  @override
  Future<String> prepareNewProjectsFolder() {
    throw UnsupportedError(_unusedByTheEditor);
  }
}

final class EditorUnderTest {
  EditorUnderTest({
    required List<RepositoryDraft> initialRepositories,
    required this.devices,
    required FolderPicker? folderPicker,
  }) {
    editor = ProjectRepositoriesEditor(
      initialRepositories: initialRepositories,
      deviceRepository: devices,
      folderPicker: folderPicker,
      onFirstRepositoryKept: firstKeptRepositories.add,
    );
    editor.addListener(_countNotification);
  }

  final ScriptedFolderDevices devices;
  final List<RepositoryDraft> firstKeptRepositories = <RepositoryDraft>[];
  late final ProjectRepositoriesEditor editor;
  int notificationCount = 0;

  void _countNotification() {
    notificationCount += 1;
  }

  List<String> listAddresses() {
    return <String>[
      for (final RepositoryDraft repository in editor.repositories)
        repository.address,
    ];
  }

  Future<void> typeAndAdd(String text) {
    editor.addressController.text = text;
    return editor.addTypedRepository();
  }
}

EditorUnderTest buildEditorUnderTest({
  required List<RepositoryDraft> initialRepositories,
  required FolderPicker? folderPicker,
}) {
  return EditorUnderTest(
    initialRepositories: initialRepositories,
    devices: ScriptedFolderDevices(gitlessPaths: <String>{}),
    folderPicker: folderPicker,
  );
}

String randomCanonicalHostedAddress(Random random) {
  final String host = randomRepositoryHost(random);
  final String owner = randomPathPartWithoutGitSuffix(random);
  final String name = randomPathPartWithoutGitSuffix(random);
  return '$host/$owner/$name';
}

String randomSpellingOf(Random random, String canonicalAddress) {
  final List<String> parts = canonicalAddress.split('/');
  final String host = scrambleLetterCase(random, parts.first);
  final String path = parts.skip(1).join('/');
  if (random.nextInt(4) == 0) {
    return 'git@$host:$path$gitSuffix';
  }
  final String prefix = pickOne(random, _hostedPrefixes);
  final String suffix = random.nextBool() ? gitSuffix : '';
  final String slashes = random.nextBool() ? '/' : '';
  return ' $prefix$host/$path$suffix$slashes ';
}

String randomFolderPath(Random random, int index) {
  return '${pickOne(random, _folderParents)}/f${random.nextInt(9)}-$index';
}

String renderEditorFolderAddress(String path) {
  return renderLocalFolderAddress(deviceId: editorDeviceId, path: path);
}

List<RepositoryDraft> randomInitialDrafts(Random random) {
  final int count = random.nextInt(4);
  return <RepositoryDraft>[
    for (int index = 0; index < count; index += 1)
      RepositoryDraft(
        address: '${randomCanonicalHostedAddress(random)}-$index',
        defaultBranch: pickOne(random, <String>['main', 'trunk', 'dev']),
      ),
  ];
}
