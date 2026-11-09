import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/screens/tasks/tasks_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const SectionRoute tasksRoute = SectionRoute(AppSection.tasks);

Future<AppNavigation> openTasksPage(
  WidgetTester tester, {
  required Random random,
  required AppDependencies dependencies,
}) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await tester.pumpWidget(const SizedBox());
  return pumpApp(
    tester,
    size: Size(width, desktopHeight),
    route: tasksRoute,
    dependencies: dependencies,
  );
}

List<ListRowData> readTaskRows(WidgetTester tester) {
  final Finder lists = find.descendant(
    of: find.byType(TasksScreen),
    matching: find.byType(ResponsiveList),
  );
  if (lists.evaluate().isEmpty) {
    return const <ListRowData>[];
  }
  return tester.widget<ResponsiveList>(lists).rows;
}

List<String> readTaskRowTitles(WidgetTester tester) {
  final List<String> titles = <String>[];
  for (final ListRowData row in readTaskRows(tester)) {
    final ListRowMain main = row.main as ListRowMain;
    titles.add(main.title);
  }
  return titles;
}

Future<void> tapTaskTitle(WidgetTester tester, String title) async {
  final Finder titleText = find.descendant(
    of: find.byType(TasksScreen),
    matching: find.text(title),
  );
  await tester.ensureVisible(titleText);
  await tester.tap(titleText);
  await pumpFrames(tester);
}
