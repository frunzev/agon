import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;

final class HostingProblem extends StateError {
  HostingProblem(super.message, {required this.kind});

  final node.HostingProblemKind? kind;
}

bool isDamagedHostedRecordProblem(Object problem) {
  if (problem is! HostingProblem) {
    return false;
  }
  return problem.kind == node.HostingProblemKind.recordDamaged;
}
