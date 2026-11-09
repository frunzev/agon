import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_frames.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const Key _childKey = ValueKey<String>('framed child');

Widget _randomChild(Random random) {
  return SizedBox(
    key: _childKey,
    width: random.nextDouble() * 200,
    height: random.nextDouble() * 200,
  );
}

Future<void> _pumpAtRandomWidth(
  WidgetTester tester,
  Random random,
  Widget child,
) async {
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: child,
  );
}

void _expectFramedLikeTheDesign(Container frame) {
  final BoxDecoration decoration = frame.decoration! as BoxDecoration;
  final Border border = decoration.border! as Border;

  expect(frame.padding, const EdgeInsets.all(AppSpacing.space5));
  expect(border.top.color, AppColors.line);
  expect(decoration.borderRadius, BorderRadius.circular(AppRadii.panel));
}

void _expectChildInsideFrame(WidgetTester tester, Finder frame) {
  final Rect frameBox = tester.getRect(frame);
  final Rect childBox = tester.getRect(find.byKey(_childKey));
  final Rect insideFrame = frameBox.deflate(AppSpacing.space5);

  expect(childBox.left, greaterThanOrEqualTo(insideFrame.left - 0.01));
  expect(childBox.top, greaterThanOrEqualTo(insideFrame.top - 0.01));
  expect(childBox.right, lessThanOrEqualTo(insideFrame.right + 0.01));
  expect(childBox.bottom, lessThanOrEqualTo(insideFrame.bottom + 0.01));
}

void main() {
  test('test_file_frame_new_property_keeps_child_and_key', () {
    final Random random = seededRandom(100001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Widget child = Text(randomHostileText(random));
      final Key key = ValueKey<int>(random.nextInt(1000));
      final FileFrame frame = FileFrame(key: key, child: child);

      expect(frame.child, same(child));
      expect(frame.key, key);
    }
  });

  test('test_image_frame_new_property_keeps_child_and_key', () {
    final Random random = seededRandom(100002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Widget child = Text(randomHostileText(random));
      final Key key = ValueKey<int>(random.nextInt(1000));
      final ImageFrame frame = ImageFrame(key: key, child: child);

      expect(frame.child, same(child));
      expect(frame.key, key);
    }
  });

  test('test_empty_section_new_property_keeps_title_and_children', () {
    final Random random = seededRandom(100003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = randomHostileText(random);
      final List<Widget> children = <Widget>[
        for (final String text in randomHostileTexts(random)) Text(text),
      ];
      final EmptySection section = EmptySection(
        title: title,
        children: children,
      );

      expect(section.title, title);
      expect(section.children, same(children));
    }
  });

  testWidgets('test_file_frame_build_property_draws_the_design_frame', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpAtRandomWidth(
        tester,
        random,
        FileFrame(child: _randomChild(random)),
      );
      final Finder frame = find.descendant(
        of: find.byType(FileFrame),
        matching: find.byType(Container),
      );

      _expectFramedLikeTheDesign(tester.widget<Container>(frame.first));
    }
  });

  testWidgets('test_file_frame_build_property_keeps_child_inside_padding', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpAtRandomWidth(
        tester,
        random,
        FileFrame(child: _randomChild(random)),
      );

      _expectChildInsideFrame(tester, find.byType(FileFrame));
      expect(find.byKey(_childKey), findsOneWidget);
    }
  });

  testWidgets('test_file_frame_build_property_wraps_long_text', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 100006,
      buildChild: (Random random) =>
          FileFrame(child: Text(randomHostileText(random) * 30)),
    );
  });

  testWidgets('test_image_frame_build_property_draws_the_design_frame', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100007);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpAtRandomWidth(
        tester,
        random,
        ImageFrame(child: _randomChild(random)),
      );
      final Finder frame = find.descendant(
        of: find.byType(ImageFrame),
        matching: find.byType(Container),
      );
      final ClipRRect clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(ImageFrame),
          matching: find.byType(ClipRRect),
        ),
      );

      _expectFramedLikeTheDesign(tester.widget<Container>(frame.first));
      expect(clip.borderRadius, BorderRadius.circular(AppRadii.panel));
    }
  });

  testWidgets('test_image_frame_build_property_centers_the_image', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100008);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpAtRandomWidth(
        tester,
        random,
        ImageFrame(child: _randomChild(random)),
      );
      final Offset frameCenter = tester.getCenter(find.byType(ImageFrame));
      final Offset childCenter = tester.getCenter(find.byKey(_childKey));

      expect((frameCenter.dx - childCenter.dx).abs(), lessThan(0.01));
      expect((frameCenter.dy - childCenter.dy).abs(), lessThan(0.01));
    }
  });

  testWidgets('test_image_frame_build_property_keeps_child_inside_padding', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100009);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpAtRandomWidth(
        tester,
        random,
        ImageFrame(child: _randomChild(random)),
      );

      _expectChildInsideFrame(tester, find.byType(ImageFrame));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_empty_section_build_property_title_is_a_heading', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100010);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String title = 'Title ${randomHostileText(random)}';
      await _pumpAtRandomWidth(
        tester,
        random,
        EmptySection(title: title, children: const <Widget>[]),
      );
      final Semantics heading = tester.widget<Semantics>(
        find
            .ancestor(of: find.text(title), matching: find.byType(Semantics))
            .first,
      );

      expect(heading.properties.header, isTrue);
    }
  });

  testWidgets('test_empty_section_build_property_children_follow_in_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100011);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int childCount = random.nextInt(5);
      await _pumpAtRandomWidth(
        tester,
        random,
        EmptySection(
          title: 'Title',
          children: <Widget>[
            for (int index = 0; index < childCount; index += 1)
              Text('part $index'),
          ],
        ),
      );
      double previousBottom = tester.getRect(find.text('Title')).bottom;

      for (int index = 0; index < childCount; index += 1) {
        final Rect part = tester.getRect(find.text('part $index'));
        expect(part.top - previousBottom, closeTo(AppSpacing.space3, 0.01));
        previousBottom = part.bottom;
      }
    }
  });

  testWidgets('test_empty_section_build_property_stays_within_the_measure', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100012);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpAtRandomWidth(
        tester,
        random,
        EmptySection(
          title: randomHostileText(random) * 10,
          children: <Widget>[Text(randomHostileText(random) * 40)],
        ),
      );
      final Rect column = tester.getRect(
        find
            .descendant(
              of: find.byType(EmptySection),
              matching: find.byType(Column),
            )
            .first,
      );

      expect(column.width, lessThanOrEqualTo(AppSizes.measure + 0.01));
      expect(column.left, closeTo(0, 0.01));
      expect(tester.takeException(), isNull);
    }
  });
}
