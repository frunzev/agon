import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';

import '../../data/node_backed/support/pairing_repository_harness.dart';

const Duration pairingLifetime = Duration(minutes: 5);
const String scriptedFreshCode = 'K7M-2QD';

final class ScriptedPairingRepository extends ChangeNotifier
    implements PairingRepository {
  ScriptedPairingRepository({
    required this.clock,
    required this.session,
    required this.request,
    required this.approvedDevice,
  });

  final MovableClock clock;
  final Device approvedDevice;
  PairingSession? session;
  PairingRequest? request;
  String? startedProblem;
  Completer<void>? heldAction;
  String? plannedRefusal;
  final List<String> calls = <String>[];
  final List<List<WorkspaceId>> approvedWorkspaces = <List<WorkspaceId>>[];

  void arrive(PairingRequest arrivingRequest) {
    request = arrivingRequest;
    notifyListeners();
  }

  void passTime(Duration elapsed) {
    clock.moment = clock.moment.add(elapsed);
    notifyListeners();
  }

  void closeElsewhere() {
    session = null;
    request = null;
    notifyListeners();
  }

  @override
  PairingSession? findActiveSession() {
    final PairingSession? shown = session;
    if (shown == null || !shown.expiresAt.isAfter(clock.now())) {
      return null;
    }
    return shown;
  }

  @override
  PairingRequest? findPendingRequest() {
    if (findActiveSession() == null) {
      return null;
    }
    return request;
  }

  @override
  Future<PairingSession> startPairing() async {
    await _waitWhileHeld('start');
    final PairingSession started = PairingSession(
      code: scriptedFreshCode,
      createdAt: clock.now(),
      expiresAt: clock.now().add(pairingLifetime),
      rendezvousProblem: startedProblem,
    );
    session = started;
    request = null;
    notifyListeners();
    return started;
  }

  @override
  Future<Device> approvePairing(List<WorkspaceId> workspaces) async {
    await _waitWhileHeld('approve');
    _requirePendingRequest();
    approvedWorkspaces.add(List<WorkspaceId>.of(workspaces));
    closeElsewhere();
    return approvedDevice;
  }

  @override
  Future<void> rejectPairing() async {
    await _waitWhileHeld('reject');
    _requirePendingRequest();
    closeElsewhere();
  }

  @override
  Future<void> cancelPairing() async {
    await _waitWhileHeld('cancel');
    if (findActiveSession() == null) {
      throw PeopleFacingRefusal(noShowingPairingCode);
    }
    closeElsewhere();
  }

  @override
  WaitingJoin? findWaitingJoin() => null;

  @override
  Future<PairingOutcome> joinWithCode({
    required String? serverAddress,
    required String code,
    required String deviceName,
    required DeviceRole role,
  }) {
    throw UnsupportedError('an approving device does not join');
  }

  @override
  Future<PairingOutcome> createHostedAccount({
    required String workspaceName,
    required String deviceName,
    required DeviceRole role,
  }) {
    throw UnsupportedError('an approving device makes no account');
  }

  Future<void> _waitWhileHeld(String call) async {
    calls.add(call);
    final Completer<void>? hold = heldAction;
    if (hold != null) {
      await hold.future;
    }
    final String? refusal = plannedRefusal;
    if (refusal != null) {
      throw PeopleFacingRefusal(refusal);
    }
  }

  void _requirePendingRequest() {
    if (findPendingRequest() == null) {
      throw PeopleFacingRefusal(noDeviceWaitingToPair);
    }
  }
}
