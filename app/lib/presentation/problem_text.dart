import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

String? describeProblemForPeople(Object problem) {
  if (problem is RecordNotFound) {
    return problem.toString();
  }
  if (problem is! PeopleFacingRefusal) {
    return null;
  }

  final String message = problem.message;
  final bool isBlank = trimUnicodeWhiteSpace(message).isEmpty;
  if (isBlank) {
    return null;
  }
  return message;
}
