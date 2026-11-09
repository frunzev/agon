import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/screens/pairing/fingerprint_words.dart';
import 'package:agent_orchestration/screens/setup/pairing_code_entry_screen.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'pairing_code_entry_probe.dart';

const String _scanLabel = 'Scan QR code';
const int _largestKeyNumber = 1000;
const int _fingerprintWordCount = 4;

WaitingJoin _randomWaitingJoin(Random random) {
  return WaitingJoin(
    code: randomValidPairingCode(random),
    fingerprintWords: <String>[
      for (int i = 0; i < _fingerprintWordCount; i += 1)
        'word$i${random.nextInt(_largestKeyNumber)}',
    ],
  );
}

void main() {
  test('test_pairing_code_entry_screen_constructor_property_keeps_every_'
      'field', () {
    final Random random = seededRandom(111004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = randomPairingCodeEntryProbe(random);

      final PairingCodeEntryScreen screen = probe.build();

      expect(screen.role, probe.role);
      expect(screen.deviceKind, probe.deviceKind);
      expect(screen.deviceName, probe.deviceName);
      expect(
        screen.scanner,
        probe.offersScanning ? same(probe.scanner) : null,
      );
      expect(screen.hostAppServer != null, probe.offersHosting);
      expect(screen.pairingRepository, same(probe.repository));
      expect(screen.navigation, same(probe.navigation));
    }
  });

  test('test_pairing_code_entry_screen_constructor_property_keeps_the_'
      'key', () {
    final Random random = seededRandom(111005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = randomPairingCodeEntryProbe(random);
      final Key key = ValueKey<int>(random.nextInt(_largestKeyNumber));

      final PairingCodeEntryScreen screen = PairingCodeEntryScreen(
        role: probe.role,
        deviceKind: probe.deviceKind,
        deviceName: probe.deviceName,
        scanner: null,
        hostAppServer: null,
        pairingRepository: probe.repository,
        navigation: probe.navigation,
        key: key,
      );

      expect(screen.key, key);
    }
  });

  test('test_pairing_code_entry_screen_constructor_property_starts_'
      'nothing', () {
    final Random random = seededRandom(111006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = randomPairingCodeEntryProbe(random);

      probe.build();

      expect(probe.hostingRequests, 0);
      expect(probe.scanner.scanCount, 0);
      expect(probe.repository.joinedCodes, isEmpty);
      expect(probe.repository.isFollowed, isFalse);
    }
  });

  test('test_pairing_code_entry_screen_create_state_property_fresh_state_'
      'per_call', () {
    final Random random = seededRandom(111007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingCodeEntryScreen screen = randomPairingCodeEntryProbe(random)
          .build();

      final State<PairingCodeEntryScreen> first = screen.createState();
      final State<PairingCodeEntryScreen> second = screen.createState();

      expect(first, isNot(same(second)));
      expect(first.mounted, isFalse);
    }
  });

  testWidgets('test_pairing_code_entry_screen_create_state_property_starts_'
      'with_an_empty_code', (WidgetTester tester) async {
    final Random random = seededRandom(111008);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = randomPairingCodeEntryProbe(random);
      await pumpPairingCodeEntry(tester, random, probe);

      final EditableText codeInput = tester.widget<EditableText>(
        find.descendant(
          of: findFieldInput(pairingCodeLabel),
          matching: find.byType(EditableText),
        ),
      );

      expect(codeInput.controller.text, isEmpty);
      expect(readButtonCallback(tester, probe.pairLabel), isNotNull);
    }
  });

  testWidgets('test_pairing_code_entry_screen_create_state_property_'
      'mounted_state_reads_its_screen', (WidgetTester tester) async {
    final Random random = seededRandom(111009);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = randomPairingCodeEntryProbe(random);
      await pumpPairingCodeEntry(tester, random, probe);

      final State<PairingCodeEntryScreen> state = tester.state(
        find.byType(PairingCodeEntryScreen),
      );

      expect(state.mounted, isTrue);
      expect(state.widget.pairingRepository, same(probe.repository));
    }
  });

  testWidgets('test_pairing_code_entry_screen_build_property_offers_only_'
      'what_it_was_given', (WidgetTester tester) async {
    final Random random = seededRandom(111010);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = randomPairingCodeEntryProbe(random);
      await pumpPairingCodeEntry(tester, random, probe);

      expect(tester.takeException(), isNull);
      expect(find.text('Enter the pairing code'), findsOneWidget);
      expect(find.text(probe.pairLabel), findsOneWidget);
      expect(
        find.text(_scanLabel),
        findsNWidgets(probe.offersScanning ? 1 : 0),
      );
      expect(
        find.text(makeThisComputerTheServerLabel),
        findsNWidgets(probe.offersHosting ? 1 : 0),
      );
      expect(
        find.text(noOtherDevicesText),
        findsNWidgets(probe.offersHosting ? 1 : 0),
      );
    }
  });

  testWidgets('test_pairing_code_entry_screen_build_property_words_follow_'
      'the_waiting_join', (WidgetTester tester) async {
    final Random random = seededRandom(111011);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = randomPairingCodeEntryProbe(random);
      await pumpPairingCodeEntry(tester, random, probe);
      final WaitingJoin join = _randomWaitingJoin(random);

      probe.repository.showWaitingJoin(join);
      await tester.pump();
      final FingerprintWords shown = tester.widget<FingerprintWords>(
        find.byType(FingerprintWords),
      );
      probe.repository.showWaitingJoin(null);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(shown.words, join.fingerprintWords);
      expect(find.byType(FingerprintWords), findsNothing);
    }
  });

  testWidgets('test_pairing_code_entry_screen_build_property_scanning_'
      'nothing_keeps_the_typed_code', (WidgetTester tester) async {
    final Random random = seededRandom(111012);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = PairingCodeEntryProbe(
        random,
        offersScanning: true,
        offersHosting: random.nextBool(),
      );
      await pumpPairingCodeEntry(tester, random, probe);
      final String typedCode = randomValidPairingCode(random);
      await enterFieldText(tester, label: pairingCodeLabel, text: typedCode);

      await tapVisible(tester, find.text(_scanLabel));
      await tester.pump();

      expect(probe.scanner.scanCount, 1);
      expect(findFieldText(pairingCodeLabel, typedCode), findsOneWidget);
    }
  });

  testWidgets('test_pairing_code_entry_screen_dispose_property_leaving_'
      'stops_following_pairing', (WidgetTester tester) async {
    final Random random = seededRandom(111013);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = randomPairingCodeEntryProbe(random);
      await pumpPairingCodeEntry(tester, random, probe);
      final bool wasFollowed = probe.repository.isFollowed;

      await tester.pumpWidget(const SizedBox.shrink());
      probe.repository.showWaitingJoin(_randomWaitingJoin(random));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(wasFollowed, isTrue);
      expect(probe.repository.isFollowed, isFalse);
    }
  });

  testWidgets('test_pairing_code_entry_screen_dispose_property_leaving_'
      'while_typing_is_quiet', (WidgetTester tester) async {
    final Random random = seededRandom(111014);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = randomPairingCodeEntryProbe(random);
      await pumpPairingCodeEntry(tester, random, probe);
      await enterFieldText(
        tester,
        label: pairingCodeLabel,
        text: randomText(random),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(probe.repository.joinedCodes, isEmpty);
    }
  });
}
