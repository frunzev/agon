import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/new_items/item_drafting_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/shared/agent_login_pointer.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_scopes.dart';

const List<String> _loginProblems = <String>[
  'the drafting run did not finish: Not logged in · Please run /login',
  'Not logged in',
  'Please run /login',
];

AppNavigation _newNavigation() {
  return AppNavigation(initialRoute: const SectionRoute(AppSection.tasks));
}

DeviceId _randomDeviceId(Random random, List<Device> devices) {
  if (random.nextBool()) {
    return pickOne(random, devices).id;
  }
  return DeviceId('device-${randomHostileText(random)}-${random.nextInt(99)}');
}

DraftRunning? _randomRunning(Random random, List<Device> devices) {
  if (random.nextInt(4) == 0) {
    return null;
  }
  return DraftRunning(
    drafterKind: pickOne(random, AgentKind.values),
    drafterDeviceId: _randomDeviceId(random, devices),
  );
}

String? _randomProblem(Random random) {
  return switch (random.nextInt(3)) {
    0 => null,
    1 => pickOne(random, _loginProblems),
    _ => 'Problem ${randomHostileText(random)}',
  };
}

void main() {
  final AppDependencies dependencies = buildGalleryDependencies();
  final List<Device> devices = dependencies.deviceRepository.listDevices();

  test('test_describe_item_drafter_property_known_devices_by_name', () {
    for (final AgentKind kind in AgentKind.values) {
      for (final Device device in devices) {
        final String text = describeItemDrafter(
          running: DraftRunning(drafterKind: kind, drafterDeviceId: device.id),
          deviceNames: DeviceNames(devices),
        );

        expect(text, '${kind.label} is drafting on ${device.name}');
        expect(text, isNot(contains(device.id.value)));
      }
    }
  });

  test('test_describe_item_drafter_property_unknown_devices_shortened', () {
    final Random random = seededRandom(1020601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentKind kind = pickOne(random, AgentKind.values);
      final DeviceId unknown = DeviceId('${randomHostileText(random)}-$i');

      final String text = describeItemDrafter(
        running: DraftRunning(drafterKind: kind, drafterDeviceId: unknown),
        deviceNames: DeviceNames(devices),
      );

      expect(
        text,
        '${kind.label} is drafting on ${shortenIdentifier(unknown.value)}',
      );
    }
  });

  test('test_describe_item_drafter_property_waiting_needs_no_devices', () {
    final Random random = seededRandom(1020602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Device> someDevices = pickSome(random, devices);

      expect(
        describeItemDrafter(
          running: null,
          deviceNames: DeviceNames(someDevices),
        ),
        startingDraftText,
      );
    }
  });

  test('test_drafting_state_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(1020603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String drafterText = randomHostileText(random);
      final String? draftProblem = randomOptionalHostileText(random);
      final String? stopProblem = randomOptionalHostileText(random);
      final String returnLabel = randomHostileText(random);
      final AgentLoginPointer? pointer = random.nextBool()
          ? AgentLoginPointer(hint: randomHostileText(random), onConnect: null)
          : null;

      final DraftingState state = DraftingState(
        drafterText: drafterText,
        draftProblem: draftProblem,
        stopProblem: stopProblem,
        returnLabel: returnLabel,
        loginPointer: pointer,
      );

      expect(state.drafterText, drafterText);
      expect(state.draftProblem, draftProblem);
      expect(state.stopProblem, stopProblem);
      expect(state.returnLabel, returnLabel);
      expect(state.loginPointer, same(pointer));
    }
  });

  test('test_drafting_state_constructor_property_const_states_are_'
      'canonical', () {
    const DraftingState first = DraftingState(
      drafterText: startingDraftText,
      draftProblem: null,
      stopProblem: null,
      returnLabel: backToWordsLabel,
      loginPointer: null,
    );
    const DraftingState second = DraftingState(
      drafterText: startingDraftText,
      draftProblem: null,
      stopProblem: null,
      returnLabel: backToWordsLabel,
      loginPointer: null,
    );

    expect(identical(first, second), isTrue);
  });

  test('test_drafting_state_constructor_property_never_trims_texts', () {
    final Random random = seededRandom(1020604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String padded = '  ${randomHostileText(random)}\n';

      final DraftingState state = DraftingState(
        drafterText: padded,
        draftProblem: padded,
        stopProblem: padded,
        returnLabel: padded,
        loginPointer: null,
      );

      expect(state.drafterText, padded);
      expect(state.draftProblem, padded);
      expect(state.stopProblem, padded);
      expect(state.returnLabel, padded);
    }
  });

  test('test_describe_drafting_state_property_keeps_problems_and_label', () {
    final Random random = seededRandom(1020605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftRunning? running = _randomRunning(random, devices);
      final String? draftProblem = _randomProblem(random);
      final String? stopProblem = randomOptionalHostileText(random);
      final String returnLabel = pickOne(random, <String>[
        backToWordsLabel,
        backToDraftLabel,
      ]);

      final DraftingState state = describeDraftingState(
        running: running,
        draftProblem: draftProblem,
        stopProblem: stopProblem,
        returnLabel: returnLabel,
        deviceRepository: dependencies.deviceRepository,
        navigation: _newNavigation(),
      );

      expect(state.draftProblem, draftProblem);
      expect(state.stopProblem, stopProblem);
      expect(state.returnLabel, returnLabel);
      expect(
        state.drafterText,
        describeItemDrafter(
          running: running,
          deviceNames: DeviceNames(devices),
        ),
      );
    }
  });

  test('test_describe_drafting_state_property_login_pointer_only_for_'
      'login_problems', () {
    final Random random = seededRandom(1020606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftRunning? running = _randomRunning(random, devices);
      final String? draftProblem = _randomProblem(random);

      final DraftingState state = describeDraftingState(
        running: running,
        draftProblem: draftProblem,
        stopProblem: null,
        returnLabel: backToWordsLabel,
        deviceRepository: dependencies.deviceRepository,
        navigation: _newNavigation(),
      );

      final bool pointsToLogin =
          running != null &&
          draftProblem != null &&
          isAgentLoginProblem(draftProblem);
      expect(state.loginPointer != null, pointsToLogin);
    }
  });

  test('test_describe_drafting_state_property_connect_only_on_this_'
      'computer', () {
    final Random random = seededRandom(1020607);
    final DeviceId thisDevice = dependencies.deviceRepository
        .currentDevice()
        .id;

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceId runner = pickOne(random, <DeviceId>[
        thisDevice,
        GalleryDeviceIds.officeServer,
        GalleryDeviceIds.macStudio,
      ]);
      final AppNavigation navigation = _newNavigation();

      final DraftingState state = describeDraftingState(
        running: DraftRunning(
          drafterKind: pickOne(random, AgentKind.values),
          drafterDeviceId: runner,
        ),
        draftProblem: pickOne(random, _loginProblems),
        stopProblem: null,
        returnLabel: backToWordsLabel,
        deviceRepository: dependencies.deviceRepository,
        navigation: navigation,
      );

      final AgentLoginPointer pointer = state.loginPointer!;
      if (runner == thisDevice) {
        expect(pointer.hint, thisComputerLoginHint);
        pointer.onConnect!();
        expect(navigation.currentRoute, RunnerDetailRoute(thisDevice));
      } else {
        expect(pointer.onConnect, isNull);
        expect(
          pointer.hint,
          contains(DeviceNames(devices).describeDevice(runner)),
        );
      }
    }
  });
}
