import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';

String describeProjectName({
  required ProjectRepository projectRepository,
  required ProjectId projectId,
}) {
  try {
    return projectRepository.findProject(projectId).name;
  } on RecordNotFound {
    return shortenIdentifier(projectId.value);
  }
}
