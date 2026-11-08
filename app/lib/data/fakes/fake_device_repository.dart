import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/control_characters.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

const String _deviceKind = 'device';
const int _forbiddenStatus = 403;
const int _notFoundStatus = 404;
const int _conflictStatus = 409;
const String _selfRevokeReason = 'a device cannot revoke itself';
const String _alreadyRevokedReason = 'the device is already revoked';
const String _revokedJoinReason = 'the device is revoked';
const String _alreadyMemberReason = 'the device is already in the workspace';
const String _notMemberReason = 'the workspace member was not found';
const String _missingKeyProblem = 'this device holds no key for workspace';
const String _folderSeparator = '/';
const String _currentFolder = '.';
const String _parentFolder = '..';
const String _fakeCheckedOutBranch = 'main';
final RegExp _folderSeparators = RegExp(r'[\\/]');

final class FakeDeviceRepository extends ChangeNotifier
    implements DeviceRepository {
  FakeDeviceRepository({
    required List<Device> devices,
    required DeviceId currentDeviceId,
    required String? peerAddressProblem,
    required Set<String> gitlessFolderPaths,
  }) : _devices = List<Device>.unmodifiable(devices),
       _currentDeviceId = currentDeviceId,
       _peerAddressProblem = peerAddressProblem,
       _gitlessFolderPaths = Set<String>.unmodifiable(gitlessFolderPaths) {
    findDevice(currentDeviceId);
  }

  final DeviceId _currentDeviceId;
  final String? _peerAddressProblem;
  Set<String> _gitlessFolderPaths;
  Set<String> _createdFolderPaths = const <String>{};
  List<Device> _devices;

  @override
  List<Device> listDevices() => _devices;

  @override
  Device findDevice(DeviceId deviceId) {
    return findRecord(
      _devices,
      matches: (Device device) => device.id == deviceId,
      kind: _deviceKind,
      identifier: deviceId.value,
    );
  }

  @override
  Device currentDevice() => findDevice(_currentDeviceId);

  @override
  String? findPeerAddressProblem() => _peerAddressProblem;

  @override
  Future<CheckedFolder> checkLocalFolder(String path) async {
    final String folderPath = _requireFolderPath(path);
    final bool hasStartedGit = _gitlessFolderPaths.contains(folderPath);
    _gitlessFolderPaths = _gitlessFolderPaths.difference(<String>{folderPath});

    return CheckedFolder(
      repository: RepositoryDraft(
        address: renderLocalFolderAddress(
          deviceId: _currentDeviceId,
          path: folderPath,
        ),
        defaultBranch: _fakeCheckedOutBranch,
      ),
      hasStartedGit: hasStartedGit,
    );
  }

  @override
  Future<CheckedFolder> createLocalFolder({
    required String parent,
    required String name,
  }) async {
    _requireSafeFolderName(name);
    final String parentPath = _requireFolderPath(parent);
    final String folderPath = '$parentPath$_folderSeparator$name';
    if (_createdFolderPaths.contains(folderPath)) {
      throw StateError(
        'the folder $folderPath already exists, so choose another name or '
        'place',
      );
    }
    _createdFolderPaths = <String>{..._createdFolderPaths, folderPath};

    return CheckedFolder(
      repository: RepositoryDraft(
        address: renderLocalFolderAddress(
          deviceId: _currentDeviceId,
          path: folderPath,
        ),
        defaultBranch: _fakeCheckedOutBranch,
      ),
      hasStartedGit: true,
    );
  }

  Future<Device> addPairedDevice(Device device) async {
    final bool isKnown = _devices.any(
      (Device candidate) => candidate.id == device.id,
    );
    if (isKnown) {
      throw StateError('Device ${device.name} is already paired');
    }

    _devices = appendRecord(_devices, device);
    notifyListeners();
    return device;
  }

  @override
  Future<Device> revokeDevice(DeviceId deviceId) async {
    if (deviceId == _currentDeviceId) {
      throw AppServerRefusal(
        status: _forbiddenStatus,
        reason: _selfRevokeReason,
      );
    }

    final Device device = findDevice(deviceId);
    if (device.revoked) {
      throw AppServerRefusal(
        status: _conflictStatus,
        reason: _alreadyRevokedReason,
      );
    }

    return _storeDevice(device.asRevoked());
  }

  @override
  Future<Device> addDeviceToWorkspace(
    DeviceId deviceId,
    WorkspaceId workspaceId,
  ) async {
    final Device device = findDevice(deviceId);
    if (!currentDevice().workspaces.contains(workspaceId)) {
      throw StateError('$_missingKeyProblem ${workspaceId.value}');
    }
    if (device.revoked) {
      throw AppServerRefusal(
        status: _conflictStatus,
        reason: _revokedJoinReason,
      );
    }
    if (device.workspaces.contains(workspaceId)) {
      throw AppServerRefusal(
        status: _conflictStatus,
        reason: _alreadyMemberReason,
      );
    }

    return _storeDevice(
      device.withWorkspaces(<WorkspaceId>[...device.workspaces, workspaceId]),
    );
  }

  @override
  Future<Device> removeDeviceFromWorkspace(
    DeviceId deviceId,
    WorkspaceId workspaceId,
  ) async {
    final Device device = findDevice(deviceId);
    if (!device.workspaces.contains(workspaceId)) {
      throw AppServerRefusal(
        status: _notFoundStatus,
        reason: _notMemberReason,
      );
    }
    final List<WorkspaceId> remaining = device.workspaces
        .where((WorkspaceId candidate) => candidate != workspaceId)
        .toList();

    return _storeDevice(device.withWorkspaces(remaining));
  }

  void grantWorkspaceToCurrentDevice(WorkspaceId workspaceId) {
    final Device current = currentDevice();
    if (current.workspaces.contains(workspaceId)) {
      return;
    }

    _storeDevice(
      current.withWorkspaces(<WorkspaceId>[
        ...current.workspaces,
        workspaceId,
      ]),
    );
  }

  void withdrawWorkspace(WorkspaceId deletedWorkspaceId) {
    _devices = List<Device>.unmodifiable(<Device>[
      for (final Device device in _devices)
        _withoutWorkspace(device, deletedWorkspaceId),
    ]);
    notifyListeners();
  }

  Device _storeDevice(Device device) {
    _devices = replaceRecord(
      _devices,
      matches: (Device candidate) => candidate.id == device.id,
      replacement: device,
    );
    notifyListeners();
    return device;
  }
}

Device _withoutWorkspace(Device device, WorkspaceId workspaceId) {
  if (!device.workspaces.contains(workspaceId)) {
    return device;
  }
  return device.withWorkspaces(<WorkspaceId>[
    for (final WorkspaceId joined in device.workspaces)
      if (joined != workspaceId) joined,
  ]);
}

String _requireFolderPath(String path) {
  final String? folderPath = normalizeFolderPath(path);
  if (folderPath != null) {
    return folderPath;
  }

  if (!isAbsoluteFolderPath(path)) {
    throw StateError('the folder "$path" is not an absolute path');
  }
  throw StateError(
    'the folder "$path" has a control character, an empty part, a . or '
    'a .. part',
  );
}

void _requireSafeFolderName(String name) {
  final bool isPadded = trimUnicodeWhiteSpace(name) != name;
  final bool isReserved = name == _currentFolder || name == _parentFolder;
  final bool hasUnsafeCharacter =
      name.contains(_folderSeparators) || hasControlCharacter(name);
  if (name.isEmpty || isPadded || isReserved || hasUnsafeCharacter) {
    throw StateError(
      '"$name" cannot name a new folder: it is empty, . or .., starts or '
      'ends with a space, or has a folder separator or a control character',
    );
  }
}
