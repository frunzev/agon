import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/screens/projects/repository_entry.dart';

final class ProjectRepositoriesEditor extends ChangeNotifier {
  ProjectRepositoriesEditor({
    required List<RepositoryDraft> initialRepositories,
    required DeviceRepository deviceRepository,
    required FolderPicker? folderPicker,
    required ValueChanged<RepositoryDraft> onFirstRepositoryKept,
  }) : _repositories = List<RepositoryDraft>.unmodifiable(initialRepositories),
       _deviceRepository = deviceRepository,
       _folderPicker = folderPicker,
       _onFirstRepositoryKept = onFirstRepositoryKept;

  final DeviceRepository _deviceRepository;
  final FolderPicker? _folderPicker;
  final ValueChanged<RepositoryDraft> _onFirstRepositoryKept;
  final TextEditingController addressController = TextEditingController();
  List<RepositoryDraft> _repositories;
  Set<String> _gitStartedAddresses = const <String>{};
  String? _addressProblem;
  String? _newFolderParent;
  bool _isDisposed = false;

  List<RepositoryDraft> get repositories => _repositories;

  Set<String> get gitStartedAddresses => _gitStartedAddresses;

  String? get addressProblem => _addressProblem;

  String? get newFolderParent => _newFolderParent;

  bool get hasNoRepository =>
      _repositories.isEmpty && _newFolderParent == null;

  @override
  void dispose() {
    _isDisposed = true;
    addressController.dispose();
    super.dispose();
  }

  void showAddressProblem(String? problem) {
    _addressProblem = problem;
    notifyListeners();
  }

  Future<void> addTypedRepository() async {
    final RepositoryEntry entry = await readTypedRepository(
      text: addressController.text,
      checkFolder: _folderPicker == null
          ? null
          : _deviceRepository.checkLocalFolder,
      listAddedAddresses: _listAddedAddresses,
    );
    _keepEntry(entry);
  }

  Future<void> chooseFolder(FolderPicker folderPicker) async {
    final String? path = await folderPicker.chooseFolder();
    if (path == null || _isDisposed) {
      return;
    }
    await _addFolder(_deviceRepository.checkLocalFolder(path));
  }

  Future<void> chooseNewFolderPlace(FolderPicker folderPicker) async {
    final String? parent = await folderPicker.chooseFolder();
    if (parent == null || _isDisposed) {
      return;
    }
    planNewFolder(parent);
  }

  void planNewFolder(String parent) {
    _newFolderParent = parent;
    notifyListeners();
  }

  void dropNewFolder() {
    _newFolderParent = null;
    notifyListeners();
  }

  Future<bool> createNewFolder(String name) async {
    final String? parent = _newFolderParent;
    if (parent == null) {
      return true;
    }

    final int keptCount = _repositories.length;
    await _addFolder(
      _deviceRepository.createLocalFolder(parent: parent, name: name),
    );
    final bool isCreated = _repositories.length > keptCount;
    if (isCreated) {
      dropNewFolder();
    }
    return isCreated;
  }

  void removeRepository(String address) {
    _repositories = List<RepositoryDraft>.unmodifiable(
      _repositories.where(
        (RepositoryDraft repository) => repository.address != address,
      ),
    );
    notifyListeners();
  }

  List<String> _listAddedAddresses() {
    return <String>[
      for (final RepositoryDraft repository in _repositories)
        repository.address,
    ];
  }

  Future<void> _addFolder(Future<CheckedFolder> folderAnswer) async {
    final RepositoryEntry entry = await readCheckedFolder(
      folderAnswer: folderAnswer,
      listAddedAddresses: _listAddedAddresses,
    );
    _keepEntry(entry);
  }

  void _keepEntry(RepositoryEntry entry) {
    if (_isDisposed) {
      return;
    }
    switch (entry) {
      case RefusedRepository(:final String problem):
        showAddressProblem(problem);
      case AcceptedRepository(
        :final RepositoryDraft repository,
        :final bool hasStartedGit,
      ):
        if (hasStartedGit) {
          _gitStartedAddresses = Set<String>.unmodifiable(<String>{
            ..._gitStartedAddresses,
            repository.address,
          });
        }
        _keepRepository(repository);
    }
  }

  void _keepRepository(RepositoryDraft repository) {
    addressController.clear();
    if (_repositories.isEmpty) {
      _onFirstRepositoryKept(repository);
    }
    _repositories = List<RepositoryDraft>.unmodifiable(<RepositoryDraft>[
      ..._repositories,
      repository,
    ]);
    _addressProblem = null;
    notifyListeners();
  }
}
