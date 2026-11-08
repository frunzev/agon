import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/task.dart';

const String nodeBlankTaskTitleProblem = 'the task title cannot be empty';

final Matcher throwsNodeBlankTitleRefusal = throwsA(
  isA<StateError>().having(
    (StateError error) => error.message,
    'message',
    nodeBlankTaskTitleProblem,
  ),
);

TaskDraft replaceDraftTitle(TaskDraft draft, String title) {
  return TaskDraft(
    title: title,
    details: draft.details,
    projectId: draft.projectId,
    doer: draft.doer,
    runsOn: draft.runsOn,
    agentPlace: draft.agentPlace,
    skills: draft.skills,
    usesAutomaticSkills: draft.usesAutomaticSkills,
    approvalPolicy: draft.approvalPolicy,
  );
}
