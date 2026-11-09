import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/screens/more/more_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';

const AppRoute _moreRoute = SectionRoute(AppSection.more);
const String _pageTitle = 'More';
const String _firstRowTitle = 'Workflows';

MoreScreen _buildScreen(AppDependencies dependencies) {
  return MoreScreen(
    workspaceRepository: dependencies.workspaceRepository,
    navigation: AppNavigation(initialRoute: _moreRoute),
  );
}

Future<Workspace> _switchToWorkspaceNamed(
  AppDependencies dependencies,
  String name,
) async {
  final Workspace created = await dependencies.workspaceRepository
      .createWorkspace(name: name);
  return dependencies.workspaceRepository.switchWorkspace(created.id);
}

String _randomLongName(Random random) {
  final StringBuffer name = StringBuffer('w');
  final int length = 1 + random.nextInt(nameMaximumLength - 1);
  for (int index = 1; index < length; index += 1) {
    name.write(pickOne(random, <String>['m', 'w', '-', '0']));
  }
  return name.toString().replaceAll(RegExp(r'-+$'), 'x');
}

void main() {
  testWidgets('test_more_screen_constructor_property_each_screen_follows_'
      'its_own_repository', (WidgetTester tester) async {
    final Random random = seededRandom(1022301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies first = buildGalleryDependencies();
      final AppDependencies second = buildGalleryDependencies();
      await _switchToWorkspaceNamed(second, 'second-$i');
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: Column(
          children: <Widget>[
            Expanded(child: _buildScreen(first)),
            Expanded(child: _buildScreen(second)),
          ],
        ),
      );

      final String firstName = first.workspaceRepository
          .currentWorkspace()
          .name;
      expect(find.text('Now in $firstName', findRichText: true), findsOne);
      expect(find.text('Now in second-$i', findRichText: true), findsOne);
    }
  });

  testWidgets('test_more_screen_build_property_long_workspace_names_fit', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1022302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final Workspace workspace = await _switchToWorkspaceNamed(
        dependencies,
        _randomLongName(random),
      );
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildScreen(dependencies),
      );

      expect(tester.takeException(), isNull, reason: workspace.name);
      expect(
        find.text('Now in ${workspace.name}', findRichText: true),
        findsOne,
      );
    }
  });

  testWidgets('test_more_screen_build_page_property_title_heads_the_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1022303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: _buildScreen(buildGalleryDependencies()),
      );

      final double titleBottom = tester
          .getBottomLeft(find.text(_pageTitle))
          .dy;
      final double rowTop = tester.getTopLeft(find.text(_firstRowTitle)).dy;
      expect(titleBottom, lessThanOrEqualTo(rowTop));
      expect(
        tester.getSemantics(find.text(_pageTitle)),
        isSemantics(label: _pageTitle, isHeader: true),
      );
    }
  });
}
