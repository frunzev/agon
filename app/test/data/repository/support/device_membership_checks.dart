import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../../support/random_inputs.dart';
import 'device_contract_rigs.dart';

const String _acceptedOutcome = 'accepted';
const String _notFoundOutcome = 'not found';
const String _stateOutcome = 'refused';
const int conflictStatus = 409;
const int notFoundStatus = 404;

String classifyMembershipOutcome(MembershipOutcome outcome) {
  final Object? failure = outcome.failure;
  if (failure == null) {
    return _acceptedOutcome;
  }
  if (failure is AppServerRefusal) {
    return 'app server ${failure.status}';
  }
  if (failure is RecordNotFound) {
    return _notFoundOutcome;
  }
  if (failure is StateError) {
    return _stateOutcome;
  }
  return 'unexpected $failure';
}

List<String> classifyEveryMembershipOutcome(List<MembershipOutcome> outcomes) {
  return <String>[
    for (final MembershipOutcome outcome in outcomes)
      classifyMembershipOutcome(outcome),
  ];
}

Future<DeviceContractWorld> buildMembershipWorld(Random random) {
  return buildEveryDeviceRepository(
    random,
    gitlessFolderPaths: const <String>{},
  );
}

List<List<DeviceProjection>> projectEveryDeviceList(
  DeviceContractWorld world,
) {
  return <List<DeviceProjection>>[
    for (final NamedDeviceRepository implementation in world.implementations)
      projectDevices(implementation.repository.listDevices()),
  ];
}

Future<void> expectMembershipChangeAgrees(
  Random random,
  DeviceContractWorld world,
  MembershipChange change,
) async {
  final DeviceRepository first = world.implementations.first.repository;
  final List<List<DeviceProjection>> before = projectEveryDeviceList(world);

  final List<MembershipOutcome> outcomes = await changeMembershipOnEvery(
    world.implementations,
    change: change,
    deviceId: pickDeviceId(random, first),
    workspaceId: pickWorkspaceId(random, first),
  );

  final List<String> classes = classifyEveryMembershipOutcome(outcomes);
  expect(classes.toSet(), hasLength(1), reason: '$change $classes');
  expect(classes.first, isNot(startsWith('unexpected')));
  if (classes.first != _acceptedOutcome) {
    expect(
      projectEveryDeviceList(world),
      before,
      reason: '$change was refused',
    );
  }
  final List<List<DeviceProjection>> after = projectEveryDeviceList(world);
  for (final List<DeviceProjection> projected in after) {
    expect(projected, orderedEquals(after.first), reason: '$change');
  }
}

Device pickOtherDevice(Random random, DeviceRepository repository) {
  final Device current = repository.currentDevice();
  final List<Device> others = <Device>[
    for (final Device device in repository.listDevices())
      if (device.id != current.id) device,
  ];
  if (others.isEmpty) {
    return current;
  }
  return pickOne(random, others);
}
