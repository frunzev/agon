import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/shared/agent_login_pointer.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

const List<String> _loginProblemMarks = <String>[
  'Not logged in',
  'Please run /login',
];
const int _largestIdNumber = 100000;

final DeviceRepository _devices = buildGalleryDependencies().deviceRepository;
final DeviceId _thisDevice = _devices.currentDevice().id;

String _randomLoginProblem(Random random) {
  return '${randomText(random)} ${pickOne(random, _loginProblemMarks)} '
      '${randomText(random)}';
}

AppNavigation _randomNavigation(Random random) {
  if (random.nextBool()) {
    return AppNavigation.limitedToRunPages(
      runId: RunId('run-${random.nextInt(_largestIdNumber)}'),
    );
  }
  return AppNavigation(
    initialRoute: SectionRoute(pickOne(random, AppSection.values)),
  );
}

DeviceId _randomOtherRunner(Random random) {
  final List<DeviceId> others = <DeviceId>[
    for (final Device device in _devices.listDevices())
      if (device.id != _thisDevice) device.id,
    DeviceId('removed-${random.nextInt(_largestIdNumber)}'),
  ];
  return pickOne(random, others);
}

AgentLoginPointer _pointAtThisComputer(
  AppNavigation navigation,
  Random random,
) {
  return pointToAgentLogin(
    reason: _randomLoginProblem(random),
    runner: _thisDevice,
    deviceRepository: _devices,
    navigation: navigation,
  )!;
}

void main() {
  test('test_agent_login_pointer_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(111101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String hint = randomHostileText(random);
      final VoidCallback? onConnect = random.nextBool() ? () {} : null;

      final AgentLoginPointer pointer = AgentLoginPointer(
        hint: hint,
        onConnect: onConnect,
      );

      expect(pointer.hint, hint);
      expect(pointer.onConnect, same(onConnect));
    }
  });

  test('test_agent_login_pointer_constructor_property_connect_runs_the_'
      'given_action', () {
    final Random random = seededRandom(111102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> calls = <int>[];
      final AgentLoginPointer pointer = AgentLoginPointer(
        hint: randomText(random),
        onConnect: () => calls.add(i),
      );

      pointer.onConnect!();

      expect(calls, <int>[i]);
    }
  });

  test('test_agent_login_pointer_constructor_property_is_const_'
      'canonical', () {
    const AgentLoginPointer first = AgentLoginPointer(
      hint: thisComputerLoginHint,
      onConnect: null,
    );
    const AgentLoginPointer second = AgentLoginPointer(
      hint: thisComputerLoginHint,
      onConnect: null,
    );

    expect(first, same(second));
  });

  test('test_point_to_agent_login_property_needs_a_login_problem_and_a_'
      'runner', () {
    final Random random = seededRandom(111103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool hasLoginProblem = random.nextBool();
      final bool hasRunner = random.nextBool();
      final String? reason = hasLoginProblem
          ? _randomLoginProblem(random)
          : pickOne(random, <String?>[
              null,
              'Exit code ${randomText(random)}',
            ]);

      final AgentLoginPointer? pointer = pointToAgentLogin(
        reason: reason,
        runner: hasRunner ? _randomOtherRunner(random) : null,
        deviceRepository: _devices,
        navigation: _randomNavigation(random),
      );

      expect(pointer != null, hasLoginProblem && hasRunner);
    }
  });

  test('test_point_to_agent_login_property_this_computer_gets_its_own_'
      'hint', () {
    final Random random = seededRandom(111104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginPointer pointer = _pointAtThisComputer(
        _randomNavigation(random),
        random,
      );

      expect(pointer.hint, thisComputerLoginHint);
    }
  });

  test('test_point_to_agent_login_property_other_runners_are_named_never_'
      'connected', () {
    final Random random = seededRandom(111105);
    final DeviceNames names = DeviceNames(_devices.listDevices());

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceId runner = _randomOtherRunner(random);

      final AgentLoginPointer pointer = pointToAgentLogin(
        reason: _randomLoginProblem(random),
        runner: runner,
        deviceRepository: _devices,
        navigation: _randomNavigation(random),
      )!;

      expect(
        pointer.hint,
        describeOtherRunnerLoginHint(names.describeDevice(runner)),
      );
      expect(pointer.hint, isNot(thisComputerLoginHint));
      expect(pointer.onConnect, isNull);
    }
  });

  test('test_offer_runner_page_property_only_where_the_window_opens_it', () {
    final Random random = seededRandom(111106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = _randomNavigation(random);

      final AgentLoginPointer pointer = _pointAtThisComputer(
        navigation,
        random,
      );

      expect(
        pointer.onConnect != null,
        navigation.canOpen(RunnerDetailRoute(_thisDevice)),
      );
    }
  });

  test('test_offer_runner_page_property_connect_opens_this_runner_page', () {
    final Random random = seededRandom(111107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = AppNavigation(
        initialRoute: SectionRoute(pickOne(random, AppSection.values)),
      );
      final List<AppRoute> before = navigation.routes;

      _pointAtThisComputer(navigation, random).onConnect!();

      expect(navigation.routes, <AppRoute>[
        ...before,
        RunnerDetailRoute(_thisDevice),
      ]);
    }
  });

  test('test_offer_runner_page_property_connecting_twice_opens_it_once', () {
    final Random random = seededRandom(111108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = AppNavigation(
        initialRoute: SectionRoute(pickOne(random, AppSection.values)),
      );
      final VoidCallback connect = _pointAtThisComputer(
        navigation,
        random,
      ).onConnect!;

      connect();
      connect();

      expect(navigation.routes.whereType<RunnerDetailRoute>(), hasLength(1));
    }
  });

  test('test_describe_agent_login_pointer_property_one_note_per_pointer', () {
    final Random random = seededRandom(111109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginPointer? pointer = random.nextBool()
          ? null
          : AgentLoginPointer(hint: randomText(random), onConnect: null);

      final List<Widget> notes = describeAgentLoginPointer(pointer);

      expect(notes, hasLength(pointer == null ? 0 : 1));
      for (final Widget note in notes) {
        expect(note, isA<MutedNote>());
        expect((note as MutedNote).text, pointer!.hint);
      }
    }
  });

  test('test_offer_agent_login_connection_property_button_only_with_an_'
      'action', () {
    final Random random = seededRandom(111110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final VoidCallback? onConnect = random.nextBool() ? () {} : null;
      final AgentLoginPointer? pointer = random.nextBool()
          ? null
          : AgentLoginPointer(hint: randomText(random), onConnect: onConnect);

      final List<Widget> buttons = offerAgentLoginConnection(pointer);

      expect(buttons, hasLength(pointer?.onConnect == null ? 0 : 1));
    }
  });
}
