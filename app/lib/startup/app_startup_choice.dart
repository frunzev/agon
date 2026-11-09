import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/startup/node_app_start.dart';
import 'package:agent_orchestration/startup/node_startup.dart';

const String galleryAppData = 'gallery';

NodeStartup chooseStartup({required String appDataChoice}) {
  if (appDataChoice == galleryAppData) {
    return NodeStartup(
      startApp: startGallery,
      startAppAsNewDevice: startGallery,
    );
  }
  return NodeStartup(
    startApp: startNodeApp,
    startAppAsNewDevice: startNodeAppAsNewDevice,
  );
}

Future<StartedApp> startGallery() async {
  return StartedApp(
    dependencies: buildGalleryDependencies(),
    navigation: AppNavigation(
      initialRoute: const SectionRoute(AppSection.tasks),
    ),
  );
}
