import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

const List<int> _testSignature = <int>[0];
const String _approvalKind = 'approval request';

final class ArrivingApprovalRepository extends ChangeNotifier
    implements ApprovalRepository {
  List<ApprovalRequest> _approvals = const <ApprovalRequest>[];

  void raiseApproval(ApprovalRequest request) {
    _approvals = List<ApprovalRequest>.unmodifiable(<ApprovalRequest>[
      ..._approvals,
      request,
    ]);
    notifyListeners();
  }

  @override
  List<ApprovalRequest> listApprovals() => _approvals;

  @override
  List<ApprovalRequest> listPendingApprovals() {
    return <ApprovalRequest>[
      for (final ApprovalRequest request in _approvals)
        if (request.isPending) request,
    ];
  }

  @override
  ApprovalRequest findApproval(ApprovalId approvalId) {
    return findRecord(
      _approvals,
      matches: (ApprovalRequest request) => request.id == approvalId,
      kind: _approvalKind,
      identifier: approvalId.value,
    );
  }

  @override
  Future<ApprovalRequest> decideApproval(
    ApprovalId approvalId,
    ApprovalDecision decision,
  ) async {
    final ApprovalRequest requested = findApproval(approvalId);
    if (!requested.isPending) {
      throw PeopleFacingRefusal(
        'Approval ${approvalId.value} is already decided',
      );
    }

    final ApprovalRequest decided = requested.withDecision(
      SignedDecision(
        decision: decision,
        decidedBy: GalleryDeviceIds.airLaptop,
        decidedAt: galleryNow,
        signature: _testSignature,
      ),
    );

    _approvals = List<ApprovalRequest>.unmodifiable(<ApprovalRequest>[
      for (final ApprovalRequest request in _approvals)
        if (request.id == approvalId) decided else request,
    ]);
    notifyListeners();
    return decided;
  }
}
