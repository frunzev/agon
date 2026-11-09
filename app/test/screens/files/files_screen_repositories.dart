import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/repository/file_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

enum FileOperation { open, list, read }

final class FixedProjectRepository extends ChangeNotifier
    implements ProjectRepository {
  FixedProjectRepository(this.project);

  final Project project;

  @override
  List<Project> listProjects(WorkspaceId workspaceId) => <Project>[project];

  @override
  Project findProject(ProjectId projectId) {
    if (projectId != project.id) {
      throw RecordNotFound(kind: 'project', identifier: projectId.value);
    }
    return project;
  }

  @override
  Future<Project> createProject(ProjectDraft draft) {
    throw UnsupportedError('the files pages never create projects');
  }

  @override
  Future<Project> addRepository(ProjectId projectId, Repository repository) {
    throw UnsupportedError('the files pages never add repositories');
  }

  @override
  Future<Project> removeRepository(ProjectId projectId, String address) {
    throw UnsupportedError('the files pages never remove repositories');
  }

  @override
  Future<void> deleteProject(ProjectId projectId) {
    throw UnsupportedError('the files pages never delete projects');
  }
}

final class ScreenFileRepository implements FileRepository {
  ScreenFileRepository(this.answers);

  FileRepository answers;
  final Map<FileOperation, Object> refusals = <FileOperation, Object>{};
  final List<FileOperation> askedOperations = <FileOperation>[];
  final List<DeviceId?> preferredRunners = <DeviceId?>[];
  final List<String> listedFolders = <String>[];
  final List<String> readPaths = <String>[];
  final List<RepositoryBranchLocation> askedLocations =
      <RepositoryBranchLocation>[];
  final List<Completer<void>> heldAnswers = <Completer<void>>[];
  final Set<FileOperation> heldOperations = <FileOperation>{};

  int countAsked(FileOperation operation) {
    int count = 0;
    for (final FileOperation asked in askedOperations) {
      if (asked == operation) {
        count += 1;
      }
    }
    return count;
  }

  void releaseHeldAnswers() {
    heldOperations.clear();
    for (final Completer<void> answer in heldAnswers) {
      answer.complete();
    }
    heldAnswers.clear();
  }

  Future<void> _ask(FileOperation operation) async {
    askedOperations.add(operation);
    if (heldOperations.contains(operation)) {
      final Completer<void> answer = Completer<void>();
      heldAnswers.add(answer);
      await answer.future;
    }
    final Object? refusal = refusals[operation];
    if (refusal is Error) {
      throw refusal;
    }
    if (refusal is Exception) {
      throw refusal;
    }
  }

  @override
  Future<RepositoryFileSource> openRepository({
    required ProjectId projectId,
    required String repositoryAddress,
    required DeviceId? preferredRunnerId,
  }) async {
    preferredRunners.add(preferredRunnerId);
    await _ask(FileOperation.open);
    return answers.openRepository(
      projectId: projectId,
      repositoryAddress: repositoryAddress,
      preferredRunnerId: preferredRunnerId,
    );
  }

  @override
  Future<List<RepositoryEntry>> listFolder({
    required RepositoryBranchLocation location,
    required String folder,
  }) async {
    listedFolders.add(folder);
    askedLocations.add(location);
    await _ask(FileOperation.list);
    return answers.listFolder(location: location, folder: folder);
  }

  @override
  Future<RepositoryFile> readFile({
    required RepositoryBranchLocation location,
    required String path,
  }) async {
    readPaths.add(path);
    askedLocations.add(location);
    await _ask(FileOperation.read);
    return answers.readFile(location: location, path: path);
  }
}
