import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';

final class HostingProblem extends PeopleFacingRefusal {
  HostingProblem(super.message, {required this.kind});

  final node.HostingProblemKind? kind;
}

bool isDamagedDeviceRecordProblem(Object problem) {
  if (problem is! HostingProblem) {
    return false;
  }
  return problem.kind == node.HostingProblemKind.recordDamaged;
}
