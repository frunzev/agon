import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/audit_repository.dart';
import 'package:agent_orchestration/screens/settings/audit_log_tab.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/node_json_primitives.dart';
import '../../support/random_inputs.dart';
import '../../support/runner_pages.dart';
import 'runner_settings_screen_checks.dart';

typedef ChainCheckAnswer = Future<ChainSummary> Function();

const String auditGenesisHash =
    '0000000000000000000000000000000000000000000000000000000000000000';
const int _mostEntries = 40;
const int _largestAgeMinutes = 20000;

final class ScriptedAuditRepository extends ChangeNotifier
    implements AuditRepository {
  ScriptedAuditRepository({required List<AuditEntry> entries})
    : _entries = List<AuditEntry>.unmodifiable(entries);

  List<AuditEntry> _entries;
  int verifyCount = 0;
  ChainCheckAnswer? plannedAnswer;

  bool get isListenedTo => hasListeners;

  @override
  List<AuditEntry> listEntries() => _entries;

  @override
  Future<ChainSummary> verifyChain() async {
    verifyCount += 1;
    final ChainCheckAnswer? answer = plannedAnswer;
    if (answer != null) {
      return answer();
    }
    return summarizeAuditChain(_entries);
  }

  void replaceEntries(List<AuditEntry> entries) {
    _entries = List<AuditEntry>.unmodifiable(entries);
    notifyListeners();
  }

  void announceWithoutChange() {
    notifyListeners();
  }
}

ChainSummary summarizeAuditChain(List<AuditEntry> entries) {
  if (entries.isEmpty) {
    return const ChainSummary(entryCount: 0, headHash: auditGenesisHash);
  }
  return ChainSummary(
    entryCount: entries.first.index + 1,
    headHash: entries.first.hash,
  );
}

String randomAuditHash(Random random) {
  return '${randomDeviceIdText(random)}${randomDeviceIdText(random)}';
}

DeviceId _randomAuditDevice(Random random) {
  if (random.nextInt(4) == 0) {
    return DeviceId(randomDeviceIdText(random));
  }
  final Device device = pickOne(random, galleryDevices);
  return device.id;
}

AuditEntry buildNextAuditEntry(Random random, List<AuditEntry> newestFirst) {
  final bool isFirst = newestFirst.isEmpty;
  return AuditEntry(
    index: isFirst ? 0 : newestFirst.first.index + 1,
    at: galleryNow.subtract(
      Duration(minutes: random.nextInt(_largestAgeMinutes)),
    ),
    deviceId: _randomAuditDevice(random),
    event: 'Event ${newestFirst.length} ${randomHostileText(random)}',
    detail: randomHostileText(random),
    previousHash: isFirst ? auditGenesisHash : newestFirst.first.hash,
    hash: randomAuditHash(random),
  );
}

List<AuditEntry> randomAuditChain(Random random, {required int length}) {
  List<AuditEntry> newestFirst = <AuditEntry>[];
  for (int i = 0; i < length; i += 1) {
    newestFirst = <AuditEntry>[
      buildNextAuditEntry(random, newestFirst),
      ...newestFirst,
    ];
  }
  return newestFirst;
}

List<AuditEntry> randomNonEmptyAuditChain(Random random) {
  return randomAuditChain(random, length: 1 + random.nextInt(_mostEntries));
}

AuditLogTab buildAuditLogTab(AuditRepository auditRepository) {
  return AuditLogTab(
    auditRepository: auditRepository,
    deviceRepository: buildRunnerDevices(peerAddressProblem: null),
    clock: FixedClock(galleryNow),
  );
}

Future<double> pumpAuditLogTab(
  WidgetTester tester,
  Random random,
  AuditRepository auditRepository,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final double width = await pumpAtRandomWidth(
    tester,
    random,
    buildAuditLogTab(auditRepository),
  );
  await tester.pump();
  return width;
}

List<String> readAuditTexts(WidgetTester tester) {
  return readShownTexts(tester, find.byType(AuditLogTab));
}
