import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/repository/file_repository.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';

final class FileTreeController extends ChangeNotifier {
  FileTreeController({required this.fileRepository, required this.location});

  final FileRepository fileRepository;
  final RepositoryBranchLocation location;
  final Map<String, List<RepositoryEntry>> _folderEntries =
      <String, List<RepositoryEntry>>{};
  final Map<String, Future<void>> _pendingLoads = <String, Future<void>>{};
  final Set<String> _expandedFolders = <String>{};
  String? _problem;
  bool _isDisposed = false;

  String? get problem => _problem;

  List<RepositoryEntry>? entriesOf(String folder) => _folderEntries[folder];

  bool isExpanded(String folder) => _expandedFolders.contains(folder);

  Future<void> revealFolders(List<String> folders) async {
    for (final String folder in folders) {
      if (_isDisposed) {
        return;
      }
      await _expandFolder(folder);
    }
  }

  Future<void> toggleFolder(String folder) async {
    if (_expandedFolders.remove(folder)) {
      notifyListeners();
      return;
    }
    await _expandFolder(folder);
  }

  Future<void> _expandFolder(String folder) async {
    _expandedFolders.add(folder);
    notifyListeners();
    if (_folderEntries.containsKey(folder)) {
      return;
    }

    final Future<void> load = _pendingLoads.putIfAbsent(
      folder,
      () => _loadFolder(folder),
    );
    try {
      await load;
    } finally {
      unawaited(_pendingLoads.remove(folder));
    }
  }

  Future<void> _loadFolder(String folder) async {
    try {
      _folderEntries[folder] = await fileRepository.listFolder(
        location: location,
        folder: folder,
      );
      _problem = null;
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      _expandedFolders.remove(folder);
      _problem = explanation;
    }
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
