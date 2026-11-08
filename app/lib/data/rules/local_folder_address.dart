import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/control_characters.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

const String localAddressPrefix = 'local:';
const String _deviceSeparator = ':';
const String _unixRoot = '/';
const String _deviceIdProblem = 'This is not a device id';
const String _folderPathProblem =
    'Choose an absolute folder with no control character, empty part, '
    '. or .. part';
const List<String> _folderPathStarts = <String>['/', '\\', '~'];
const List<String> _reservedFolderParts = <String>['.', '..'];
final RegExp _folderSeparators = RegExp(r'[\\/]');
final RegExp _driveRoot = RegExp(r'^[A-Za-z]:[\\/]');
final RegExp _deviceIdText = RegExp(r'^[a-z0-9-]+$');
final RegExp _trailingNoise = RegExp(
  '(?:$unicodeWhiteSpaceCharacter|[\\\\/])+\$',
);

final class LocalFolderAddress {
  const LocalFolderAddress({required this.deviceId, required this.path});

  final DeviceId deviceId;
  final String path;
}

String renderLocalFolderAddress({
  required DeviceId deviceId,
  required String path,
}) {
  if (!_deviceIdText.hasMatch(deviceId.value)) {
    throw ArgumentError.value(deviceId.value, 'deviceId', _deviceIdProblem);
  }
  final String? folderPath = normalizeFolderPath(path);
  if (folderPath == null) {
    throw ArgumentError.value(path, 'path', _folderPathProblem);
  }
  return '$localAddressPrefix${deviceId.value}$_deviceSeparator$folderPath';
}

LocalFolderAddress? parseLocalFolderAddress(String address) {
  if (!address.startsWith(localAddressPrefix)) {
    return null;
  }

  final String deviceAndPath = address.substring(localAddressPrefix.length);
  final int separatorIndex = deviceAndPath.indexOf(_deviceSeparator);
  if (separatorIndex < 0) {
    return null;
  }

  final String deviceText = deviceAndPath.substring(0, separatorIndex);
  final String pathText = deviceAndPath.substring(separatorIndex + 1);
  final String? path = normalizeFolderPath(pathText);
  if (!_deviceIdText.hasMatch(deviceText) || path == null) {
    return null;
  }
  return LocalFolderAddress(deviceId: DeviceId(deviceText), path: path);
}

String? normalizeFolderPath(String path) {
  final String trimmedPath = trimUnicodeWhiteSpace(path);
  final String? root = _findFolderRoot(trimmedPath);
  if (root == null || hasControlCharacter(trimmedPath)) {
    return null;
  }

  final String belowRoot = trimmedPath
      .substring(root.length)
      .replaceFirst(_trailingNoise, '');
  final List<String> parts = belowRoot.split(_folderSeparators);
  if (parts.any(_isUnsafeFolderPart)) {
    return null;
  }
  return '$root$belowRoot';
}

String? _findFolderRoot(String path) {
  if (path.startsWith(_unixRoot)) {
    return _unixRoot;
  }
  return _driveRoot.firstMatch(path)?.group(0);
}

bool isAbsoluteFolderPath(String path) {
  return _findFolderRoot(trimUnicodeWhiteSpace(path)) != null;
}

bool _isUnsafeFolderPart(String part) {
  return part.isEmpty || _reservedFolderParts.contains(part);
}

String describeFolderName(String path) {
  final List<String> namedParts = <String>[
    for (final String part in path.split(_folderSeparators))
      if (part.isNotEmpty) part,
  ];
  if (namedParts.isEmpty) {
    return path;
  }
  return namedParts.last;
}

bool looksLikeFolderPath(String text) {
  final String trimmed = text.trim();
  for (final String start in _folderPathStarts) {
    if (trimmed.startsWith(start)) {
      return true;
    }
  }
  return _driveRoot.hasMatch(trimmed);
}

LocalFolderAddress? findLocalFolder(List<Repository> repositories) {
  for (final Repository repository in repositories) {
    final LocalFolderAddress? folder = parseLocalFolderAddress(
      repository.address,
    );
    if (folder != null) {
      return folder;
    }
  }
  return null;
}
