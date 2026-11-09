import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_folder_paths.dart';
import 'support/random_approval_requests.dart';

const String _separator = ' · ';
final DeviceNames _deviceNames = DeviceNames(galleryDevices);
const List<String> _blankTexts = <String>['', ' ', '\t', '\n ', ' '];

String _joinSegments(List<TextSegment> segments) {
  final StringBuffer joined = StringBuffer();
  for (final TextSegment segment in segments) {
    joined.write(segment.text);
  }
  return joined.toString();
}

ImproveSkillAction _skillChangeWithSummary(String summary) {
  return ImproveSkillAction(
    skillId: GallerySkillIds.changelogEntries,
    summary: summary,
    preview: null,
  );
}

void main() {
  test('test_keep_written_parts_property_blank_summaries_are_dropped', () {
    final Random random = seededRandom(616901);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String runLabel = 'release #${random.nextInt(1000)}';

      final String context = _joinSegments(
        describeApprovalContext(
          action: _skillChangeWithSummary(pickOne(random, _blankTexts)),
          runLabel: runLabel,
          change: null,
        ),
      );

      expect(context, runLabel);
    }
  });

  test('test_keep_written_parts_property_blank_run_labels_are_dropped', () {
    final Random random = seededRandom(616902);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RunCommandAction action = randomCommandAction(random);

      final List<TextSegment> context = describeApprovalContext(
        action: action,
        runLabel: pickOne(random, _blankTexts),
        change: null,
      );

      expect(context, hasLength(1));
      expect(context.single.text, action.command);
    }
  });

  test('test_keep_written_parts_property_written_parts_keep_their_order', () {
    final Random random = seededRandom(616903);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String runLabel = 'release #${random.nextInt(1000)}';
      final String summary = 'Change ${randomText(random)}';

      final String context = _joinSegments(
        describeApprovalContext(
          action: _skillChangeWithSummary(summary),
          runLabel: runLabel,
          change: null,
        ),
      );

      expect(context, '$runLabel$_separator$summary');
    }
  });

  test('test_describe_approval_repository_property_local_hides_the_'
      'stored_address', () {
    final Random random = seededRandom(616118);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      final String address = renderLocalFolderAddress(
        deviceId: device.id,
        path: buildTemporaryFolderPath('code/app-${random.nextInt(99)}'),
      );

      final String shown = describeApprovalRepository(address, _deviceNames);

      expect(shown, isNot(contains(localAddressPrefix)));
      expect(shown, isNot(contains(device.id.value)));
      expect(shown, contains('app-'));
    }
  });
}
