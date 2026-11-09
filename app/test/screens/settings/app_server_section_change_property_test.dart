import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';

import '../../support/random_inputs.dart';
import '../../support/server_group_repositories.dart';
import '../support/app_server_section_harness.dart';

const String _thisBackupText =
    'This device · Backup · keeps a live copy and takes over when the '
    'active server is off.';

void main() {
  testWidgets('test_change_server_backup_property_retry_clears_the_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109310);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkspaceRepository inner = buildServerGroupRepository(
        galleryAppServerGroup,
      );
      int attempts = 0;
      await pumpAppServerSection(
        tester,
        random,
        ScriptedServerBackupRepository(
          inner: inner,
          startBackup: () async {
            attempts += 1;
            if (attempts == 1) {
              throw PeopleFacingRefusal('first try refused $i');
            }
            return inner.startServerBackup();
          },
        ),
      );

      await tapServerBackupToggle(tester, findServerBackupToggle());
      expect(find.text('first try refused $i'), findsOneWidget);
      await tapServerBackupToggle(tester, findServerBackupToggle());

      expect(find.text('first try refused $i'), findsNothing);
      expect(find.text(_thisBackupText), findsOneWidget);
    }
  });

  testWidgets('test_change_server_backup_property_unexplained_not_hidden', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109311);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpAppServerSection(
        tester,
        random,
        ScriptedServerBackupRepository(
          inner: buildServerGroupRepository(galleryAppServerGroup),
          startBackup: () async => throw FormatException('broken $i'),
        ),
      );

      final List<Object> escaped = <Object>[];
      await runZonedGuarded<Future<void>>(
        () => tapServerBackupToggle(tester, findServerBackupToggle()),
        (Object problem, StackTrace _) => escaped.add(problem),
      );

      expect(escaped, <Matcher>[isA<FormatException>()]);
      expect(readServerBackupToggle(tester).onChanged, isNotNull);
      expect(find.text('broken $i'), findsNothing);
    }
  });

  testWidgets('test_change_server_backup_property_blank_refusal_escapes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109312);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String blank = pickOne(random, const <String>['', ' ', '\n']);
      await pumpAppServerSection(
        tester,
        random,
        ScriptedServerBackupRepository(
          inner: buildServerGroupRepository(galleryAppServerGroup),
          startBackup: () async => throw PeopleFacingRefusal(blank),
        ),
      );

      final List<Object> escaped = <Object>[];
      await runZonedGuarded<Future<void>>(
        () => tapServerBackupToggle(tester, findServerBackupToggle()),
        (Object problem, StackTrace _) => escaped.add(problem),
      );

      expect(escaped, hasLength(1));
      expect(readServerBackupToggle(tester).value, isFalse);
      expect(readServerBackupToggle(tester).onChanged, isNotNull);
    }
  });
}
