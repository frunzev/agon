import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/repository_address.dart';

import '../../support/random_inputs.dart';
import 'support/mirrored_rule_tables.dart';

const List<String> _surroundingWhiteSpace = <String>[
  '',
  ' ',
  '\t',
  '\r\n',
  '\u00A0',
  '\u3000',
];

String _renderCase(SharedFolderRenderingCase sharedCase) {
  return renderLocalFolderAddress(
    deviceId: DeviceId(sharedCase.deviceId),
    path: sharedCase.path,
  );
}

void _expectRendering(SharedFolderRenderingCase sharedCase) {
  final String reason = '${sharedCase.deviceId} ${sharedCase.path}';
  final String? address = sharedCase.address;
  if (address == null) {
    expect(() => _renderCase(sharedCase), throwsArgumentError, reason: reason);
    return;
  }
  expect(_renderCase(sharedCase), address, reason: reason);
}

void main() {
  final List<SharedFolderAddressCase> addressCases =
      readSharedFolderAddressCases();
  final List<SharedFolderRenderingCase> renderingCases =
      readSharedFolderRenderingCases();

  test(
    'test_parse_local_folder_address_property_agrees_with_shared_table',
    () {
      for (final SharedFolderAddressCase sharedCase in addressCases) {
        final LocalFolderAddress? folder = parseLocalFolderAddress(
          sharedCase.address,
        );

        final String reason = sharedCase.address.runes.toString();
        expect(folder?.deviceId.value, sharedCase.deviceId, reason: reason);
        expect(folder?.path, sharedCase.path, reason: reason);
      }
    },
  );

  test(
    'test_render_local_folder_address_property_agrees_with_shared_table',
    () {
      for (final SharedFolderRenderingCase sharedCase in renderingCases) {
        _expectRendering(sharedCase);
      }
    },
  );

  test('test_parse_repository_address_property_agrees_on_local_addresses', () {
    for (final SharedFolderAddressCase sharedCase in addressCases) {
      final String? canonical = parseRepositoryAddress(sharedCase.address);

      final String reason = sharedCase.address.runes.toString();
      expect(canonical, sharedCase.canonical, reason: reason);
    }
  });

  test('test_parse_repository_address_property_local_rows_ignore_padding', () {
    final Random random = seededRandom(87031);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SharedFolderAddressCase sharedCase = pickOne(random, addressCases);
      final String leading = pickOne(random, _surroundingWhiteSpace);
      final String trailing = pickOne(random, _surroundingWhiteSpace);
      final String padded = '$leading${sharedCase.address}$trailing';

      final String? canonical = parseRepositoryAddress(padded);

      expect(canonical, sharedCase.canonical, reason: padded.runes.toString());
    }
  });

  test('test_render_local_folder_address_property_reads_back_its_rows', () {
    for (final SharedFolderAddressCase sharedCase in addressCases) {
      final String? deviceId = sharedCase.deviceId;
      final String? path = sharedCase.path;
      if (deviceId == null || path == null) {
        continue;
      }

      final String address = renderLocalFolderAddress(
        deviceId: DeviceId(deviceId),
        path: path,
      );

      expect(address, sharedCase.canonical);
      expect(parseLocalFolderAddress(address)?.path, path);
    }
  });
}
