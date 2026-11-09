import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/repository_address.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/projects/agent_access_choices.dart';
import 'package:agent_orchestration/screens/projects/project_text.dart';

typedef FolderCheck = Future<CheckedFolder> Function(String path);

typedef AddedAddressesReader = List<String> Function();

sealed class RepositoryEntry {
  const RepositoryEntry();
}

final class AcceptedRepository extends RepositoryEntry {
  const AcceptedRepository({
    required this.repository,
    required this.hasStartedGit,
  });

  final RepositoryDraft repository;
  final bool hasStartedGit;
}

final class RefusedRepository extends RepositoryEntry {
  const RefusedRepository(this.problem);

  final String problem;
}

Future<RepositoryEntry> readTypedRepository({
  required String text,
  required FolderCheck? checkFolder,
  required AddedAddressesReader listAddedAddresses,
}) async {
  if (checkFolder != null && looksLikeFolderPath(text)) {
    return readCheckedFolder(
      folderAnswer: checkFolder(text),
      listAddedAddresses: listAddedAddresses,
    );
  }

  final String? problem = describeRepositoryEntryProblem(
    text: text,
    addedAddresses: listAddedAddresses(),
  );
  if (problem != null) {
    return RefusedRepository(problem);
  }
  return AcceptedRepository(
    repository: RepositoryDraft(
      address: parseRepositoryAddress(text)!,
      defaultBranch: defaultRepositoryBranch,
    ),
    hasStartedGit: false,
  );
}

Future<RepositoryEntry> readCheckedFolder({
  required Future<CheckedFolder> folderAnswer,
  required AddedAddressesReader listAddedAddresses,
}) async {
  final CheckedFolder checked;
  try {
    checked = await folderAnswer;
  } on Object catch (problem) {
    final String? explanation = describeProblemForPeople(problem);
    if (explanation == null) {
      rethrow;
    }
    return RefusedRepository(explanation);
  }

  final RepositoryDraft repository = checked.repository;
  if (listAddedAddresses().contains(repository.address)) {
    return const RefusedRepository(repositoryAlreadyAddedProblem);
  }
  return AcceptedRepository(
    repository: repository,
    hasStartedGit: checked.hasStartedGit,
  );
}
