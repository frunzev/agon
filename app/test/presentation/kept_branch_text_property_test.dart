import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/rules/kept_branches.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/kept_branch_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/random_inputs.dart';
import '../support/random_repository_addresses.dart';
import '../support/sample_folder_paths.dart';

typedef _RandomRepository = ({String address, String host, String path});

const String _linkLead = 'Browse the branch in ';

String _joinTexts(List<TextSegment> segments) {
  final StringBuffer buffer = StringBuffer();
  for (final TextSegment segment in segments) {
    buffer.write(segment.text);
  }
  return buffer.toString();
}

_RandomRepository _randomRepository(Random random) {
  final String host = randomRepositoryHost(random);
  final String path =
      '${randomRepositoryName(random)}/${randomRepositoryName(random)}';
  return (address: '$host/$path', host: host, path: path);
}

KeptBranch _randomKeptBranch(Random random, String repositoryAddress) {
  return KeptBranch(
    repositoryAddress: repositoryAddress,
    branch: randomHostileText(random),
    runner: pickOne(random, galleryDevices).id,
  );
}

void main() {
  final DeviceNames deviceNames = DeviceNames(galleryDevices);

  test('test_describe_kept_branch_property_follows_the_design_sentence', () {
    final Random random = seededRandom(930301);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _RandomRepository repository = _randomRepository(random);
      final Device runner = pickOne(random, galleryDevices);
      final KeptBranch kept = KeptBranch(
        repositoryAddress: repository.address,
        branch: randomHostileText(random),
        runner: runner.id,
      );

      final String sentence = _joinTexts(
        describeKeptBranch(kept: kept, deviceNames: deviceNames),
      );

      expect(
        sentence,
        'The push to ${repository.path} was denied, so its commits stay on '
        '${kept.branch} on ${runner.name}.',
      );
    }
  });

  test('test_describe_kept_branch_property_only_the_branch_is_monospace', () {
    final Random random = seededRandom(930302);
    for (int i = 0; i < propertyIterations; i += 1) {
      final KeptBranch kept = _randomKeptBranch(
        random,
        _randomRepository(random).address,
      );

      final List<TextSegment> segments = describeKeptBranch(
        kept: kept,
        deviceNames: deviceNames,
      );

      final List<TextSegment> monospaced = <TextSegment>[
        for (final TextSegment segment in segments)
          if (segment.face == TextFace.monospace) segment,
      ];
      expect(monospaced.length, 1);
      expect(monospaced.single.text, kept.branch);
    }
  });

  test('test_describe_kept_branch_property_hides_host_and_device_id', () {
    final Random random = seededRandom(930303);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _RandomRepository repository = _randomRepository(random);
      final KeptBranch kept = KeptBranch(
        repositoryAddress: repository.address,
        branch: 'task/ship',
        runner: pickOne(random, galleryDevices).id,
      );

      final String sentence = _joinTexts(
        describeKeptBranch(kept: kept, deviceNames: deviceNames),
      );

      expect(sentence, isNot(contains('${repository.host}/')));
      expect(sentence, isNot(contains(kept.runner.value)));
    }
  });

  test('test_describe_kept_branch_link_property_names_the_path', () {
    final Random random = seededRandom(930304);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _RandomRepository repository = _randomRepository(random);
      final KeptBranch kept = _randomKeptBranch(random, repository.address);

      final String link = describeKeptBranchLink(kept);

      expect(link, '$_linkLead${repository.path}');
    }
  });

  test(
    'test_describe_kept_branch_link_property_ignores_branch_and_runner',
    () {
      final Random random = seededRandom(930305);
      for (int i = 0; i < propertyIterations; i += 1) {
        final String address = _randomRepository(random).address;
        final KeptBranch first = _randomKeptBranch(random, address);
        final KeptBranch second = _randomKeptBranch(random, address);

        expect(describeKeptBranchLink(second), describeKeptBranchLink(first));
      }
    },
  );

  test('test_describe_kept_branch_link_property_folders_show_their_name', () {
    final Random random = seededRandom(930306);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String folderName = randomRepositoryName(random);
      final String address = renderLocalFolderAddress(
        deviceId: DeviceId('device-${random.nextInt(999)}'),
        path: buildTemporaryFolderPath('work/$folderName'),
      );
      final KeptBranch kept = _randomKeptBranch(random, address);

      final String link = describeKeptBranchLink(kept);

      expect(link, '$_linkLead$folderName');
      expect(link, isNot(contains(localAddressPrefix)));
    }
  });
}
