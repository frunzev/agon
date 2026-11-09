import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/rules/pairing_invitation.dart';
import 'package:agent_orchestration/screens/pairing/pairing_qr_code.dart';

import '../../data/rules/pairing_invitation_test.dart' show randomInvitation;
import '../../support/random_inputs.dart';
import '../../support/random_repository_addresses.dart';
import '../../support/widget_harness.dart';

const double _qrCodeExtent = 192;
const double _pictureExtent = 120;
const String _codeSymbols = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const String _peerKeySymbols = '0123456789abcdef';
const int _codeHalfLength = 3;
const int _peerKeyLength = 64;
const int _largestPort = 65535;

String _randomPairingCode(Random random) {
  final String start = randomCharacters(random, _codeSymbols, _codeHalfLength);
  final String end = randomCharacters(random, _codeSymbols, _codeHalfLength);
  return '$start-$end';
}

String _randomServerAddress(Random random) {
  final String host = randomRepositoryHost(random);
  return switch (random.nextInt(3)) {
    0 => 'https://$host',
    1 => 'http://$host:${1 + random.nextInt(_largestPort)}',
    _ => 'peer://${randomCharacters(random, _peerKeySymbols, _peerKeyLength)}',
  };
}

PairingInvitation _randomShownInvitation(Random random) {
  if (random.nextInt(3) == 0) {
    return randomInvitation(random);
  }
  return PairingInvitation(
    code: _randomPairingCode(random),
    serverAddress: _randomServerAddress(random),
  );
}

Future<void> _pumpQrCode(
  WidgetTester tester,
  Random random,
  PairingInvitation invitation,
) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: PairingQrCode(invitation: invitation),
  );
  expect(tester.takeException(), isNull, reason: 'width $width');
}

QrPainter _findShownPainter(WidgetTester tester) {
  final Finder qrPaint = find.byWidgetPredicate(
    (Widget widget) => widget is CustomPaint && widget.painter is QrPainter,
  );
  final CustomPaint paint = tester.widget<CustomPaint>(qrPaint);
  return paint.painter! as QrPainter;
}

QrPainter _drawLike(QrPainter shown, String payload) {
  return QrPainter(
    data: payload,
    version: shown.version,
    errorCorrectionLevel: shown.errorCorrectionLevel,
    gapless: shown.gapless,
    eyeStyle: shown.eyeStyle,
    dataModuleStyle: shown.dataModuleStyle,
  );
}

Future<List<int>> _readPixels(WidgetTester tester, QrPainter painter) async {
  final ByteData? picture = await tester.runAsync<ByteData?>(
    () => painter.toImageData(_pictureExtent),
  );
  return picture!.buffer.asUint8List();
}

void main() {
  test('test_pairing_qr_code_new_property_keeps_the_invitation', () {
    final Random random = seededRandom(104401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingInvitation invitation = _randomShownInvitation(random);

      final PairingQrCode widget = PairingQrCode(invitation: invitation);

      expect(widget.invitation.code, invitation.code);
      expect(widget.invitation.serverAddress, invitation.serverAddress);
    }
  });

  test('test_pairing_qr_code_new_property_keeps_its_key', () {
    final Random random = seededRandom(104402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ValueKey<int> key = ValueKey<int>(random.nextInt(1 << 30));

      final PairingQrCode widget = PairingQrCode(
        invitation: _randomShownInvitation(random),
        key: key,
      );

      expect(widget.key, key);
    }
  });

  testWidgets('test_pairing_qr_code_new_property_equal_invitations_draw_'
      'equal_codes', (WidgetTester tester) async {
    final Random random = seededRandom(104403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingInvitation invitation = _randomShownInvitation(random);
      final PairingInvitation copy = PairingInvitation(
        code: invitation.code,
        serverAddress: invitation.serverAddress,
      );

      await _pumpQrCode(tester, random, invitation);
      final List<int> first = await _readPixels(
        tester,
        _findShownPainter(tester),
      );
      await _pumpQrCode(tester, random, copy);
      final List<int> second = await _readPixels(
        tester,
        _findShownPainter(tester),
      );

      expect(second, first);
    }
  });

  testWidgets('test_pairing_qr_code_build_property_scanned_payload_decodes_'
      'to_the_invitation', (WidgetTester tester) async {
    final Random random = seededRandom(104404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingInvitation invitation = _randomShownInvitation(random);
      final String payload = encodePairingInvitation(invitation);

      await _pumpQrCode(tester, random, invitation);

      final QrPainter shown = _findShownPainter(tester);
      final List<int> shownPixels = await _readPixels(tester, shown);
      final List<int> payloadPixels = await _readPixels(
        tester,
        _drawLike(shown, payload),
      );
      expect(shownPixels, payloadPixels);
      final PairingInvitation scanned = decodePairingInvitation(payload);
      expect(scanned.code, invitation.code);
      expect(scanned.serverAddress, invitation.serverAddress);
    }
  });

  testWidgets('test_pairing_qr_code_build_property_names_the_code_for_'
      'screen_readers', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final Random random = seededRandom(104405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingInvitation invitation = PairingInvitation(
        code: _randomPairingCode(random),
        serverAddress: _randomServerAddress(random),
      );

      await _pumpQrCode(tester, random, invitation);

      expect(
        find.bySemanticsLabel('QR code for ${invitation.code}'),
        findsOneWidget,
      );
    }
    semantics.dispose();
  });

  testWidgets('test_pairing_qr_code_build_property_different_invitations_'
      'draw_different_squares_of_one_size', (WidgetTester tester) async {
    final Random random = seededRandom(104406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingInvitation invitation = _randomShownInvitation(random);
      final PairingInvitation other = PairingInvitation(
        code: '${invitation.code}9',
        serverAddress: invitation.serverAddress,
      );

      await _pumpQrCode(tester, random, invitation);
      final QrPainter shown = _findShownPainter(tester);
      final List<int> shownPixels = await _readPixels(tester, shown);
      final List<int> otherPixels = await _readPixels(
        tester,
        _drawLike(shown, encodePairingInvitation(other)),
      );

      expect(shownPixels, isNot(otherPixels));
      expect(
        tester.getSize(find.byType(PairingQrCode)),
        const Size.square(_qrCodeExtent),
      );
    }
  });
}
