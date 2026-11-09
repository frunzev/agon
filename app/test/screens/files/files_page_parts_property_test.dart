import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/files/files_page_parts.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const String _designTitle = 'Files';
const String _designSummary = 'Read only';
const Key _repositoryKey = ValueKey<String>('repository picker');
const Key _branchKey = ValueKey<String>('branch picker');
const Key _treeKey = ValueKey<String>('tree');

String _randomLongText(Random random) {
  return randomHostileText(random) * (1 + random.nextInt(30));
}

FileTreeSection _randomSection(Random random) {
  return FileTreeSection(
    repositoryPicker: const SizedBox(
      key: _repositoryKey,
      height: 40,
      child: Text('acme/app'),
    ),
    branchPicker: random.nextBool()
        ? const SizedBox(key: _branchKey, height: 40, child: Text('main'))
        : null,
    runnerName: _randomLongText(random),
    treeView: random.nextBool()
        ? const SizedBox(key: _treeKey, height: 120, child: Text('tree'))
        : null,
  );
}

Future<double> _pumpAtRandomWidth(
  WidgetTester tester,
  Random random,
  Widget child,
) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(tester, width: width, child: child);
  expect(tester.takeException(), isNull, reason: 'width $width');
  return width;
}

void main() {
  test('test_build_files_page_header_property_keeps_the_design_title_and_'
      'summary', () {
    final Random random = seededRandom(100441);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PageHeader header = buildFilesPageHeader(
        projectName: randomHostileText(random),
        onBack: () {},
      );

      expect(header.title, _designTitle);
      expect(header.summary, hasLength(1));
      expect(header.summary.single.text, _designSummary);
      expect(header.summary.single.face, TextFace.body);
      expect(header.breadcrumb, isNull);
      expect(header.actions, isEmpty);
    }
  });

  test('test_build_files_page_header_property_back_link_names_the_'
      'project', () {
    final Random random = seededRandom(100442);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String projectName = randomHostileText(random);
      int backs = 0;

      final PageHeader header = buildFilesPageHeader(
        projectName: projectName,
        onBack: () => backs += 1,
      );
      header.backLink!.onPressed();

      expect(header.backLink!.label, projectName);
      expect(backs, 1);
    }
  });

  testWidgets('test_build_files_page_header_property_renders_any_project_'
      'name', (WidgetTester tester) async {
    final Random random = seededRandom(100443);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String projectName = 'p${_randomLongText(random)}';
      int backs = 0;

      await _pumpAtRandomWidth(
        tester,
        random,
        buildFilesPageHeader(
          projectName: projectName,
          onBack: () => backs += 1,
        ),
      );
      await tester.tap(find.text(projectName));
      await tester.pump();

      expect(find.text(_designTitle), findsOneWidget);
      expect(backs, 1);
    }
  });

  testWidgets('test_files_problem_build_property_shows_the_exact_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100444);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = 'x${_randomLongText(random)}';

      await _pumpAtRandomWidth(tester, random, FilesProblem(text: problem));

      expect(find.text(problem), findsOneWidget);
    }
  });

  testWidgets('test_files_problem_build_property_reads_as_a_danger_alert', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100445);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = _randomLongText(random);

      await _pumpAtRandomWidth(tester, random, FilesProblem(text: problem));

      final StatusLabel label = tester.widget(find.byType(StatusLabel));
      expect(label.text, problem);
      expect(label.tone, StatusTone.danger);
      expect(label.icon, AppIconKind.alert);
    }
  });

  testWidgets('test_files_problem_build_property_stays_inside_the_window', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100446);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = 'x${_randomLongText(random)}';

      final double width = await _pumpAtRandomWidth(
        tester,
        random,
        FilesProblem(text: problem),
      );

      final Rect area = tester.getRect(find.text(problem));
      expect(area.left, greaterThanOrEqualTo(0));
      expect(area.right, lessThanOrEqualTo(width + 0.5));
    }
  });

  testWidgets('test_file_tree_section_build_property_names_the_runner_it_'
      'reads_from', (WidgetTester tester) async {
    final Random random = seededRandom(100447);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FileTreeSection section = _randomSection(random);

      await _pumpAtRandomWidth(tester, random, section);

      final String status = 'From ${section.runnerName} · encrypted';
      expect(find.text(status, findRichText: true), findsOneWidget);
    }
  });

  testWidgets('test_file_tree_section_build_property_shows_the_given_'
      'parts_only', (WidgetTester tester) async {
    final Random random = seededRandom(100448);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FileTreeSection section = _randomSection(random);

      await _pumpAtRandomWidth(tester, random, section);

      expect(find.byKey(_repositoryKey), findsOneWidget);
      final bool hasBranch = section.branchPicker != null;
      final bool hasTree = section.treeView != null;
      expect(find.byKey(_branchKey), hasBranch ? findsOne : findsNothing);
      expect(find.byKey(_treeKey), hasTree ? findsOne : findsNothing);
    }
  });

  testWidgets('test_file_tree_section_build_property_pickers_then_status_'
      'then_tree', (WidgetTester tester) async {
    final Random random = seededRandom(100449);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FileTreeSection section = _randomSection(random);

      await _pumpAtRandomWidth(tester, random, section);

      final Rect picker = tester.getRect(find.byKey(_repositoryKey));
      final Rect status = tester.getRect(
        find.textContaining('encrypted', findRichText: true),
      );
      expect(picker.bottom, lessThanOrEqualTo(status.top));
      if (section.treeView != null) {
        final Rect tree = tester.getRect(find.byKey(_treeKey));
        expect(status.bottom, lessThanOrEqualTo(tree.top));
      }
    }
  });
}
