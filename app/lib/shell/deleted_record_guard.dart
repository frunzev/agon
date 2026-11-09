import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/route_records.dart';
import 'package:agent_orchestration/shell/route_screens.dart';
import 'package:agent_orchestration/windows/run_window_opener.dart';

class DeletedRecordGuard extends StatelessWidget {
  const DeletedRecordGuard({
    required this.route,
    required this.dependencies,
    required this.navigation,
    required this.runWindowOpener,
    super.key,
  });

  final AppRoute route;
  final AppDependencies dependencies;
  final AppNavigation navigation;
  final RunWindowOpener? runWindowOpener;

  @override
  Widget build(BuildContext context) {
    final bool isRecordMissing = isRouteRecordMissing(
      route: route,
      dependencies: dependencies,
    );
    final Widget? screen = isRecordMissing
        ? null
        : buildRouteScreen(
            route: route,
            dependencies: dependencies,
            navigation: navigation,
            runWindowOpener: runWindowOpener,
          );

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        dependencies.taskRepository,
        dependencies.jobRepository,
        dependencies.projectRepository,
        dependencies.workflowRepository,
        dependencies.skillRepository,
        dependencies.ruleRepository,
        dependencies.runnerRepository,
        dependencies.deviceRepository,
      ]),
      builder: _showScreenWhileRecordExists,
      child: screen,
    );
  }

  Widget _showScreenWhileRecordExists(BuildContext context, Widget? screen) {
    final bool isRecordMissing = isRouteRecordMissing(
      route: route,
      dependencies: dependencies,
    );
    if (screen == null || isRecordMissing) {
      WidgetsBinding.instance.addPostFrameCallback(_closeMissingRecordPage);
      return const SizedBox.shrink();
    }
    return screen;
  }

  void _closeMissingRecordPage(Duration _) {
    navigation.closeMissingRecordPage(route);
  }
}
