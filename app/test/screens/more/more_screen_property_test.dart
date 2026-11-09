import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/screens/more/more_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';

import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';

typedef _DesignRow = ({String title, String subtitle, AppRoute? route});

const AppRoute _moreRoute = SectionRoute(AppSection.more);
const List<_DesignRow> _designRows = <_DesignRow>[
  (
    title: 'Workflows',
    subtitle: 'Reusable chains of agents',
    route: SectionRoute(AppSection.workflows),
  ),
  (
    title: 'Skills',
    subtitle: 'Instructions agents can follow',
    route: SectionRoute(AppSection.skills),
  ),
  (
    title: 'Rules',
    subtitle: 'What every agent must follow',
    route: SectionRoute(AppSection.rules),
  ),
  (
    title: 'Devices',
    subtitle: 'Runners, servers and pairing',
    route: SectionRoute(AppSection.devices),
  ),
  (
    title: 'Settings',
    subtitle: 'App server, commands, audit log',
    route: SectionRoute(AppSection.settings),
  ),
  (title: 'Switch workspace', subtitle: '', route: WorkspaceSwitcherRoute()),
];

Finder _findShown(String text) => find.text(text, findRichText: true);

String _describeCurrentWorkspace(WorkspaceRepository repository) {
  return 'Now in ${repository.currentWorkspace().name}';
}

Future<void> _switchToNewWorkspace(
  WorkspaceRepository repository,
  int round,
) async {
  final Workspace created = await repository.createWorkspace(
    name: 'team-$round',
  );
  await repository.switchWorkspace(created.id);
}

MoreScreen _buildScreen(
  AppDependencies dependencies,
  AppNavigation navigation,
) {
  return MoreScreen(
    workspaceRepository: dependencies.workspaceRepository,
    navigation: navigation,
  );
}

void main() {
  test('test_more_screen_constructor_property_keeps_every_field', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = AppNavigation(initialRoute: _moreRoute);

    final MoreScreen screen = _buildScreen(dependencies, navigation);

    expect(screen.workspaceRepository, same(dependencies.workspaceRepository));
    expect(screen.navigation, same(navigation));
  });

  test('test_more_screen_constructor_property_no_key_unless_given', () {
    final Random random = seededRandom(1021401);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(99));
      final AppNavigation navigation = AppNavigation(initialRoute: _moreRoute);

      expect(_buildScreen(dependencies, navigation).key, isNull);
      expect(
        MoreScreen(
          workspaceRepository: dependencies.workspaceRepository,
          navigation: navigation,
          key: key,
        ).key,
        key,
      );
    }
  });

  testWidgets('test_more_screen_build_property_rows_follow_the_design', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1021402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildScreen(
          dependencies,
          AppNavigation(initialRoute: _moreRoute),
        ),
      );

      expect(tester.takeException(), isNull);
      double previousTop = double.negativeInfinity;
      for (final _DesignRow row in _designRows) {
        final double top = tester.getTopLeft(_findShown(row.title)).dy;
        expect(top, greaterThan(previousTop), reason: row.title);
        previousTop = top;
        if (row.subtitle.isNotEmpty) {
          expect(_findShown(row.subtitle), findsOneWidget);
        }
      }
    }
  });

  testWidgets('test_more_screen_build_property_follows_the_workspace', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1021403);
    final AppDependencies dependencies = buildGalleryDependencies();
    final WorkspaceRepository repository = dependencies.workspaceRepository;
    await pumpPageInRandomWindow(
      tester,
      random: random,
      page: _buildScreen(
        dependencies,
        AppNavigation(initialRoute: _moreRoute),
      ),
    );

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String before = _describeCurrentWorkspace(repository);
      await _switchToNewWorkspace(repository, i);
      await tester.pump();

      expect(_findShown(_describeCurrentWorkspace(repository)), findsOne);
      expect(_findShown(before), findsNothing);
    }
  });

  testWidgets('test_more_screen_build_page_property_one_header_six_rows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1021404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildScreen(
          dependencies,
          AppNavigation(initialRoute: _moreRoute),
        ),
      );

      expect(find.text('More'), findsOneWidget);
      expect(find.byType(RowAction), findsNWidgets(_designRows.length));
      expect(find.byType(ListRowMain), findsNWidgets(_designRows.length));
    }
  });

  testWidgets('test_more_screen_build_page_property_names_the_current_'
      'workspace', (WidgetTester tester) async {
    final Random random = seededRandom(1021405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final WorkspaceRepository repository = dependencies.workspaceRepository;
      if (random.nextBool()) {
        await _switchToNewWorkspace(repository, i);
      }
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildScreen(
          dependencies,
          AppNavigation(initialRoute: _moreRoute),
        ),
      );

      expect(_findShown(_describeCurrentWorkspace(repository)), findsOne);
    }
  });

  testWidgets('test_more_screen_build_row_property_each_tap_opens_its_'
      'route', (WidgetTester tester) async {
    final Random random = seededRandom(1021406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = AppNavigation(initialRoute: _moreRoute);
      final _DesignRow row = pickOne(random, _designRows);
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildScreen(buildGalleryDependencies(), navigation),
      );

      await tapShownText(tester, row.title);

      expect(navigation.routes, <AppRoute?>[_moreRoute, row.route]);
    }
  });

  testWidgets('test_more_screen_build_row_property_taps_stack_in_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1021407);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = AppNavigation(initialRoute: _moreRoute);
      final List<_DesignRow> tapped = <_DesignRow>[
        for (int tap = 0; tap < random.nextInt(4); tap += 1)
          pickOne(random, _designRows),
      ];
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildScreen(buildGalleryDependencies(), navigation),
      );

      for (final _DesignRow row in tapped) {
        await tapShownText(tester, row.title);
      }

      final List<AppRoute?> expectedRoutes = <AppRoute?>[_moreRoute];
      for (final _DesignRow row in tapped) {
        if (row.route != expectedRoutes.last) {
          expectedRoutes.add(row.route);
        }
      }
      expect(navigation.routes, expectedRoutes);
    }
  });

  testWidgets('test_more_screen_build_row_property_subtitle_sits_under_'
      'its_title', (WidgetTester tester) async {
    final Random random = seededRandom(1021408);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildScreen(
          dependencies,
          AppNavigation(initialRoute: _moreRoute),
        ),
      );

      for (final _DesignRow row in _designRows) {
        final String subtitle = row.subtitle.isEmpty
            ? _describeCurrentWorkspace(dependencies.workspaceRepository)
            : row.subtitle;
        final Rect title = tester.getRect(_findShown(row.title));
        final Rect shownSubtitle = tester.getRect(_findShown(subtitle));
        expect(shownSubtitle.top, greaterThanOrEqualTo(title.bottom));
        expect(shownSubtitle.left, closeTo(title.left, 1));
      }
    }
  });
}
