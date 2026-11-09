import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/path_breadcrumb.dart';
import 'package:agent_orchestration/screens/files/repository_file_paths.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_property_inputs.dart';

const String _separator = '/';
const String _breadcrumbLabel = 'Path';
const int _deepestPath = 12;
const List<String> _readableSegments = <String>[
  'src',
  'שלום',
  'مرحبا',
  '\u202eevil',
  'café',
  '\u{1F600}',
  'a-very-long-folder-name-without-any-spaces-at-all-to-wrap',
];

String _randomSegment(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _readableSegments);
  }
  return randomHostileFileStem(random);
}

String _randomDeepPath(Random random) {
  final int depth = 1 + random.nextInt(_deepestPath);
  return <String>[
    for (int index = 0; index < depth; index += 1) _randomSegment(random),
  ].join(_separator);
}

List<String> _readTexts(WidgetTester tester, Type wrapper) {
  final Finder texts = find.descendant(
    of: find.descendant(
      of: find.byType(PathBreadcrumb),
      matching: find.byType(wrapper),
    ),
    matching: find.byType(Text),
  );
  return <String>[
    for (final Element element in texts.evaluate())
      (element.widget as Text).data ?? '',
  ];
}

Future<void> _pumpBreadcrumb(
  WidgetTester tester,
  Random random,
  PathBreadcrumb breadcrumb,
) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(tester, width: width, child: breadcrumb);
  expect(tester.takeException(), isNull, reason: 'width $width');
}

void main() {
  testWidgets('test_path_breadcrumb_build_property_crumbs_round_trip_to_'
      'the_path', (WidgetTester tester) async {
    final Random random = seededRandom(100431);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String repositoryPath = 'acme/${_randomSegment(random)}';
      final String filePath = _randomDeepPath(random);
      final List<String> labels = describeBreadcrumb(repositoryPath, filePath);

      await _pumpBreadcrumb(
        tester,
        random,
        PathBreadcrumb(labels: labels, onPressed: () {}),
      );

      final List<String> crumbs = _readTexts(tester, InkWell);
      expect(crumbs, labels);
      expect(crumbs.first, repositoryPath);
      final String rebuiltPath = <String>[
        ...crumbs.sublist(1),
        fileNameOf(filePath),
      ].join(_separator);
      expect(rebuiltPath, filePath);
    }
  });

  testWidgets('test_path_breadcrumb_build_property_one_separator_between_'
      'each_pair', (WidgetTester tester) async {
    final Random random = seededRandom(100432);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> labels = <String>[
        for (int index = 0; index < random.nextInt(_deepestPath); index += 1)
          _randomSegment(random),
      ];

      await _pumpBreadcrumb(
        tester,
        random,
        PathBreadcrumb(labels: labels, onPressed: () {}),
      );

      final List<String> separators = _readTexts(tester, ExcludeSemantics);
      final int expectedCount = labels.isEmpty ? 0 : labels.length - 1;
      expect(separators, List<String>.filled(expectedCount, _separator));
      final Semantics container = tester.widget(
        find
            .descendant(
              of: find.byType(PathBreadcrumb),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(container.properties.label, _breadcrumbLabel);
      expect(container.container, isTrue);
    }
  });

  testWidgets('test_path_breadcrumb_build_property_every_crumb_returns_to_'
      'the_files', (WidgetTester tester) async {
    final Random random = seededRandom(100433);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      int presses = 0;
      final List<String> labels = <String>[
        'acme/app',
        for (int index = 0; index < random.nextInt(6); index += 1)
          'f$index${pickOne(random, _readableSegments)}',
      ];

      await _pumpBreadcrumb(
        tester,
        random,
        PathBreadcrumb(labels: labels, onPressed: () => presses += 1),
      );
      final Finder crumbs = find.descendant(
        of: find.byType(PathBreadcrumb),
        matching: find.byType(InkWell),
      );
      final int crumbCount = crumbs.evaluate().length;
      for (int index = 0; index < crumbCount; index += 1) {
        await tester.tap(crumbs.at(index));
      }
      await tester.pump();

      expect(crumbCount, labels.length);
      expect(presses, labels.length);
    }
  });

  testWidgets('test_path_breadcrumb_build_property_crumbs_stay_inside_the_'
      'window', (WidgetTester tester) async {
    final Random random = seededRandom(100434);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> labels = describeBreadcrumb(
        'acme/app',
        _randomDeepPath(random),
      );

      await _pumpBreadcrumb(
        tester,
        random,
        PathBreadcrumb(labels: labels, onPressed: () {}),
      );

      final double windowWidth = tester.view.physicalSize.width;
      final Finder crumbs = find.descendant(
        of: find.byType(PathBreadcrumb),
        matching: find.byType(InkWell),
      );
      for (final Element crumb in crumbs.evaluate()) {
        final Rect area = tester.getRect(find.byWidget(crumb.widget));
        expect(area.left, greaterThanOrEqualTo(0));
        expect(area.right, lessThanOrEqualTo(windowWidth + 0.5));
      }
    }
  });
}
