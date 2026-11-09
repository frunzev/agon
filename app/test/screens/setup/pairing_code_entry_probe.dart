import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/screens/setup/pairing_code_entry_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/fixed_qr_code_scanner.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import '../support/planned_refusal.dart';

const String pairingCodeLabel = 'Pairing code';
const String _crockfordSymbols = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const List<String> _codeSeparators = <String>['', '', '-', ' ', ' '];
const List<String> _foreignSymbols = <String>['U', 'u', '#', '!', '_', '😀'];
const int _codeLength = 6;
const int _largestNameNumber = 1000;
const List<String> _deviceKinds = <String>['Mac', 'PC', 'computer', 'phone'];

PairingOutcome _buildOutcome({
  required String deviceName,
  required DeviceRole role,
  required List<String> workspaceNames,
}) {
  return PairingOutcome(
    deviceName: deviceName,
    role: role,
    workspaceNames: workspaceNames,
    runnerLabels: const <String>[],
    approverName: null,
  );
}

final class ScriptedPairingRepository extends ChangeNotifier
    implements PairingRepository {
  final List<String> joinedCodes = <String>[];
  final List<String?> joinedServerAddresses = <String?>[];
  final PlannedRefusal joinRefusal = PlannedRefusal();
  Completer<void>? pendingJoin;
  WaitingJoin? waitingJoin;

  bool get isFollowed => hasListeners;

  void showWaitingJoin(WaitingJoin? join) {
    waitingJoin = join;
    notifyListeners();
  }

  @override
  Future<PairingOutcome> joinWithCode({
    required String? serverAddress,
    required String code,
    required String deviceName,
    required DeviceRole role,
  }) async {
    joinedCodes.add(code);
    joinedServerAddresses.add(serverAddress);
    final Completer<void>? pending = pendingJoin;
    if (pending != null) {
      await pending.future;
    }
    final PairingOutcome outcome = _buildOutcome(
      deviceName: deviceName,
      role: role,
      workspaceNames: const <String>['acme'],
    );
    return joinRefusal.refuseOr(() => Future<PairingOutcome>.value(outcome));
  }

  @override
  Future<PairingOutcome> createHostedAccount({
    required String workspaceName,
    required String deviceName,
    required DeviceRole role,
  }) => throw UnimplementedError();

  @override
  WaitingJoin? findWaitingJoin() => waitingJoin;

  @override
  PairingSession? findActiveSession() => null;

  @override
  PairingRequest? findPendingRequest() => null;

  @override
  Future<PairingSession> startPairing() => throw UnimplementedError();

  @override
  Future<Device> approvePairing(List<WorkspaceId> workspaces) {
    throw UnimplementedError();
  }

  @override
  Future<void> rejectPairing() => throw UnimplementedError();

  @override
  Future<void> cancelPairing() => throw UnimplementedError();
}

final class PairingCodeEntryProbe {
  PairingCodeEntryProbe(
    Random random, {
    required this.offersScanning,
    required this.offersHosting,
  }) : role = pickOne(random, DeviceRole.values),
       deviceKind = pickOne(random, _deviceKinds),
       deviceName = 'device-${random.nextInt(_largestNameNumber)}';

  final DeviceRole role;
  final String deviceKind;
  final String deviceName;
  final bool offersScanning;
  final bool offersHosting;
  final ScriptedPairingRepository repository = ScriptedPairingRepository();
  final FixedQrCodeScanner scanner = FixedQrCodeScanner(null);
  final PlannedRefusal hostingRefusal = PlannedRefusal();
  late final AppNavigation navigation = AppNavigation(
    initialRoute: PairingCodeEntryRoute(role),
  );
  int hostingRequests = 0;
  Completer<void>? pendingHosting;

  String get pairLabel => 'Pair this $deviceKind';

  PairingOutcome get hostedOutcome => _buildOutcome(
    deviceName: deviceName,
    role: role,
    workspaceNames: const <String>['personal'],
  );

  PairingCodeEntryScreen build() {
    return PairingCodeEntryScreen(
      role: role,
      deviceKind: deviceKind,
      deviceName: deviceName,
      scanner: offersScanning ? scanner : null,
      hostAppServer: offersHosting ? _host : null,
      pairingRepository: repository,
      navigation: navigation,
    );
  }

  Future<PairingOutcome> _host() async {
    hostingRequests += 1;
    final Completer<void>? pending = pendingHosting;
    if (pending != null) {
      await pending.future;
    }
    return hostingRefusal.refuseOr(
      () => Future<PairingOutcome>.value(hostedOutcome),
    );
  }
}

PairingCodeEntryProbe randomPairingCodeEntryProbe(Random random) {
  return PairingCodeEntryProbe(
    random,
    offersScanning: random.nextBool(),
    offersHosting: random.nextBool(),
  );
}

Future<void> pumpPairingCodeEntry(
  WidgetTester tester,
  Random random,
  PairingCodeEntryProbe probe,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: probe.build(),
  );
}

String randomValidPairingCode(Random random) {
  final StringBuffer code = StringBuffer();
  for (int i = 0; i < _codeLength; i += 1) {
    code.write(pickOne(random, _codeSeparators));
    final String symbol =
        _crockfordSymbols[random.nextInt(_crockfordSymbols.length)];
    code.write(random.nextBool() ? symbol : symbol.toLowerCase());
  }
  code.write(pickOne(random, _codeSeparators));
  return code.toString();
}

String randomBadPairingCode(Random random) {
  final String validCode = randomValidPairingCode(random);
  switch (random.nextInt(3)) {
    case 0:
      return '$validCode${_crockfordSymbols[random.nextInt(10)]}';
    case 1:
      return validCode
          .replaceAll(RegExp('[0-9A-Za-z]'), '')
          .padRight(random.nextInt(_codeLength), '7');
    default:
      final int cut = random.nextInt(validCode.length + 1);
      final String foreign = pickOne(random, _foreignSymbols);
      return '${validCode.substring(0, cut)}$foreign'
          '${validCode.substring(cut)}';
  }
}

Finder findPairingButton(String label) {
  return find.widgetWithText(AppButton, label);
}

VoidCallback? readButtonCallback(WidgetTester tester, String label) {
  return tester.widget<AppButton>(findPairingButton(label)).onPressed;
}
