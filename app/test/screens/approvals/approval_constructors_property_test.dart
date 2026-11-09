import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/approvals/approval_dialog.dart';
import 'package:agent_orchestration/screens/approvals/approval_review.dart';

import '../../support/random_inputs.dart';
import 'support/approval_dialog_scene.dart';
import 'support/random_approval_requests.dart';

const int _largestMinutesAgo = 600;

ApprovalRequest _randomRequest(Random random) {
  return buildPendingApproval(
    action: randomApprovalAction(random),
    requestedBy: pickOne(random, galleryDevices).id,
    requestedAt: galleryNow,
  );
}

ApprovalDialog _buildDialog(Random random, {required Key? key}) {
  return ApprovalDialog(
    key: key,
    request: _randomRequest(random),
    runLabel: randomRunLabel(random),
    askedBy: randomText(random),
    workflows: galleryWorkflows,
    deviceNames: DeviceNames(galleryDevices),
  );
}

void main() {
  test('test_approval_dialog_new_property_keeps_every_field', () {
    final Random random = seededRandom(96101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalRequest request = _randomRequest(random);
      final String? runLabel = randomRunLabel(random);
      final String askedBy = randomText(random);
      final DeviceNames deviceNames = DeviceNames(galleryDevices);
      final ApprovalDialog dialog = ApprovalDialog(
        request: request,
        runLabel: runLabel,
        askedBy: askedBy,
        workflows: galleryWorkflows,
        deviceNames: deviceNames,
      );

      expect(identical(dialog.request, request), isTrue);
      expect(dialog.runLabel, runLabel);
      expect(dialog.askedBy, askedBy);
      expect(identical(dialog.workflows, galleryWorkflows), isTrue);
      expect(identical(dialog.deviceNames, deviceNames), isTrue);
    }
  });

  test('test_approval_dialog_new_property_keeps_the_key', () {
    final Random random = seededRandom(96102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomText(random));

      expect(_buildDialog(random, key: key).key, key);
      expect(_buildDialog(random, key: null).key, isNull);
    }
  });

  testWidgets('test_approval_dialog_new_property_the_shown_dialog_is_the_'
      'built_one', (WidgetTester tester) async {
    final Random random = seededRandom(96103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Key key = ValueKey<int>(i);
      final ApprovalDialog dialog = _buildDialog(random, key: key);
      await openApprovalDialogScene(
        tester,
        size: randomApprovalWindowSize(random),
        dialog: dialog,
      );

      final ApprovalDialog shown = tester.widget<ApprovalDialog>(
        find.byKey(key),
      );
      expect(identical(shown, dialog), isTrue);
    }
  });

  test('test_approval_review_new_property_keeps_every_dependency', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies gallery = buildGalleryDependencies();
      final ApprovalReview review = ApprovalReview(
        approvalRepository: gallery.approvalRepository,
        workflowRepository: gallery.workflowRepository,
        deviceRepository: gallery.deviceRepository,
        clock: gallery.clock,
      );

      expect(
        identical(review.approvalRepository, gallery.approvalRepository),
        isTrue,
      );
      expect(
        identical(review.workflowRepository, gallery.workflowRepository),
        isTrue,
      );
      expect(
        identical(review.deviceRepository, gallery.deviceRepository),
        isTrue,
      );
      expect(identical(review.clock, gallery.clock), isTrue);
    }
  });

  testWidgets('test_approval_review_new_property_the_given_clock_dates_the_'
      'question', (WidgetTester tester) async {
    final Random random = seededRandom(96104);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies gallery = buildGalleryDependencies();
      final DateTime now = galleryNow.add(
        Duration(minutes: random.nextInt(_largestMinutesAgo)),
      );
      final Device requester = pickOne(random, galleryDevices);
      final ApprovalRequest request = buildPendingApproval(
        action: randomApprovalAction(random),
        requestedBy: requester.id,
        requestedAt: galleryNow,
      );
      final ApprovalReview review = ApprovalReview(
        approvalRepository: gallery.approvalRepository,
        workflowRepository: gallery.workflowRepository,
        deviceRepository: gallery.deviceRepository,
        clock: FixedClock(now),
      );
      final _AskingScene scene = _AskingScene(review, request);
      await pumpApprovalOpener(
        tester,
        size: randomApprovalWindowSize(random),
        open: scene.ask,
      );
      await tapOpenApproval(tester);

      final String when = describeTimeSince(galleryNow, now);
      final String lowercaseWhen =
          '${when.substring(0, 1).toLowerCase()}${when.substring(1)}';
      expect(
        find.text('Agent on ${requester.name}, $lowercaseWhen'),
        findsOneWidget,
      );
    }
  });

  testWidgets('test_approval_review_new_property_the_given_devices_name_'
      'the_asker', (WidgetTester tester) async {
    final Random random = seededRandom(96105);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies gallery = buildGalleryDependencies();
      final Device requester = pickOne(
        random,
        gallery.deviceRepository.listDevices(),
      );
      final ApprovalReview review = ApprovalReview(
        approvalRepository: gallery.approvalRepository,
        workflowRepository: gallery.workflowRepository,
        deviceRepository: gallery.deviceRepository,
        clock: gallery.clock,
      );
      final _AskingScene scene = _AskingScene(
        review,
        buildPendingApproval(
          action: randomApprovalAction(random),
          requestedBy: requester.id,
          requestedAt: galleryNow,
        ),
      );
      await pumpApprovalOpener(
        tester,
        size: randomApprovalWindowSize(random),
        open: scene.ask,
      );
      await tapOpenApproval(tester);

      expect(find.text('Agent on ${requester.name}, just now'), findsOne);
    }
  });
}

final class _AskingScene {
  _AskingScene(this.review, this.request);

  final ApprovalReview review;
  final ApprovalRequest request;

  Future<void> ask(BuildContext context) async {
    await review.askForDecision(
      context: context,
      request: request,
      runLabel: null,
    );
  }
}
