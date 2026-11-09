import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/new_items/change_request_composer.dart';

import '../../support/random_inputs.dart';

const List<String> unicodeWhiteSpaceCharacters = <String>[
  '\t',
  '\n',
  '\u000B',
  '\u000C',
  '\r',
  ' ',
  '\u0085',
  '\u00A0',
  '\u1680',
  '\u2000',
  '\u2005',
  '\u200A',
  '\u2028',
  '\u2029',
  '\u202F',
  '\u205F',
  '\u3000',
];

String randomBlankNote(Random random) {
  final StringBuffer note = StringBuffer();
  for (int index = 0; index <= random.nextInt(4); index += 1) {
    note.write(pickOne(random, unicodeWhiteSpaceCharacters));
  }
  return note.toString();
}

String randomChangeNote(Random random) {
  final String blank = randomBlankNote(random);
  return '$blank${randomWordPhrase(random)}x${randomText(random)}$blank';
}

Widget buildComposerPage(ChangeRequestComposer composer) {
  return SingleChildScrollView(child: composer);
}

Future<void> typeChangeNote(WidgetTester tester, String note) async {
  await tester.enterText(find.byType(TextField), note);
  await tester.pump();
}

String readShownChangeNote(WidgetTester tester) {
  final TextField field = tester.widget(find.byType(TextField));
  return field.controller!.text;
}
