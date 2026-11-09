import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflows.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

final DeviceNames _deviceNames = DeviceNames(galleryDevices);
const List<String> _plainLabels = <String>['linux', 'gpu', 'mac', 'arm64'];
const List<String> _blankLabels = <String>['', ' ', '\t', '  '];
final RegExp _doubleSpace = RegExp(r'\s\s');

List<String> _randomLabels(Random random) {
  final int count = random.nextInt(4);
  final List<String> labels = <String>[];
  for (int i = 0; i < count; i += 1) {
    labels.add(
      pickOne(random, <String>[
        pickOne(random, _plainLabels),
        pickOne(random, _blankLabels),
        randomHostileText(random),
      ]),
    );
  }
  return labels;
}

void main() {
  test('test_describe_labelled_runner_property_never_doubles_spaces', () {
    final Random random = seededRandom(615701);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> labels = <String>[
        for (final String label in _randomLabels(random))
          if (!label.contains(_doubleSpace)) label,
      ];

      final String text = describeAgentTarget(
        RunnerWithLabels(labels),
        _deviceNames,
      );

      expect(text, isNot(contains(_doubleSpace)), reason: '$labels');
      expect(text, startsWith('any '));
      expect(text, endsWith(' runner'));
    }
  });

  test('test_describe_labelled_runner_property_labelless_reads_any_'
      'runner', () {
    final Random random = seededRandom(615702);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> blankLabels = <String>[
        for (int j = 0; j < random.nextInt(3); j += 1)
          pickOne(random, _blankLabels),
      ];

      final String text = describeAgentTarget(
        RunnerWithLabels(blankLabels),
        _deviceNames,
      );

      expect(text, 'any runner');
    }
  });

  test('test_describe_labelled_runner_property_names_labels_in_order', () {
    final Random random = seededRandom(615703);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> plainLabels = <String>[
        for (int j = 0; j < 1 + random.nextInt(3); j += 1)
          pickOne(random, _plainLabels),
      ];
      final List<String> mixedLabels = <String>[
        for (final String label in plainLabels) ...<String>[
          label,
          if (random.nextBool()) pickOne(random, _blankLabels),
        ],
      ];

      final String text = describeAgentTarget(
        RunnerWithLabels(mixedLabels),
        _deviceNames,
      );

      expect(text, 'any ${plainLabels.join(' ')} runner');
    }
  });
  test('test_describe_agent_target_property_specific_runner_is_named', () {
    final Random random = seededRandom(615704);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);

      final String text = describeAgentTarget(
        SpecificRunner(device.id),
        _deviceNames,
      );

      expect(text, _deviceNames.describeDevice(device.id));
      expect(text, isNot(contains(device.id.value)));
    }
  });

  test('test_describe_agent_target_property_every_target_reads_plainly', () {
    final Random random = seededRandom(615705);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = pickOne(random, <RunnerTarget>[
        const AnyFreeRunner(),
        RunnerWithLabels(_randomLabels(random)),
        SpecificRunner(pickOne(random, galleryDevices).id),
      ]);

      final String text = describeAgentTarget(target, _deviceNames);

      expect(text.trim(), isNotEmpty);
      expect(text, isNot(contains('Instance of')));
    }
  });
}
