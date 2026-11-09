import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/runner_target_text.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../support/random_inputs.dart';

const String _runsOnLead = 'Runs on ';
const String _notSetUp = 'Not set up';
const int _largestUnknownDeviceNumber = 1000000;
const int _largestLabelCount = 3;
const List<String> _labelPool = <String>['gpu', 'mac', 'linux'];

final DeviceNames _deviceNames = DeviceNames(galleryDevices);

String _joinTexts(List<TextSegment> segments) {
  final StringBuffer buffer = StringBuffer();
  for (final TextSegment segment in segments) {
    buffer.write(segment.text);
  }
  return buffer.toString();
}

DeviceId _randomDeviceId(Random random) {
  if (random.nextInt(3) == 0) {
    return DeviceId(
      'unknown-device-${random.nextInt(_largestUnknownDeviceNumber)}',
    );
  }
  final Device device = pickOne(random, galleryDevices);
  return device.id;
}

List<String> _randomLabels(Random random) {
  final int labelCount = random.nextInt(_largestLabelCount + 1);
  return <String>[
    for (int i = 0; i < labelCount; i += 1) pickOne(random, _labelPool),
  ];
}

RunnerTarget _randomTarget(Random random) {
  return pickOne<RunnerTarget>(random, <RunnerTarget>[
    const AnyFreeRunner(),
    SpecificRunner(_randomDeviceId(random)),
    RunnerWithLabels(_randomLabels(random)),
  ]);
}

void main() {
  test('test_describe_agent_kind_property_set_kinds_read_their_label', () {
    for (final AgentKind kind in AgentKind.values) {
      final String text = describeAgentKind(kind);

      expect(text, kind.label);
      expect(text.trim(), isNotEmpty);
    }
  });

  test('test_describe_agent_kind_property_unset_kind_reads_not_set_up', () {
    final String text = describeAgentKind(null);

    expect(text, _notSetUp);
    for (final AgentKind kind in AgentKind.values) {
      expect(text, isNot(describeAgentKind(kind)));
    }
  });

  test('test_describe_agent_kind_property_every_choice_reads_apart', () {
    final List<AgentKind?> choices = <AgentKind?>[null, ...AgentKind.values];
    final Set<String> texts = <String>{
      for (final AgentKind? kind in choices) describeAgentKind(kind),
    };

    expect(texts, hasLength(choices.length));
  });

  test('test_describe_step_runs_on_property_only_specific_says_runs_on', () {
    final Random random = seededRandom(12341);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = _randomTarget(random);

      final String text = _joinTexts(describeStepRunsOn(target, _deviceNames));

      if (target is SpecificRunner) {
        final String name = _deviceNames.describeDevice(target.deviceId);
        expect(text, '$_runsOnLead$name');
      } else {
        final List<TextSegment> plain = describeRunnerTarget(
          target,
          _deviceNames,
        );
        expect(text, _joinTexts(plain));
        expect(text, isNot(startsWith(_runsOnLead)));
      }
    }
  });

  test('test_describe_step_runs_on_property_never_has_blank_segments', () {
    final Random random = seededRandom(12342);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = _randomTarget(random);

      final List<TextSegment> segments = describeStepRunsOn(
        target,
        _deviceNames,
      );

      expect(segments, isNotEmpty);
      for (final TextSegment segment in segments) {
        expect(segment.text.trim(), isNotEmpty);
      }
      expect(_joinTexts(segments), isNot(contains('  ')));
    }
  });
}
