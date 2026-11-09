import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';

const String createdTaskNotStartedPrefix =
    'The task was created but could not start: ';

Future<Run> startCreatedTask({
  required TaskRepository taskRepository,
  required TaskId taskId,
}) async {
  try {
    return await taskRepository.startTask(taskId);
  } on Object catch (problem) {
    final String? explanation = describeProblemForPeople(problem);
    if (explanation == null) {
      rethrow;
    }
    throw PeopleFacingRefusal('$createdTaskNotStartedPrefix$explanation');
  }
}
