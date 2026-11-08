import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/task_form/submit_refusal.dart';
import 'package:agent_orchestration/screens/task_run/run_page_header.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_app_server_refusals.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import '../task_run/support/run_page_retry_harness.dart';

const String _openDialogLabel = 'Open dialog';
const int _largestReasonRepeats = 60;
const int _largestRunNumber = 999;

String _randomRunLabel(Random random) {
  return '${randomWordPhrase(random)} #${random.nextInt(_largestRunNumber)}';
}

String _randomLongReason(Random random) {
  final int repeats = 1 + random.nextInt(_largestReasonRepeats);
  return List<String>.filled(repeats, randomRefusalReason(random)).join(' ');
}

ActionRefusalDialog _buildRetryDialog({
  required String runLabel,
  required String explanation,
}) {
  return ActionRefusalDialog(
    title: runLabel,
    refusal: SubmitRefusal(
      actionLabel: retryRunLabel,
      explanation: explanation,
    ),
  );
}

Future<void> _pumpDialogOpener(
  WidgetTester tester, {
  required double width,
  required ActionRefusalDialog dialog,
}) async {
  useViewSize(tester, Size(width, desktopHeight));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    wrapInApp(
      Builder(
        builder: (BuildContext context) => AppButton.secondary(
          label: _openDialogLabel,
          onPressed: () => showAppDialog<void>(
            context: context,
            builder: (BuildContext _) => dialog,
          ),
        ),
      ),
      platform: platformMeantByWidth(width),
    ),
  );
  await tapAppButton(tester, _openDialogLabel);
}

double _randomWindowWidth(Random random) {
  return randomWidth(random, least: narrowestWidth, most: widestWidth);
}

void main() {
  testWidgets('test_action_refusal_dialog_build_property_retry_shows_label_'
      'reason_and_close', (WidgetTester tester) async {
    final Random random = seededRandom(94601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = _randomWindowWidth(random);
      final String runLabel = _randomRunLabel(random);
      final String explanation = randomRefusalReason(random);
      await _pumpDialogOpener(
        tester,
        width: width,
        dialog: _buildRetryDialog(runLabel: runLabel, explanation: explanation),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(find.text(runLabel), findsOneWidget);
      expect(find.text(retryRefusalTitle), findsOneWidget);
      expect(find.text(explanation), findsOneWidget);
      expect(findAppButton(closeButtonLabel), findsOneWidget);
    }
  });

  testWidgets('test_action_refusal_dialog_build_property_retry_close_'
      'dismisses_it', (WidgetTester tester) async {
    final Random random = seededRandom(94602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpDialogOpener(
        tester,
        width: _randomWindowWidth(random),
        dialog: _buildRetryDialog(
          runLabel: _randomRunLabel(random),
          explanation: randomRefusalReason(random),
        ),
      );

      await tapAppButton(tester, closeButtonLabel);

      expect(tester.takeException(), isNull);
      expect(find.byType(ActionRefusalDialog), findsNothing);
      expect(findAppButton(_openDialogLabel), findsOneWidget);
    }
  });

  testWidgets('test_action_refusal_dialog_build_property_retry_long_'
      'reasons_still_close', (WidgetTester tester) async {
    final Random random = seededRandom(94603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = _randomWindowWidth(random);
      await _pumpDialogOpener(
        tester,
        width: width,
        dialog: _buildRetryDialog(
          runLabel: _randomRunLabel(random),
          explanation: _randomLongReason(random),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
      final Rect dialogArea = tester.getRect(find.byType(AppDialog));
      expect(dialogArea.left, greaterThanOrEqualTo(0));
      expect(dialogArea.right, lessThanOrEqualTo(width));
      expect(dialogArea.bottom, lessThanOrEqualTo(desktopHeight));
      await tapAppButton(tester, closeButtonLabel);
      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(find.byType(ActionRefusalDialog), findsNothing);
    }
  });

  test('test_action_refusal_dialog_constructor_property_keeps_the_run_'
      'label', () {
    final Random random = seededRandom(94604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String runLabel = randomHostileText(random);

      final ActionRefusalDialog dialog = _buildRetryDialog(
        runLabel: runLabel,
        explanation: randomHostileText(random),
      );

      expect(dialog.title, runLabel);
    }
  });

  test('test_action_refusal_dialog_constructor_property_keeps_the_retry_'
      'explanation', () {
    final Random random = seededRandom(94605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String explanation = randomHostileText(random);

      final ActionRefusalDialog dialog = _buildRetryDialog(
        runLabel: randomHostileText(random),
        explanation: explanation,
      );

      expect(dialog.refusal.explanation, explanation);
      expect(dialog.refusal.actionLabel, retryRunLabel);
    }
  });

  test('test_action_refusal_dialog_constructor_property_retry_fields_'
      'never_swap', () {
    final Random random = seededRandom(94606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String runLabel = 'label ${randomText(random)}';
      final String explanation = 'reason ${randomText(random)}';

      final ActionRefusalDialog dialog = _buildRetryDialog(
        runLabel: runLabel,
        explanation: explanation,
      );

      expect(dialog.title, isNot(explanation));
      expect(dialog.refusal.explanation, isNot(runLabel));
    }
  });
}
