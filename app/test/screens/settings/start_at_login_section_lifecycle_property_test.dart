import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/screens/settings.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/recording_runner_presence.dart';
import '../../support/widget_harness.dart';
import 'support/start_at_login_harness.dart';

void main() {
  testWidgets(
    'test_start_at_login_section_constructor_property_keeps_fields',
    (WidgetTester tester) async {
      final Random random = seededRandom(310981);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final RunnerPresence presence = RecordedRunnerPresence(
          isStartAtLoginChosen: random.nextBool(),
        ).presence;
        final Key key = ValueKey<int>(random.nextInt(1000));

        final StartAtLoginSection section = StartAtLoginSection(
          runnerPresence: presence,
          key: key,
        );

        expect(identical(section.runnerPresence, presence), isTrue);
        expect(section.key, key);
      }
    },
  );

  testWidgets('test_start_at_login_section_constructor_property_no_key', (
    WidgetTester tester,
  ) async {
    final StartAtLoginSection section = StartAtLoginSection(
      runnerPresence: RecordedRunnerPresence(isStartAtLoginChosen: false)
          .presence,
    );

    expect(section.key, isNull);
  });

  testWidgets(
    'test_start_at_login_section_constructor_property_own_presence',
    (WidgetTester tester) async {
      final Random random = seededRandom(310982);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final bool isChosen = random.nextBool();

        await pumpStartAtLogin(
          tester,
          width: randomStartAtLoginWidth(random),
          presence: RecordedRunnerPresence(isStartAtLoginChosen: isChosen)
              .presence,
        );

        expect(readStartAtLoginToggle(tester).value, isChosen);
      }
    },
  );

  testWidgets('test_start_at_login_label_property_matches_the_design', (
    WidgetTester tester,
  ) async {
    await pumpStartAtLogin(
      tester,
      width: desktopWidth,
      presence: RecordedRunnerPresence(isStartAtLoginChosen: false).presence,
    );

    expect(startAtLoginLabel, 'Start at login');
    expect(find.text(startAtLoginLabel), findsOneWidget);
    expect(readStartAtLoginToggle(tester).semanticLabel, startAtLoginLabel);
  });

  testWidgets('test_start_at_login_section_create_state_property_new_state', (
    WidgetTester tester,
  ) async {
    final StartAtLoginSection section = StartAtLoginSection(
      runnerPresence: RecordedRunnerPresence(isStartAtLoginChosen: true)
          .presence,
    );

    final State<StartAtLoginSection> first = section.createState();
    final State<StartAtLoginSection> second = section.createState();

    expect(identical(first, second), isFalse);
    expect(first.mounted, isFalse);
  });

  testWidgets(
    'test_start_at_login_section_create_state_property_kept_on_rebuild',
    (WidgetTester tester) async {
      final Random random = seededRandom(310983);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final CountingChoiceStore store = CountingChoiceStore(
          isStartAtLoginChosen: random.nextBool(),
        );
        final RunnerPresence presence = buildPresence(
          loginItem: RecordingLoginItem(),
          store: store,
        );
        final double width = randomStartAtLoginWidth(random);
        await pumpStartAtLogin(tester, width: width, presence: presence);

        await pumpScrollableAtWidth(
          tester,
          width: width,
          child: StartAtLoginSection(runnerPresence: presence),
        );

        expect(store.readCount, 1);
        expect(
          readStartAtLoginToggle(tester).value,
          store.isStartAtLoginChosen,
        );
      }
    },
  );

  testWidgets(
    'test_start_at_login_section_create_state_property_new_key_reads',
    (WidgetTester tester) async {
      final Random random = seededRandom(310984);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final CountingChoiceStore store = CountingChoiceStore(
          isStartAtLoginChosen: random.nextBool(),
        );
        final RunnerPresence presence = buildPresence(
          loginItem: RecordingLoginItem(),
          store: store,
        );
        final double width = randomStartAtLoginWidth(random);
        await pumpStartAtLogin(tester, width: width, presence: presence);
        store.isStartAtLoginChosen = !store.isStartAtLoginChosen;

        await pumpScrollableAtWidth(
          tester,
          width: width,
          child: StartAtLoginSection(
            key: ValueKey<int>(i),
            runnerPresence: presence,
          ),
        );
        await tester.pump();

        expect(store.readCount, 2);
        expect(
          readStartAtLoginToggle(tester).value,
          store.isStartAtLoginChosen,
        );
      }
    },
  );

  testWidgets('test_init_state_property_hidden_until_the_choice_is_read', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310985);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final CountingChoiceStore store = CountingChoiceStore(
        isStartAtLoginChosen: random.nextBool(),
      )..heldRead = Completer<void>();
      await pumpStartAtLogin(
        tester,
        width: randomStartAtLoginWidth(random),
        presence: buildPresence(loginItem: RecordingLoginItem(), store: store),
      );

      expect(findStartAtLoginToggle(), findsNothing);
      expect(find.text(thisComputerTitle), findsNothing);

      store.heldRead!.complete();
      await pumpFrames(tester);
      expect(readStartAtLoginToggle(tester).value, store.isStartAtLoginChosen);
    }
  });

  testWidgets('test_init_state_property_reads_the_choice_exactly_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310986);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final CountingChoiceStore store = CountingChoiceStore(
        isStartAtLoginChosen: random.nextBool(),
      );
      await pumpStartAtLogin(
        tester,
        width: randomStartAtLoginWidth(random),
        presence: buildPresence(loginItem: RecordingLoginItem(), store: store),
      );

      final int frameCount = 1 + random.nextInt(4);
      for (int frame = 0; frame < frameCount; frame += 1) {
        await tester.pump();
      }

      expect(store.readCount, 1);
    }
  });

  testWidgets('test_init_state_property_leaving_before_the_read_is_quiet', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310987);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final CountingChoiceStore store = CountingChoiceStore(
        isStartAtLoginChosen: random.nextBool(),
      )..heldRead = Completer<void>();
      await pumpStartAtLogin(
        tester,
        width: randomStartAtLoginWidth(random),
        presence: buildPresence(loginItem: RecordingLoginItem(), store: store),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      store.heldRead!.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });
}
