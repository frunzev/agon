import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const SectionRoute newWorkflowFormSectionRoute = SectionRoute(
  AppSection.workflows,
);
const double promptMaximumWidth = 512;
const Duration betweenNewWorkflowTaps = Duration(milliseconds: 80);
const List<String> _shownWhiteSpaces = <String>[
  ' ',
  '\t',
  '\n',
  '\u00A0',
  '\u2003',
  '\u3000',
];

AppNavigation buildNewWorkflowNavigation() {
  final AppNavigation navigation = AppNavigation(
    initialRoute: newWorkflowFormSectionRoute,
  );
  navigation.openRoute(const NewWorkflowRoute());
  return navigation;
}

Future<double> pumpNewWorkflowScreen(
  WidgetTester tester,
  Random random,
  NewWorkflowScreen screen,
) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  useViewSize(tester, Size(width, desktopHeight));
  await tester.pumpWidget(
    wrapInApp(screen, platform: platformMeantByWidth(width)),
  );
  await tester.pump();
  return width;
}

String randomDescriptionWhiteSpace(Random random) {
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < random.nextInt(4); i += 1) {
    buffer.write(pickOne(random, _shownWhiteSpaces));
  }
  return buffer.toString();
}

Finder findWorkflowDescription() => findFieldInput(workflowQuestion);

Future<void> tapNewWorkflowLabel(WidgetTester tester, String label) async {
  await tapVisible(tester, find.text(label));
  await tester.pump();
}
