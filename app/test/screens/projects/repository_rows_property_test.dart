import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/projects/repository_rows.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'project_repositories_editor_inputs.dart';

const String _partSeparator = ' · ';

final DeviceNames _galleryNames = DeviceNames(galleryDevices);

String _randomAddress(Random random, int index) {
  if (random.nextBool()) {
    return '${randomCanonicalHostedAddress(random)}-$index';
  }
  final Device device = pickOne(random, galleryDevices);
  return renderLocalFolderAddress(
    deviceId: device.id,
    path: randomFolderPath(random, index),
  );
}

RepositoryDraft _randomDraft(Random random, int index) {
  return RepositoryDraft(
    address: _randomAddress(random, index),
    defaultBranch: 'b${randomHostileText(random)}',
  );
}

ListRowMain _mainOf(ListRowData row) => row.main as ListRowMain;

String _subtitleOf(ListRowData row) {
  return <String>[
    for (final TextSegment segment in _mainOf(row).subtitle) segment.text,
  ].join();
}

void main() {
  test('test_describe_drafted_repository_place_property_names_host_or_'
      'device', () {
    final Random random = seededRandom(1061801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryDraft draft = _randomDraft(random, i);

      final String place = describeDraftedRepositoryPlace(
        draft,
        _galleryNames,
      );

      final LocalFolderAddress? folder = parseLocalFolderAddress(
        draft.address,
      );
      final String expectedStart = folder == null
          ? draft.address.split('/').first
          : 'on ${_galleryNames.describeDevice(folder.deviceId)}';
      expect(place, startsWith('$expectedStart$_partSeparator'));
    }
  });

  test('test_describe_drafted_repository_place_property_keeps_branch_'
      'verbatim', () {
    final Random random = seededRandom(1061802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryDraft draft = _randomDraft(random, i);

      final String place = describeDraftedRepositoryPlace(
        draft,
        _galleryNames,
      );

      expect(place, endsWith('$_partSeparator${draft.defaultBranch}'));
      expect(place.length, greaterThan(draft.defaultBranch.length));
    }
  });

  test('test_describe_drafted_repository_place_property_unknown_devices_'
      'still_describe', () {
    final Random random = seededRandom(1061803);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String deviceId = 'device-${random.nextInt(1 << 20)}';
      final RepositoryDraft draft = RepositoryDraft(
        address: renderLocalFolderAddress(
          deviceId: DeviceId(deviceId),
          path: randomFolderPath(random, i),
        ),
        defaultBranch: 'main',
      );

      final String place = describeDraftedRepositoryPlace(
        draft,
        DeviceNames(const <Device>[]),
      );

      expect(place, startsWith('on '));
      expect(place, endsWith('${_partSeparator}main'));
    }
  });

  test('test_build_repository_draft_row_property_key_is_the_address', () {
    final Random random = seededRandom(1061804);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryDraft first = _randomDraft(random, i);
      final RepositoryDraft second = _randomDraft(random, i + 1);

      final ListRowData firstRow = buildRepositoryDraftRow(
        repository: first,
        deviceNames: _galleryNames,
        gitStartedAddresses: const <String>{},
        end: null,
      );
      final ListRowData secondRow = buildRepositoryDraftRow(
        repository: second,
        deviceNames: _galleryNames,
        gitStartedAddresses: const <String>{},
        end: null,
      );

      expect(firstRow.key, ValueKey<String>(first.address));
      expect(firstRow.key == secondRow.key, first.address == second.address);
    }
  });

  test('test_build_repository_draft_row_property_git_note_only_when_'
      'started', () {
    final Random random = seededRandom(1061805);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryDraft draft = _randomDraft(random, i);
      final bool hasStartedGit = random.nextBool();
      final Set<String> started = <String>{
        if (hasStartedGit) draft.address,
        _randomAddress(random, i + 1),
      };

      final ListRowData row = buildRepositoryDraftRow(
        repository: draft,
        deviceNames: _galleryNames,
        gitStartedAddresses: started,
        end: null,
      );

      final String subtitle = _subtitleOf(row);
      expect(subtitle.contains(startedGitNote), hasStartedGit);
      expect(
        subtitle,
        startsWith(describeDraftedRepositoryPlace(draft, _galleryNames)),
      );
    }
  });

  test('test_build_repository_draft_row_property_titles_by_path_and_'
      'keeps_end', () {
    final Random random = seededRandom(1061806);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryDraft draft = _randomDraft(random, i);
      final Widget end = Text(randomHostileText(random));

      final ListRowData row = buildRepositoryDraftRow(
        repository: draft,
        deviceNames: _galleryNames,
        gitStartedAddresses: const <String>{},
        end: end,
      );

      expect(_mainOf(row).title, describeRepositoryPath(draft.address));
      expect(_mainOf(row).titleFace, TextFace.monospace);
      expect(row.end, same(end));
      expect(row.onTap, isNull);
    }
  });

  test('test_build_new_folder_row_property_key_never_clashes_with_drafts', () {
    final Random random = seededRandom(1061807);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryDraft draft = _randomDraft(random, i);
      final ListRowData draftRow = buildRepositoryDraftRow(
        repository: draft,
        deviceNames: _galleryNames,
        gitStartedAddresses: const <String>{},
        end: null,
      );

      final ListRowData folderRow = buildNewFolderRow(
        folderPath: draft.address,
        end: const SizedBox.shrink(),
      );

      expect(folderRow.key, isNot(draftRow.key));
      expect(folderRow.key, isA<ValueKey<String>>());
    }
  });

  test('test_build_new_folder_row_property_shows_the_path_verbatim', () {
    final Random random = seededRandom(1061808);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String folderPath = '/${randomHostileText(random)}';

      final ListRowData row = buildNewFolderRow(
        folderPath: folderPath,
        end: const SizedBox.shrink(),
      );

      expect(_mainOf(row).title, folderPath);
      expect(_mainOf(row).titleFace, TextFace.monospace);
      expect(_subtitleOf(row), newFolderNote);
    }
  });

  test('test_build_new_folder_row_property_keeps_the_end', () {
    final Random random = seededRandom(1061809);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Widget end = Text(randomHostileText(random));

      final ListRowData row = buildNewFolderRow(
        folderPath: randomFolderPath(random, i),
        end: end,
      );

      expect(row.end, same(end));
      expect(row.emphasis, RowEmphasis.normal);
      expect(row.onTap, isNull);
    }
  });
}
