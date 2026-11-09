import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/rules/kept_branches.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/task_run/no_place_banner.dart';
import 'package:agent_orchestration/screens/task_run/not_pushed_banner.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/node_json_primitives.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';

const String _keptTitle = 'The work stayed on its branch and was not pushed';
const String _dockerDetail =
    "This task's agents run in Docker. It starts once an online runner "
    "offers Docker: tick In Docker on that runner's page.";
const String _localDetail =
    "This task's agents run on the runner's computer. It starts once an "
    'online runner offers it: tick On this computer on that '
    "runner's page.";
const Map<AgentPlace, List<String>> _designedPlaceTexts =
    <AgentPlace, List<String>>{
      AgentPlace.container: <String>[
        'No runner offers Docker right now',
        _dockerDetail,
      ],
      AgentPlace.localProcess: <String>[
        'No runner runs agents on its own computer right now',
        _localDetail,
      ],
    };

final DeviceNames _deviceNames = DeviceNames(galleryDevices);

DeviceId _randomRunner(Random random) {
  if (random.nextInt(3) == 0) {
    return DeviceId(randomUuidText(random));
  }
  return pickOne(random, galleryDevices).id;
}

List<KeptBranch> _randomKeptBranches(Random random) {
  final int count = 1 + random.nextInt(4);
  return <KeptBranch>[
    for (int index = 0; index < count; index += 1)
      KeptBranch(
        repositoryAddress: 'github.com/acme/repo-$index',
        branch: 'task/${randomHostileText(random)}',
        runner: _randomRunner(random),
      ),
  ];
}

Future<void> _pumpInPage(
  WidgetTester tester,
  Random random,
  Widget banner,
) async {
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SingleChildScrollView(child: banner),
  );
}

String _readSentence(MixedText text) {
  final StringBuffer sentence = StringBuffer();
  for (final TextSegment segment in text.segments) {
    sentence.write(segment.text);
  }
  return sentence.toString();
}

void main() {
  testWidgets('test_no_place_banner_build_property_follows_the_design', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1140901);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);

      await _pumpInPage(tester, random, NoPlaceBanner(place: place));

      expect(tester.takeException(), isNull);
      expect(find.text(_designedPlaceTexts[place]![0]), findsOneWidget);
      expect(find.text(_designedPlaceTexts[place]![1]), findsOneWidget);
    }
  });

  testWidgets('test_no_place_banner_build_property_asks_for_attention', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1140902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpInPage(
        tester,
        random,
        NoPlaceBanner(place: pickOne(random, AgentPlace.values)),
      );

      final NoticeBanner banner = tester.widget(find.byType(NoticeBanner));
      expect(banner.tone, BannerTone.attention);
      expect(banner.icon, AppIconKind.alert);
      expect(banner.actions, isEmpty);
    }
  });

  testWidgets('test_no_place_banner_build_property_places_read_apart', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1140903);

    for (final AgentPlace place in AgentPlace.values) {
      await _pumpInPage(tester, random, NoPlaceBanner(place: place));

      for (final AgentPlace other in AgentPlace.values) {
        if (other == place) {
          continue;
        }
        expect(find.text(_designedPlaceTexts[other]![0]), findsNothing);
      }
    }
  });

  testWidgets('test_not_pushed_banner_build_property_any_runner_reads_'
      'safely', (WidgetTester tester) async {
    final Random random = seededRandom(1140904);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<KeptBranch> keptBranches = _randomKeptBranches(random);

      await _pumpInPage(
        tester,
        random,
        NotPushedBanner(
          keptBranches: keptBranches,
          deviceNames: _deviceNames,
          onBrowse: null,
        ),
      );

      expect(tester.takeException(), isNull);
      final List<MixedText> sentences = tester
          .widgetList<MixedText>(find.byType(MixedText))
          .toList();
      expect(sentences.length, keptBranches.length);
      for (int index = 0; index < keptBranches.length; index += 1) {
        final DeviceId runner = keptBranches[index].runner;
        final String runnerName =
            _deviceNames.findName(runner) ?? shortenIdentifier(runner.value);
        expect(_readSentence(sentences[index]), endsWith(' on $runnerName.'));
      }
    }
  });

  testWidgets('test_not_pushed_banner_build_property_browsing_needs_a_'
      'callback', (WidgetTester tester) async {
    final Random random = seededRandom(1140905);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<KeptBranch> keptBranches = _randomKeptBranches(random);
      final bool canBrowse = random.nextBool();
      final List<KeptBranch> browsed = <KeptBranch>[];

      await _pumpInPage(
        tester,
        random,
        NotPushedBanner(
          keptBranches: keptBranches,
          deviceNames: _deviceNames,
          onBrowse: canBrowse ? browsed.add : null,
        ),
      );

      final NoticeBanner banner = tester.widget(find.byType(NoticeBanner));
      expect(banner.title, _keptTitle);
      expect(banner.tone, BannerTone.neutral);
      expect(
        find.byType(AppButton),
        findsNWidgets(canBrowse ? keptBranches.length : 0),
      );
    }
  });

  testWidgets('test_not_pushed_banner_build_property_each_button_browses_'
      'its_branch', (WidgetTester tester) async {
    final Random random = seededRandom(1140906);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<KeptBranch> keptBranches = _randomKeptBranches(random);
      final List<KeptBranch> browsed = <KeptBranch>[];
      final int tapped = random.nextInt(keptBranches.length);

      await _pumpInPage(
        tester,
        random,
        NotPushedBanner(
          keptBranches: keptBranches,
          deviceNames: _deviceNames,
          onBrowse: browsed.add,
        ),
      );
      final Finder button = find.byType(AppButton).at(tapped);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(browsed.length, 1);
      expect(identical(browsed.single, keptBranches[tapped]), isTrue);
    }
  });

  testWidgets('test_not_pushed_banner_build_property_fits_long_branches', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1140907);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Device runner = pickOne(random, galleryDevices);
      final KeptBranch kept = KeptBranch(
        repositoryAddress: 'github.com/acme/${'very-long-name-' * 20}',
        branch: 'task/${'rename-the-billing-module-' * 12}',
        runner: runner.id,
      );

      await _pumpInPage(
        tester,
        random,
        NotPushedBanner(
          keptBranches: <KeptBranch>[kept],
          deviceNames: _deviceNames,
          onBrowse: (KeptBranch _) {},
        ),
      );

      expect(tester.takeException(), isNull);
    }
  });
}
