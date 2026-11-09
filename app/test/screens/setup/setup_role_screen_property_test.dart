import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/screens/setup/server_hosting.dart';
import 'package:agent_orchestration/screens/setup/setup_role_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const List<String> _deviceKinds = <String>['Mac', 'PC', 'computer', 'phone'];
const int _largestKeyNumber = 1000;
const Map<DeviceRole, (String, String)> _designedMacChoices =
    <DeviceRole, (String, String)>{
      DeviceRole.clientAndRunner: (
        'Client and runner',
        'Use the app here and run tasks on this Mac too.',
      ),
      DeviceRole.client: (
        'Client only',
        'Start workflows, chat with agents and approve what they do.',
      ),
      DeviceRole.runner: (
        'Runner only',
        'Run tasks for your other devices, each in its own sandbox.',
      ),
    };

List<DeviceRole> _randomOfferedRoles(Random random) {
  return listSetupRoles(pickOne(random, TargetPlatform.values));
}

final class _RoleScreenProbe {
  _RoleScreenProbe(Random random)
    : deviceKind = pickOne(random, _deviceKinds),
      roles = _randomOfferedRoles(random);

  final String deviceKind;
  final List<DeviceRole> roles;
  final AppNavigation navigation = AppNavigation(
    initialRoute: const SetupRoleRoute(),
  );

  SetupRoleScreen build() {
    return SetupRoleScreen(
      deviceKind: deviceKind,
      roles: roles,
      navigation: navigation,
    );
  }
}

Future<_RoleScreenProbe> _pumpRoleScreen(
  WidgetTester tester,
  Random random,
) async {
  final _RoleScreenProbe probe = _RoleScreenProbe(random);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: probe.build(),
  );
  return probe;
}

String _titleOf(DeviceRole role, String deviceKind) {
  return describeSetupRoleChoice(role: role, deviceKind: deviceKind).title;
}

void main() {
  test('test_describe_setup_role_choice_property_value_is_the_role_and_'
      'titles_differ', () {
    final Random random = seededRandom(110801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String deviceKind = randomText(random);
      final Set<String> titles = <String>{};
      for (final DeviceRole role in DeviceRole.values) {
        final ChoiceOption<DeviceRole> choice = describeSetupRoleChoice(
          role: role,
          deviceKind: deviceKind,
        );
        expect(choice.value, role);
        titles.add(choice.title);
      }

      expect(titles, hasLength(DeviceRole.values.length));
    }
  });

  test('test_describe_setup_role_choice_property_only_the_device_kind_'
      'changes', () {
    final Random random = seededRandom(110802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String deviceKind = 'kind ${randomText(random)}';
      final DeviceRole role = pickOne(random, DeviceRole.values);
      final ChoiceOption<DeviceRole> choice = describeSetupRoleChoice(
        role: role,
        deviceKind: deviceKind,
      );
      final ChoiceOption<DeviceRole> onMac = describeSetupRoleChoice(
        role: role,
        deviceKind: 'Mac',
      );

      expect(choice.title, onMac.title);
      expect(choice.detail, onMac.detail.replaceAll('Mac', deviceKind));
    }
  });

  test('test_describe_setup_role_choice_property_matches_the_design', () {
    for (final DeviceRole role in DeviceRole.values) {
      final ChoiceOption<DeviceRole> choice = describeSetupRoleChoice(
        role: role,
        deviceKind: 'Mac',
      );
      final (String, String) designed = _designedMacChoices[role]!;

      expect((choice.title, choice.detail), designed);
    }
  });

  test('test_setup_role_screen_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(110803);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RoleScreenProbe probe = _RoleScreenProbe(random);
      final Key key = ValueKey<int>(random.nextInt(_largestKeyNumber));

      final SetupRoleScreen screen = SetupRoleScreen(
        deviceKind: probe.deviceKind,
        roles: probe.roles,
        navigation: probe.navigation,
        key: key,
      );

      expect(screen.deviceKind, probe.deviceKind);
      expect(screen.roles, same(probe.roles));
      expect(screen.navigation, same(probe.navigation));
      expect(screen.key, key);
    }
  });

  test('test_setup_role_screen_constructor_property_opens_nothing', () {
    final Random random = seededRandom(110804);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RoleScreenProbe probe = _RoleScreenProbe(random);

      probe.build();

      expect(probe.navigation.routes, const <AppRoute>[SetupRoleRoute()]);
    }
  });

  test('test_setup_role_screen_create_state_property_fresh_state_per_'
      'call', () {
    final Random random = seededRandom(110805);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SetupRoleScreen screen = _RoleScreenProbe(random).build();

      final State<SetupRoleScreen> first = screen.createState();
      final State<SetupRoleScreen> second = screen.createState();

      expect(first, isNot(same(second)));
      expect(first.mounted, isFalse);
    }
  });

  test('test_setup_role_screen_constructor_property_takes_any_offered_'
      'role_list', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final List<DeviceRole> roles = listSetupRoles(platform);

      final SetupRoleScreen screen = SetupRoleScreen(
        deviceKind: 'Mac',
        roles: roles,
        navigation: AppNavigation(initialRoute: const SetupRoleRoute()),
      );

      expect(screen.roles, roles);
    }
  });

  testWidgets('test_setup_role_screen_create_state_property_starts_on_the_'
      'first_role', (WidgetTester tester) async {
    final Random random = seededRandom(110810);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RoleScreenProbe probe = await _pumpRoleScreen(tester, random);

      final ChoiceListField<DeviceRole> choices = tester
          .widget<ChoiceListField<DeviceRole>>(
            find.byType(ChoiceListField<DeviceRole>),
          );

      expect(choices.selected, probe.roles.first);
    }
  });

  testWidgets('test_setup_role_screen_create_state_property_mounted_state_'
      'reads_its_screen', (WidgetTester tester) async {
    final Random random = seededRandom(110806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RoleScreenProbe probe = await _pumpRoleScreen(tester, random);

      final State<SetupRoleScreen> state = tester.state(
        find.byType(SetupRoleScreen),
      );

      expect(state.mounted, isTrue);
      expect(state.widget.roles, same(probe.roles));
    }
  });

  testWidgets('test_setup_role_screen_build_property_shows_every_offered_'
      'role_at_any_width', (WidgetTester tester) async {
    final Random random = seededRandom(110807);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RoleScreenProbe probe = await _pumpRoleScreen(tester, random);

      expect(tester.takeException(), isNull);
      expect(
        find.text('How will this ${probe.deviceKind} be used?'),
        findsOneWidget,
      );
      for (final DeviceRole role in DeviceRole.values) {
        expect(
          find.text(_titleOf(role, probe.deviceKind)),
          findsNWidgets(probe.roles.contains(role) ? 1 : 0),
        );
      }
    }
  });

  testWidgets('test_setup_role_screen_build_property_continue_uses_the_'
      'first_role_by_default', (WidgetTester tester) async {
    final Random random = seededRandom(110808);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RoleScreenProbe probe = await _pumpRoleScreen(tester, random);

      await tapVisible(tester, find.text('Continue'));
      await tester.pump();

      expect(probe.navigation.routes, <AppRoute>[
        const SetupRoleRoute(),
        PairingCodeEntryRoute(probe.roles.first),
      ]);
    }
  });

  testWidgets('test_setup_role_screen_build_property_continue_uses_the_'
      'last_chosen_role', (WidgetTester tester) async {
    final Random random = seededRandom(110809);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RoleScreenProbe probe = await _pumpRoleScreen(tester, random);
      DeviceRole chosen = probe.roles.first;
      final int choiceCount = 1 + random.nextInt(probe.roles.length + 1);
      for (int j = 0; j < choiceCount; j += 1) {
        chosen = pickOne(random, probe.roles);
        await tapVisible(
          tester,
          find.text(_titleOf(chosen, probe.deviceKind)),
        );
        await tester.pump();
      }

      await tapVisible(tester, find.text('Continue'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(probe.navigation.currentRoute, PairingCodeEntryRoute(chosen));
    }
  });
}
