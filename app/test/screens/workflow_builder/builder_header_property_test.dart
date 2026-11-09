import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import '../support/random_page_windows.dart';

const String _backLabel = 'Workflows';
const int _longTitleRepeats = 8;

final class _HeaderScene {
  int backs = 0;
  int cancels = 0;
  int signs = 0;
  Completer<void> pendingLeave = Completer<void>();

  void goBack() {
    backs += 1;
  }

  Future<void> cancel() {
    cancels += 1;
    return pendingLeave.future;
  }

  Future<void> sign() {
    signs += 1;
    return pendingLeave.future;
  }

  BuilderHeader build({required String title, required String summary}) {
    return BuilderHeader(
      title: title,
      summary: summary,
      onBack: goBack,
      onCancel: cancel,
      onSigned: sign,
    );
  }
}

String _randomHeaderText(Random random) {
  return pickOne(random, <String>[
    randomHostileText(random),
    List<String>.filled(_longTitleRepeats, randomText(random)).join('-'),
    'feature-pipeline',
  ]);
}

Future<_HeaderScene> _pumpHeader(WidgetTester tester, Random random) async {
  final _HeaderScene scene = _HeaderScene();
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: scene.build(
      title: _randomHeaderText(random),
      summary: _randomHeaderText(random),
    ),
  );
  return scene;
}

Finder _findButton(String label) {
  return find.widgetWithText(AppButton, label);
}

bool _isEnabled(WidgetTester tester, String label) {
  final AppButton button = tester.widget(_findButton(label));
  return button.onPressed != null;
}

void main() {
  testWidgets('test_builder_header_build_property_design_labels_fit', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162401);
    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      await _pumpHeader(tester, random);

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(_findButton(cancelBuildingLabel), findsOneWidget);
      expect(_findButton(signAndSaveLabel), findsOneWidget);
      expect(find.text(_backLabel), findsOneWidget);
    }
  });

  testWidgets('test_builder_header_build_property_back_only_goes_back', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162402);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _HeaderScene scene = await _pumpHeader(tester, random);

      await tester.tap(find.text(_backLabel));
      await tester.pump();

      expect(scene.backs, 1);
      expect(scene.cancels + scene.signs, 0);
    }
  });

  testWidgets('test_builder_header_build_property_ready_buttons_at_rest', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162403);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpHeader(tester, random);

      expect(_isEnabled(tester, cancelBuildingLabel), isTrue);
      expect(_isEnabled(tester, signAndSaveLabel), isTrue);
    }
  });

  testWidgets('test_leave_once_property_taps_during_a_leave_are_ignored', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162404);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _HeaderScene scene = await _pumpHeader(tester, random);
      final String first = pickOne(random, <String>[
        cancelBuildingLabel,
        signAndSaveLabel,
      ]);
      final String second = pickOne(random, <String>[
        cancelBuildingLabel,
        signAndSaveLabel,
      ]);

      await tester.tap(_findButton(first));
      await tester.tap(_findButton(second));
      await tester.pump();

      expect(scene.cancels + scene.signs, 1);
      expect(_isEnabled(tester, cancelBuildingLabel), isFalse);
      expect(_isEnabled(tester, signAndSaveLabel), isFalse);
      scene.pendingLeave.complete();
      await tester.pump();
    }
  });

  testWidgets('test_leave_once_property_buttons_return_if_still_shown', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162405);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _HeaderScene scene = await _pumpHeader(tester, random);

      await tester.tap(_findButton(signAndSaveLabel));
      await tester.pump();
      scene.pendingLeave.complete();
      await tester.pump();
      await tester.pump();

      expect(_isEnabled(tester, cancelBuildingLabel), isTrue);
      expect(_isEnabled(tester, signAndSaveLabel), isTrue);
      scene.pendingLeave = Completer<void>();
      await tester.tap(_findButton(signAndSaveLabel));
      await tester.pump();
      expect(scene.signs, 2);
      scene.pendingLeave.complete();
      await tester.pump();
    }
  });

  testWidgets('test_leave_once_property_failed_leave_frees_the_buttons', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162406);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _HeaderScene scene = await _pumpHeader(tester, random);
      final List<Object> escaped = <Object>[];

      await runZonedGuarded<Future<void>>(() async {
        scene.pendingLeave = Completer<void>();
        await tester.tap(_findButton(cancelBuildingLabel));
        await tester.pump();
        scene.pendingLeave.completeError(StateError(randomText(random)));
        await tester.pump();
        await tester.pump();
      }, (Object problem, StackTrace _) => escaped.add(problem));

      expect(escaped, <Matcher>[isA<StateError>()]);
      expect(_isEnabled(tester, cancelBuildingLabel), isTrue);
    }
  });

  testWidgets('test_builder_header_create_state_property_headers_apart', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162407);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _HeaderScene left = _HeaderScene();
      final _HeaderScene right = _HeaderScene();
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: Column(
          children: <Widget>[
            left.build(title: 'left', summary: randomText(random)),
            right.build(title: 'right', summary: randomText(random)),
          ],
        ),
      );

      await tester.tap(_findButton(cancelBuildingLabel).first);
      await tester.pump();

      final List<AppButton> rightButtons = tester
          .widgetList<AppButton>(find.byType(AppButton))
          .skip(2)
          .toList();
      expect(left.cancels, 1);
      for (final AppButton button in rightButtons) {
        expect(button.onPressed, isNotNull);
      }
      left.pendingLeave.complete();
      await tester.pump();
    }
  });

  testWidgets('test_builder_header_create_state_property_survives_rebuild', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162408);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _HeaderScene scene = await _pumpHeader(tester, random);
      await tester.tap(_findButton(cancelBuildingLabel));
      await tester.pump();

      await tester.pumpWidget(
        wrapInApp(
          scene.build(title: randomText(random), summary: randomText(random)),
          platform: platformMeantByWidth(tester.view.physicalSize.width),
        ),
      );

      expect(_isEnabled(tester, signAndSaveLabel), isFalse);
      scene.pendingLeave.complete();
      await tester.pump();
    }
  });

  testWidgets('test_builder_header_create_state_property_gone_is_quiet', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162409);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _HeaderScene scene = await _pumpHeader(tester, random);
      await tester.tap(_findButton(signAndSaveLabel));
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      scene.pendingLeave.complete();
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(scene.signs, 1);
    }
  });
}
