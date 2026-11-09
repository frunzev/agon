import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';

import '../../support/random_device_records.dart';
import '../../support/random_inputs.dart';
import 'support/approvals_screen_scene.dart';

ApprovalRequest _askedBy(ApprovalRequest request, DeviceId requester) {
  return ApprovalRequest(
    id: request.id,
    runId: request.runId,
    action: request.action,
    requestedBy: requester,
    requestedAt: request.requestedAt,
    decision: null,
  );
}

List<ApprovalRequest> _randomPendingFrom(
  Random random,
  List<DeviceId> requesters,
) {
  final List<ApprovalRequest> pending = listPending(approvalPool);
  final int count = 1 + random.nextInt(pending.length);
  return <ApprovalRequest>[
    for (final ApprovalRequest request in pending.take(count))
      _askedBy(request, pickOne(random, requesters)),
  ];
}

Future<AppDependencies> _pumpPending(
  WidgetTester tester,
  Random random,
  List<ApprovalRequest> pending,
) async {
  final AppDependencies dependencies = replaceApprovals(
    buildGalleryDependencies(),
    pending,
  );
  await pumpApprovalsScreen(
    tester,
    random: random,
    dependencies: dependencies,
  );
  return dependencies;
}

DeviceId _randomUnknownRequester(Random random) {
  return randomDeviceRecord(random, approvedBy: null).id;
}

void main() {
  testWidgets('test_approvals_screen_build_row_property_an_unknown_'
      'requester_never_crashes', (WidgetTester tester) async {
    final Random random = seededRandom(5312001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<ApprovalRequest> pending = _randomPendingFrom(
        random,
        <DeviceId>[_randomUnknownRequester(random)],
      );

      await _pumpPending(tester, random, pending);

      expectNoProblem(tester);
      expect(find.text(reviewLabel), findsWidgets);
    }
  });

  testWidgets('test_approvals_screen_build_row_property_an_unknown_'
      'requester_reads_as_its_short_identifier', (WidgetTester tester) async {
    final Random random = seededRandom(5312002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DeviceId requester = _randomUnknownRequester(random);
      final List<ApprovalRequest> pending = _randomPendingFrom(
        random,
        <DeviceId>[requester],
      );

      await _pumpPending(tester, random, pending);

      final String shortName = shortenIdentifier(requester.value);
      expect(find.text(shortName), findsNWidgets(pending.length));
    }
  });

  testWidgets('test_approvals_screen_build_row_property_known_requesters_'
      'keep_their_names_beside_unknown_ones', (WidgetTester tester) async {
    final Random random = seededRandom(5312003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies gallery = buildGalleryDependencies();
      final Device known = pickOne(
        random,
        gallery.deviceRepository.listDevices(),
      );
      final DeviceId unknown = _randomUnknownRequester(random);
      final List<ApprovalRequest> pending = _randomPendingFrom(
        random,
        <DeviceId>[known.id, unknown],
      );

      await _pumpPending(tester, random, pending);

      final int knownCount = pending
          .where((ApprovalRequest request) => request.requestedBy == known.id)
          .length;
      expectNoProblem(tester);
      if (knownCount > 0) {
        expect(find.text(known.name), findsWidgets);
      }
      expect(
        find.text(shortenIdentifier(unknown.value)),
        findsNWidgets(pending.length - knownCount),
      );
    }
  });
}
