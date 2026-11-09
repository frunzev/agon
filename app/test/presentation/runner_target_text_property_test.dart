import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/runner_target_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/random_inputs.dart';

const String _anyRunner = 'Any runner';
const String _labelsLead = 'Any runner with ';

String _joinTexts(List<TextSegment> segments) {
  final StringBuffer buffer = StringBuffer();
  for (final TextSegment segment in segments) {
    buffer.write(segment.text);
  }
  return buffer.toString();
}

List<String> _randomLabels(Random random) {
  final int count = random.nextInt(4);
  return <String>[for (int i = 0; i < count; i += 1) 'label-$i'];
}

RunnerTarget _randomTarget(Random random) {
  return pickOne<RunnerTarget>(random, <RunnerTarget>[
    const AnyFreeRunner(),
    SpecificRunner(pickOne(random, galleryDevices).id),
    RunnerWithLabels(_randomLabels(random)),
    RunnerWithLabels(<String>[
      for (final String text in randomHostileTexts(random)) 'gpu$text',
    ]),
  ]);
}

void main() {
  final DeviceNames deviceNames = DeviceNames(galleryDevices);

  test('test_describe_runner_target_property_specific_shows_only_name', () {
    final Random random = seededRandom(930801);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);

      final List<TextSegment> segments = describeRunnerTarget(
        SpecificRunner(device.id),
        deviceNames,
      );

      expect(segments.length, 1);
      expect(segments.single.text, device.name);
      expect(segments.single.face, TextFace.monospace);
      expect(_joinTexts(segments), isNot(contains(device.id.value)));
    }
  });

  test('test_describe_runner_target_property_labels_listed_in_order', () {
    final Random random = seededRandom(930802);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> labels = <String>[
        'label-first',
        ..._randomLabels(random),
      ];

      final List<TextSegment> segments = describeRunnerTarget(
        RunnerWithLabels(labels),
        deviceNames,
      );

      expect(segments.first.text, _labelsLead);
      expect(segments.first.face, TextFace.body);
      expect(segments.last.text, labels.join(', '));
      expect(segments.last.face, TextFace.monospace);
    }
  });

  test('test_describe_runner_target_property_never_dangles_or_empties', () {
    final Random random = seededRandom(930803);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = _randomTarget(random);

      final List<TextSegment> segments = describeRunnerTarget(
        target,
        deviceNames,
      );

      expect(_joinTexts(segments), isNot(endsWith('with ')));
      expect(_joinTexts(segments).trim(), isNotEmpty);
      for (final TextSegment segment in segments) {
        expect(segment.text, isNotEmpty);
      }
    }
  });

  test('test_describe_runner_target_property_empty_labels_mean_any', () {
    final List<TextSegment> segments = describeRunnerTarget(
      RunnerWithLabels(const <String>[]),
      deviceNames,
    );

    expect(_joinTexts(segments), _anyRunner);
    expect(
      _joinTexts(describeRunnerTarget(const AnyFreeRunner(), deviceNames)),
      _anyRunner,
    );
  });
}
