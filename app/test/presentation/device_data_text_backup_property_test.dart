import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/device_data_text.dart';

import '../support/random_display_counts.dart';
import '../support/random_inputs.dart';

final RegExp _groupedNumberPattern = RegExp(r'^\d{1,3}(,\d{3})*$');

void main() {
  test('test_describe_backup_copy_property_huge_counts_group_digits', () {
    final Random random = seededRandom(97229);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int changesBehind = 2 + randomCountOfAnySize(random);
      final BackupCopy copy = BackupCopy(
        changesBehind: changesBehind,
        verifiedAt: galleryNow.subtract(
          Duration(milliseconds: random.nextInt(60000)),
        ),
      );

      final String text = describeBackupCopy(
        copy: copy,
        serverState: AppServerState.online,
        now: galleryNow,
      );

      expect(text.endsWith(' changes behind'), isTrue, reason: text);
      final String number = text.split(' ').first;
      expect(_groupedNumberPattern.hasMatch(number), isTrue, reason: text);
      expect(int.parse(number.replaceAll(',', '')), changesBehind);
    }
  });

  test('test_describe_backup_copy_property_fresh_only_under_a_minute', () {
    final Random random = seededRandom(97230);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Duration age = Duration(
        milliseconds: 59000 + random.nextInt(2000),
      );
      final BackupCopy copy = BackupCopy(
        changesBehind: 0,
        verifiedAt: galleryNow.subtract(age),
      );

      final String text = describeBackupCopy(
        copy: copy,
        serverState: AppServerState.online,
        now: galleryNow,
      );

      final bool isFresh = age < const Duration(minutes: 1);
      expect(text, isFresh ? 'Up to date' : 'Last copied 1 min ago');
    }
  });
}
