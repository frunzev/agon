import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/screens/runners/api_key_form.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'api_key_form_probe.dart';

Future<void> _ignoreKey(String apiKey) async {}

void _ignoreCancel() {}

void main() {
  test('test_api_key_form_constructor_property_keeps_every_field', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(i);

      final ApiKeyForm form = ApiKeyForm(
        onSave: _ignoreKey,
        onCancel: _ignoreCancel,
        key: key,
      );

      expect(form.onSave, _ignoreKey);
      expect(form.onCancel, _ignoreCancel);
      expect(form.key, key);
    }
  });

  testWidgets('test_api_key_form_constructor_property_cancel_reaches_only_'
      'the_cancel_callback', (WidgetTester tester) async {
    final Random random = seededRandom(108301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final KeyFormProbe probe = await pumpApiKeyForm(tester, random);
      await enterFieldText(
        tester,
        label: apiKeyFieldLabel,
        text: randomHostileText(random),
      );
      final int taps = 1 + random.nextInt(3);

      for (int tap = 0; tap < taps; tap += 1) {
        await tapApiKeyFormButton(tester, cancelLabel);
      }

      expect(probe.cancels, taps);
      expect(probe.savedKeys, isEmpty);
    }
  });

  testWidgets('test_api_key_form_constructor_property_save_reaches_only_'
      'the_save_callback', (WidgetTester tester) async {
    final Random random = seededRandom(108302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final KeyFormProbe probe = await pumpApiKeyForm(tester, random);

      await tapApiKeyFormButton(tester, saveKeyLabel);

      expect(probe.savedKeys, <String>['']);
      expect(probe.cancels, 0);
    }
  });

  test('test_api_key_form_create_state_property_each_call_is_a_fresh_'
      'state', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      const ApiKeyForm form = ApiKeyForm(
        onSave: _ignoreKey,
        onCancel: _ignoreCancel,
      );

      final State<ApiKeyForm> first = form.createState();
      final State<ApiKeyForm> second = form.createState();

      expect(identical(first, second), isFalse);
      expect(first.mounted, isFalse);
    }
  });

  testWidgets('test_api_key_form_create_state_property_a_new_form_starts_'
      'empty', (WidgetTester tester) async {
    final Random random = seededRandom(108303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpApiKeyForm(tester, random);
      await enterFieldText(
        tester,
        label: apiKeyFieldLabel,
        text: 'sk-${randomText(random)}',
      );

      await pumpApiKeyForm(tester, random);

      expect(readApiKeyField(tester), isEmpty);
    }
  });

  testWidgets('test_api_key_form_create_state_property_the_typed_key_'
      'survives_rebuilds', (WidgetTester tester) async {
    final Random random = seededRandom(108304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpApiKeyForm(tester, random);
      await enterFieldText(
        tester,
        label: apiKeyFieldLabel,
        text: 'sk-${randomText(random)}',
      );
      final String typed = readApiKeyField(tester);

      tester.element(find.byType(ApiKeyForm)).markNeedsBuild();
      await tester.pump();

      expect(readApiKeyField(tester), typed);
    }
  });

  testWidgets('test_api_key_form_dispose_property_removal_is_quiet', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108305);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpApiKeyForm(tester, random);
      await enterFieldText(
        tester,
        label: apiKeyFieldLabel,
        text: randomHostileText(random),
      );

      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isNull);
      expect(find.byType(ApiKeyForm), findsNothing);
    }
  });

  testWidgets('test_api_key_form_dispose_property_a_save_ending_after_'
      'removal_is_quiet', (WidgetTester tester) async {
    final Random random = seededRandom(108306);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final KeyFormProbe probe = await pumpApiKeyForm(tester, random);
      final Completer<void> pending = Completer<void>();
      probe.pendingSave = pending;
      await tapApiKeyFormButton(tester, saveKeyLabel);

      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(probe.savedKeys, hasLength(1));
    }
  });

  testWidgets('test_api_key_form_dispose_property_removal_stops_callbacks', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108307);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final KeyFormProbe probe = await pumpApiKeyForm(tester, random);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(probe.savedKeys, isEmpty);
      expect(probe.cancels, 0);
    }
  });
}
