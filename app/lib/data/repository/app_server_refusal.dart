import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';

final class AppServerRefusal extends PeopleFacingRefusal {
  AppServerRefusal({required this.status, required String reason})
    : super(reason);

  final int status;

  @override
  String toString() => 'the app server answered $status: $message';
}
