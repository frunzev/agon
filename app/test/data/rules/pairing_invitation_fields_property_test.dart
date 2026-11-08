import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/rules/pairing_invitation.dart';

import '../../support/random_inputs.dart';
import 'pairing_invitation_test.dart' show randomInvitation;

const Set<String> _invitationFields = <String>{'v', 'code', 'server'};
final RegExp _whiteSpace = RegExp(r'\s');

void main() {
  test('test_encode_pairing_invitation_property_has_only_three_fields', () {
    final Random random = seededRandom(88001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingInvitation invitation = randomInvitation(random);

      final String link = encodePairingInvitation(invitation);

      final Uri parsed = Uri.parse(link);
      expect(parsed.queryParameters.keys.toSet(), _invitationFields);
      expect(parsed.queryParameters['code'], invitation.code);
      expect(link.contains(_whiteSpace), isFalse, reason: link);
    }
  });
}
