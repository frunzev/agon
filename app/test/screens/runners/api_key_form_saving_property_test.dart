import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/agent_login_text.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'api_key_form_probe.dart';

void main() {
  testWidgets('test_api_key_form_build_property_shows_the_design_wording_'
      'at_any_width', (WidgetTester tester) async {
    final Random random = seededRandom(108401);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpApiKeyForm(tester, random);

      expect(tester.takeException(), isNull);
      expect(find.text('Anthropic API key'), findsOneWidget);
      expect(
        find.text(
          'Each container gets it as ANTHROPIC_API_KEY. It stays on this '
          'computer.',
        ),
        findsOneWidget,
      );
      expect(find.text('Save key'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    }
  });

  testWidgets('test_api_key_form_build_property_the_key_stays_hidden', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpApiKeyForm(tester, random);
      await enterFieldText(
        tester,
        label: apiKeyFieldLabel,
        text: 'sk-ant-${randomText(random)}',
      );

      final TextField field = tester.widget<TextField>(
        findFieldInput(apiKeyFieldLabel),
      );
      expect(field.obscureText, isTrue);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.maxLines, 1);
    }
  });

  testWidgets('test_api_key_form_build_property_enter_saves_like_the_'
      'button', (WidgetTester tester) async {
    final Random random = seededRandom(108403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final KeyFormProbe probe = await pumpApiKeyForm(tester, random);
      await enterFieldText(
        tester,
        label: apiKeyFieldLabel,
        text: randomHostileText(random),
      );
      final String typed = readApiKeyField(tester);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(probe.savedKeys, <String>[typed]);
    }
  });

  testWidgets('test_api_key_form_save_property_sends_the_typed_text_'
      'verbatim', (WidgetTester tester) async {
    final Random random = seededRandom(108404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final KeyFormProbe probe = await pumpApiKeyForm(tester, random);
      final String text =
          '${randomHostileText(random)} '
          '${randomHostileText(random)}';
      await enterFieldText(tester, label: apiKeyFieldLabel, text: text);
      final String typed = readApiKeyField(tester);

      await tapApiKeyFormButton(tester, saveKeyLabel);

      expect(probe.savedKeys, <String>[typed]);
    }
  });

  testWidgets('test_api_key_form_save_property_each_press_saves_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final KeyFormProbe probe = await pumpApiKeyForm(tester, random);
      await enterFieldText(
        tester,
        label: apiKeyFieldLabel,
        text: 'sk-${randomText(random)}',
      );
      final String typed = readApiKeyField(tester);
      final int presses = 1 + random.nextInt(3);

      for (int press = 0; press < presses; press += 1) {
        await tapApiKeyFormButton(tester, saveKeyLabel);
      }

      expect(probe.savedKeys, List<String>.filled(presses, typed));
    }
  });

  testWidgets('test_api_key_form_save_property_keeps_the_field_for_a_'
      'retry', (WidgetTester tester) async {
    final Random random = seededRandom(108406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpApiKeyForm(tester, random);
      await enterFieldText(
        tester,
        label: apiKeyFieldLabel,
        text: randomHostileText(random),
      );
      final String typed = readApiKeyField(tester);

      await tapApiKeyFormButton(tester, saveKeyLabel);

      expect(readApiKeyField(tester), typed);
    }
  });
}
