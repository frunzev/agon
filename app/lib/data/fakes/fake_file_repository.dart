import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/repository/file_repository.dart';
import 'package:agent_orchestration/data/rules/code_point_order.dart';
import 'package:agent_orchestration/data/rules/control_characters.dart';

const String _pathSeparator = '/';
const String _rootFolder = '';
const String _currentFolder = '.';
const String _parentFolder = '..';
const String _foreignSeparator = '\\';

final class FakeRepositoryFile {
  const FakeRepositoryFile({
    required this.repositoryAddress,
    required this.path,
    required this.size,
    required this.preview,
  });

  final String repositoryAddress;
  final String path;
  final int size;
  final FilePreview preview;
}

final class FakeFileRepository implements FileRepository {
  FakeFileRepository({
    required Map<String, RepositoryFileSource> sources,
    required List<FakeRepositoryFile> files,
  }) : _sources = Map<String, RepositoryFileSource>.unmodifiable(sources),
       _files = List<FakeRepositoryFile>.unmodifiable(files);

  final Map<String, RepositoryFileSource> _sources;
  final List<FakeRepositoryFile> _files;

  @override
  Future<RepositoryFileSource> openRepository({
    required ProjectId projectId,
    required String repositoryAddress,
    required DeviceId? preferredRunnerId,
  }) async {
    final RepositoryFileSource? source = _sources[repositoryAddress];
    if (source == null) {
      return FilesWithoutRunner(holders: const <RepositoryHolder>[]);
    }
    return source;
  }

  @override
  Future<List<RepositoryEntry>> listFolder({
    required RepositoryBranchLocation location,
    required String folder,
  }) async {
    final String normalizedFolder = _normalizeRepositoryPath(folder);
    final String prefix = normalizedFolder == _rootFolder
        ? _rootFolder
        : '$normalizedFolder$_pathSeparator';
    final Map<String, RepositoryEntry> folders = <String, RepositoryEntry>{};
    final List<RepositoryEntry> files = <RepositoryEntry>[];
    bool isFound = false;

    for (final FakeRepositoryFile file in _files) {
      final bool isInside =
          file.repositoryAddress == location.repositoryAddress &&
          file.path.startsWith(prefix);
      if (!isInside) {
        continue;
      }
      isFound = true;
      final String rest = file.path.substring(prefix.length);
      final int separatorIndex = rest.indexOf(_pathSeparator);
      final bool isFile = separatorIndex < 0;
      final String name = isFile ? rest : rest.substring(0, separatorIndex);
      if (!_isAddressableName(name)) {
        continue;
      }
      if (isFile) {
        files.add(_describeFile(name, file.size));
      } else {
        folders[name] = _describeFolder(name);
      }
    }

    if (normalizedFolder != _rootFolder && !isFound) {
      throw StateError('the folder $folder does not exist');
    }
    return List<RepositoryEntry>.unmodifiable(<RepositoryEntry>[
      ..._sortByName(folders.values.toList()),
      ..._sortByName(files),
    ]);
  }

  @override
  Future<RepositoryFile> readFile({
    required RepositoryBranchLocation location,
    required String path,
  }) async {
    final String normalizedPath = _normalizeRepositoryPath(path);
    for (final FakeRepositoryFile file in _files) {
      final bool isRequested =
          file.repositoryAddress == location.repositoryAddress &&
          file.path == normalizedPath;
      if (isRequested) {
        return RepositoryFile(
          path: file.path,
          size: file.size,
          preview: file.preview,
        );
      }
    }
    throw StateError('the file $path does not exist');
  }
}

RepositoryEntry _describeFile(String name, int size) {
  return RepositoryEntry(
    name: name,
    kind: RepositoryEntryKind.file,
    size: size,
  );
}

RepositoryEntry _describeFolder(String name) {
  return RepositoryEntry(
    name: name,
    kind: RepositoryEntryKind.folder,
    size: null,
  );
}

List<RepositoryEntry> _sortByName(List<RepositoryEntry> entries) {
  final List<RepositoryEntry> sorted = List<RepositoryEntry>.of(entries);
  sorted.sort(_compareNames);
  return sorted;
}

int _compareNames(RepositoryEntry first, RepositoryEntry second) {
  final int ignoringCase = compareCodePoints(
    first.name.toLowerCase(),
    second.name.toLowerCase(),
  );
  if (ignoringCase != 0) {
    return ignoringCase;
  }
  return compareCodePoints(first.name, second.name);
}

bool _isAddressableName(String name) {
  final bool isReserved =
      name.isEmpty || name == _currentFolder || name == _parentFolder;
  final bool hasForbiddenCharacter =
      name.contains(_foreignSeparator) || hasControlCharacter(name);
  return !isReserved && !hasForbiddenCharacter;
}

String _normalizeRepositoryPath(String path) {
  final bool isAbsolute = path.startsWith(_pathSeparator);
  final bool hasForbiddenCharacter =
      path.contains(_foreignSeparator) || hasControlCharacter(path);
  if (isAbsolute || hasForbiddenCharacter) {
    throw StateError('the path $path cannot name a place in the repository');
  }

  final List<String> keptParts = <String>[];
  for (final String part in path.split(_pathSeparator)) {
    if (part == _parentFolder) {
      throw StateError('the path $path leaves the repository');
    }
    if (part.isNotEmpty && part != _currentFolder) {
      keptParts.add(part);
    }
  }
  return keptParts.join(_pathSeparator);
}
