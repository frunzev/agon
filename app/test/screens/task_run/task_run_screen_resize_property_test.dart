import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/screens/task_run/earlier_rounds_block.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/run_steps_section_scenes.dart';
import 'support/task_run_screen_scenes.dart';

const double _widestNarrowWindow = LayoutSize.largeMinimumWidth - 1;

Finder _findBoxOfHeight(double height) {
  return find.byWidgetPredicate(
    (Widget widget) => widget is SizedBox && widget.height == height,
  );
}

RunPageScene _randomSceneWithRounds(Random random) {
  while (true) {
    final Run run = randomRunOfTask(
      random,
      task: pickOne(random, listGalleryWork()),
    );
    if (listStepsWithRounds(run).isNotEmpty) {
      return buildRunPageScene(
        run: run,
        openSteps: const <OpenPersonStep>[],
        approvals: const <ApprovalRequest>[],
      );
    }
  }
}

Size _randomSizeIn(Random random, double least, double most) {
  return Size(randomWidth(random, least: least, most: most), desktopHeight);
}

void main() {
  testWidgets('test_task_run_screen_build_property_resizing_keeps_rounds', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(116001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageScene scene = _randomSceneWithRounds(random);
      final Size wide = _randomSizeIn(
        random,
        LayoutSize.largeMinimumWidth,
        widestWidth,
      );
      final Size narrow = _randomSizeIn(
        random,
        LayoutSize.mediumMinimumWidth,
        _widestNarrowWindow,
      );
      final bool startsWide = random.nextBool();
      await tester.pumpWidget(const SizedBox());
      await pumpApp(
        tester,
        size: startsWide ? wide : narrow,
        route: TaskRunRoute(scene.run.id),
        dependencies: scene.dependencies,
      );
      final RunStep step = pickOne(random, listStepsWithRounds(scene.run));
      tester
          .widget<EarlierRoundsBlock>(findEarlierRoundsBlock(step.name))
          .onToggled();
      await pumpFrames(tester);
      expect(isShowingEarlierRounds(tester, step.name), isTrue);

      useViewSize(tester, startsWide ? narrow : wide);
      await pumpFrames(tester);

      expect(isShowingEarlierRounds(tester, step.name), isTrue);
    }
  });

  testWidgets('test_split_layout_property_children_keep_state_when_resized', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(116002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double wide = randomWidth(
        random,
        least: LayoutSize.largeMinimumWidth,
        most: widestWidth,
      );
      final double narrow = randomWidth(
        random,
        least: LayoutSize.mediumMinimumWidth,
        most: _widestNarrowWindow,
      );
      final bool startsWide = random.nextBool();
      final String typed = 'typed $i ${randomWordPhrase(random)}';
      final Widget layout = SplitLayout(
        proportion: pickOne(random, SplitProportion.values),
        start: const TextField(),
        end: const Text('end'),
      );
      await tester.pumpWidget(const SizedBox());
      await pumpScrollableAtWidth(
        tester,
        width: startsWide ? wide : narrow,
        child: layout,
      );
      await tester.enterText(find.byType(TextField), typed);

      await pumpScrollableAtWidth(
        tester,
        width: startsWide ? narrow : wide,
        child: layout,
      );

      final EditableText field = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(field.controller.text, typed);
      expect(find.text('end'), findsOneWidget);
    }
  });

  testWidgets('test_split_layout_property_wide_widths_follow_proportion', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(116003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SplitProportion proportion = pickOne(
        random,
        SplitProportion.values,
      );
      final double width = randomWidth(
        random,
        least: LayoutSize.largeMinimumWidth,
        most: widestWidth,
      );
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: SplitLayout(
          proportion: proportion,
          start: const SizedBox(height: 10),
          end: const SizedBox(height: 20),
        ),
      );

      final double startWidth = tester.getSize(_findBoxOfHeight(10)).width;
      final double endWidth = tester.getSize(_findBoxOfHeight(20)).width;
      final double expectedRatio = proportion.startFlex / proportion.endFlex;
      expect(startWidth / endWidth, closeTo(expectedRatio, 0.01));
    }
  });
}
