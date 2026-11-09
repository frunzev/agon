import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/deleted_record_guard.dart';
import 'package:agent_orchestration/shell/rising_page.dart';
import 'package:agent_orchestration/shell/route_pages.dart';

import '../support/random_inputs.dart';
import 'route_record_samples.dart';

const int _largestStackDepth = 5;

List<AppRoute> _randomRoutes(Random random, AppDependencies dependencies) {
  final List<AppRoute> routes = <AppRoute>[
    pickOne(random, listPagesWithoutRecords(random)),
  ];
  final int depth = random.nextInt(_largestStackDepth);
  for (int i = 0; i < depth; i += 1) {
    routes.add(sampleRecordRoute(random, dependencies).route);
  }
  return routes;
}

DeletedRecordGuard _readGuard(Page<Object?> page) {
  final RisingPage risingPage = page as RisingPage;
  return risingPage.child as DeletedRecordGuard;
}

void main() {
  final AppDependencies dependencies = buildGalleryDependencies();

  test('test_build_route_pages_property_every_page_is_guarded_for_its_'
      'route', () {
    final Random random = seededRandom(5311201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AppRoute> routes = _randomRoutes(random, dependencies);
      final AppNavigation navigation = AppNavigation(
        initialRoute: routes.first,
      );

      final List<Page<Object?>> pages = buildRoutePages(
        routes: routes,
        dependencies: dependencies,
        navigation: navigation,
        runWindowOpener: null,
      );

      expect(pages, hasLength(routes.length));
      for (int index = 0; index < routes.length; index += 1) {
        final DeletedRecordGuard guard = _readGuard(pages[index]);
        expect(guard.route, routes[index]);
        expect(guard.navigation, same(navigation));
        expect(guard.dependencies, same(dependencies));
      }
    }
  });

  test('test_build_route_pages_property_building_never_looks_records_up', () {
    final Random random = seededRandom(5311202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AppRoute> routes = _randomRoutes(random, dependencies);

      expect(
        () => buildRoutePages(
          routes: routes,
          dependencies: dependencies,
          navigation: AppNavigation(initialRoute: routes.first),
          runWindowOpener: null,
        ),
        returnsNormally,
        reason: '$routes',
      );
    }
  });

  test('test_build_route_pages_property_keys_follow_position_and_route', () {
    final Random random = seededRandom(5311203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AppRoute> routes = _randomRoutes(random, dependencies);

      final List<Page<Object?>> pages = buildRoutePages(
        routes: routes,
        dependencies: dependencies,
        navigation: AppNavigation(initialRoute: routes.first),
        runWindowOpener: null,
      );

      for (int index = 0; index < routes.length; index += 1) {
        expect(
          pages[index].key,
          ValueKey<(int, AppRoute)>((index, routes[index])),
        );
      }
    }
  });
}
