import 'dart:convert';

import '../../../bridge/support/scripted_node_transport.dart';

const String _pathSeparator = '/';
const String _currentFolder = '.';
const String _parentFolder = '..';
const String _foreignSeparator = '\\';
const String _folderKind = 'folder';
const String _fileKind = 'file';
final RegExp _controlCharacter = RegExp(r'[\u0000-\u001F\u007F-\u009F]');

final class RustFileRefusal implements Exception {
  const RustFileRefusal(this.message);

  final String message;
}

typedef ModelFile = ({String address, String path, int size, Object? preview});

typedef _ModelEntry = ({String name, String kind, int? size});

final class RustRepositoryFilesModel {
  RustRepositoryFilesModel({required this.files, required this.branchViews});

  final List<ModelFile> files;
  final Map<String, Map<String, Object?>> branchViews;

  String answer(String inputJson) {
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    final String address = command['repository_address']! as String;
    try {
      return encodeSuccessReply(switch (command['command']) {
        'list_repository_branches' => _openRepository(address),
        'list_repository_files' => _listFolder(
          address,
          command['folder']! as String,
        ),
        'read_repository_file' => _readFile(
          address,
          command['path']! as String,
        ),
        _ => throw FormatException('unknown command ${command['command']}'),
      });
    } on RustFileRefusal catch (refusal) {
      return encodeErrorReply(refusal.message);
    }
  }

  Map<String, Object?> _openRepository(String address) {
    final Map<String, Object?>? view = branchViews[address];
    if (view == null) {
      return <String, Object?>{'kind': 'unavailable', 'holders': <Object?>[]};
    }
    return view;
  }

  Map<String, Object?> _listFolder(String address, String folder) {
    final String normalized = normalizeRepositoryFolderPath(folder);
    final bool isTree =
        normalized.isEmpty || _hasFilesBelow(address, normalized);
    if (!isTree) {
      throw RustFileRefusal('the folder $normalized is not a folder');
    }
    final List<_ModelEntry> entries = _readTree(address, normalized);
    entries.sort(_compareEntries);
    return <String, Object?>{
      'entries': <Object?>[
        for (final _ModelEntry entry in entries)
          <String, Object?>{
            'name': entry.name,
            'kind': entry.kind,
            'size': entry.size,
          },
      ],
    };
  }

  Map<String, Object?> _readFile(String address, String path) {
    final String normalized = normalizeRepositoryFolderPath(path);
    if (normalized.isEmpty) {
      throw const RustFileRefusal('the file path cannot be empty');
    }
    for (final ModelFile file in files) {
      if (file.address == address && file.path == normalized) {
        return <String, Object?>{
          'path': normalized,
          'size': file.size,
          'preview': file.preview,
        };
      }
    }
    throw RustFileRefusal('the file $normalized does not exist');
  }

  bool _hasFilesBelow(String address, String folder) {
    for (final ModelFile file in files) {
      if (file.address == address && file.path.startsWith('$folder/')) {
        return true;
      }
    }
    return false;
  }

  List<_ModelEntry> _readTree(String address, String folder) {
    final String prefix = folder.isEmpty ? '' : '$folder$_pathSeparator';
    final Map<String, _ModelEntry> entries = <String, _ModelEntry>{};
    for (final ModelFile file in files) {
      if (file.address != address || !file.path.startsWith(prefix)) {
        continue;
      }
      final String rest = file.path.substring(prefix.length);
      final int separatorIndex = rest.indexOf(_pathSeparator);
      final _ModelEntry entry = separatorIndex < 0
          ? (name: rest, kind: _fileKind, size: file.size)
          : (
              name: rest.substring(0, separatorIndex),
              kind: _folderKind,
              size: null,
            );
      if (_isAddressableName(entry.name)) {
        entries[entry.name] = entry;
      }
    }
    return entries.values.toList();
  }
}

String normalizeRepositoryFolderPath(String path) {
  if (path.startsWith(_pathSeparator)) {
    throw RustFileRefusal('the path $path is absolute');
  }
  if (path.contains(_foreignSeparator) || path.contains(_controlCharacter)) {
    throw RustFileRefusal(
      'the path $path holds a character paths cannot hold',
    );
  }

  final List<String> keptParts = <String>[];
  for (final String part in path.split(_pathSeparator)) {
    if (part == _parentFolder) {
      throw RustFileRefusal('the path $path leaves the repository');
    }
    if (part.isNotEmpty && part != _currentFolder) {
      keptParts.add(part);
    }
  }
  return keptParts.join(_pathSeparator);
}

bool _isAddressableName(String name) {
  final bool isReserved =
      name.isEmpty || name == _currentFolder || name == _parentFolder;
  final bool hasForbiddenCharacter =
      name.contains(_foreignSeparator) || name.contains(_controlCharacter);
  return !isReserved && !hasForbiddenCharacter;
}

int _compareEntries(_ModelEntry first, _ModelEntry second) {
  final bool isFirstFolder = first.kind == _folderKind;
  final bool isSecondFolder = second.kind == _folderKind;
  if (isFirstFolder != isSecondFolder) {
    return isFirstFolder ? -1 : 1;
  }
  final int ignoringCase = _compareCodePoints(
    first.name.toLowerCase(),
    second.name.toLowerCase(),
  );
  if (ignoringCase != 0) {
    return ignoringCase;
  }
  return _compareCodePoints(first.name, second.name);
}

int _compareCodePoints(String first, String second) {
  final List<int> firstCodePoints = first.runes.toList();
  final List<int> secondCodePoints = second.runes.toList();
  final int sharedLength = firstCodePoints.length < secondCodePoints.length
      ? firstCodePoints.length
      : secondCodePoints.length;
  for (int i = 0; i < sharedLength; i += 1) {
    final int difference = firstCodePoints[i] - secondCodePoints[i];
    if (difference != 0) {
      return difference;
    }
  }
  return firstCodePoints.length - secondCodePoints.length;
}
