import 'dart:convert';

import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

import '../../../bridge/support/scripted_node_transport.dart';

const String _unixRoot = '/';
const String _driveSeparator = ':';
const int _driveRootLength = 3;
const List<String> _folderSeparators = <String>['/', '\\'];
const List<String> _reservedParts = <String>['.', '..'];
const String _checkedOutBranch = 'main';
final RegExp _controlCharacter = RegExp(r'[\u0000-\u001F\u007F-\u009F]');
final RegExp _driveLetter = RegExp(r'^[A-Za-z]$');
final RegExp _trailingNoise = RegExp(
  r'[\\/\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A'
  r'\u2028\u2029\u202F\u205F\u3000]+$',
);
final RegExp _separatorPattern = RegExp(r'[\\/]');

final class RustFolderRefusal implements Exception {
  const RustFolderRefusal(this.message);

  final String message;
}

final class RustLocalFolderModel {
  RustLocalFolderModel({
    required this.deviceId,
    required Set<String> gitlessFolderPaths,
  }) : _gitlessFolderPaths = Set<String>.of(gitlessFolderPaths);

  final String deviceId;
  final Set<String> _gitlessFolderPaths;
  final Set<String> _createdFolderPaths = <String>{};

  String? answer(String inputJson) {
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    try {
      return switch (command['command']) {
        'check_local_folder' => encodeSuccessReply(
          checkFolder(command['path']! as String),
        ),
        'create_local_folder' => encodeSuccessReply(
          createFolder(
            parent: command['parent']! as String,
            name: command['name']! as String,
          ),
        ),
        _ => null,
      };
    } on RustFolderRefusal catch (refusal) {
      return encodeErrorReply(refusal.message);
    }
  }

  Map<String, Object?> checkFolder(String path) {
    final String folderPath = normalizeRustFolderPath(path);
    final bool hasStartedGit = _gitlessFolderPaths.remove(folderPath);
    return <String, Object?>{
      'address': 'local:$deviceId:$folderPath',
      'default_branch': _checkedOutBranch,
      'has_started_git': hasStartedGit,
    };
  }

  Map<String, Object?> createFolder({
    required String parent,
    required String name,
  }) {
    _validateNewFolderName(name);
    final String parentPath = normalizeRustFolderPath(parent);
    final String folderPath = '$parentPath$_unixRoot$name';
    if (!_createdFolderPaths.add(folderPath)) {
      throw RustFolderRefusal('the folder $folderPath already exists');
    }
    _gitlessFolderPaths.add(normalizeRustFolderPath(folderPath));
    return checkFolder(folderPath);
  }
}

String normalizeRustFolderPath(String path) {
  final String trimmed = trimUnicodeWhiteSpace(path);
  if (trimmed.isEmpty) {
    throw const RustFolderRefusal('the folder path is empty');
  }
  if (trimmed.contains(_controlCharacter)) {
    throw RustFolderRefusal('the folder "$trimmed" is unsafe');
  }

  final String? root = _findRoot(trimmed);
  if (root == null) {
    throw RustFolderRefusal('the folder "$trimmed" is not an absolute path');
  }
  final String partsText = trimmed
      .substring(root.length)
      .replaceFirst(_trailingNoise, '');
  for (final String part in partsText.split(_separatorPattern)) {
    if (part.isEmpty || _reservedParts.contains(part)) {
      throw RustFolderRefusal('the folder "$trimmed" is unsafe');
    }
  }
  return '$root$partsText';
}

String? _findRoot(String path) {
  if (path.startsWith(_unixRoot)) {
    return _unixRoot;
  }
  if (path.length < _driveRootLength) {
    return null;
  }
  final String root = path.substring(0, _driveRootLength);
  final bool isDriveRoot =
      _driveLetter.hasMatch(root[0]) &&
      root[1] == _driveSeparator &&
      _folderSeparators.contains(root[2]);
  if (!isDriveRoot) {
    return null;
  }
  return root;
}

void _validateNewFolderName(String name) {
  final bool isPadded = trimUnicodeWhiteSpace(name) != name;
  final bool isReserved = _reservedParts.contains(name);
  final bool hasUnsafeCharacter =
      name.contains(_controlCharacter) || name.contains(_separatorPattern);
  if (name.isEmpty || isPadded || isReserved || hasUnsafeCharacter) {
    throw RustFolderRefusal('"$name" cannot name a new folder');
  }
}
