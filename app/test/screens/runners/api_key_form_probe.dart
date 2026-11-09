import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/screens/runners/api_key_form.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

final class KeyFormProbe {
  final List<String> savedKeys = <String>[];
  int cancels = 0;
  Completer<void>? pendingSave;

  Future<void> save(String apiKey) async {
    savedKeys.add(apiKey);
    final Completer<void>? pending = pendingSave;
    if (pending != null) {
      await pending.future;
    }
  }

  void cancel() {
    cancels += 1;
  }
}

Future<KeyFormProbe> pumpApiKeyForm(WidgetTester tester, Random random) async {
  final KeyFormProbe probe = KeyFormProbe();
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: ApiKeyForm(
      key: UniqueKey(),
      onSave: probe.save,
      onCancel: probe.cancel,
    ),
  );
  return probe;
}

String readApiKeyField(WidgetTester tester) {
  final TextField field = tester.widget<TextField>(
    findFieldInput(apiKeyFieldLabel),
  );
  final TextEditingController? controller = field.controller;
  if (controller == null) {
    throw StateError('the key field has no controller');
  }
  return controller.text;
}

Future<void> tapApiKeyFormButton(WidgetTester tester, String label) async {
  await tapVisible(tester, find.widgetWithText(AppButton, label));
  await tester.pump();
}
