import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

const String blankTaskTitleProblem = 'the task title cannot be empty';

void requireTaskTitle(String title) {
  if (trimUnicodeWhiteSpace(title).isEmpty) {
    throw PeopleFacingRefusal(blankTaskTitleProblem);
  }
}
