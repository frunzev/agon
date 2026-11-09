import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/rules/repository_address.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'project_repositories_editor_inputs.dart';

const Map<AgentAccess, String> _designedAccessWords = <AgentAccess, String>{
  AgentAccess.readOnly: 'Read only',
  AgentAccess.pushAfterApproval: 'Read and push',
};

int _countRunnersByModel(
  WorkspaceId workspaceId,
  List<Runner> runners,
  List<Device> devices,
) {
  int count = 0;
  for (final Runner runner in runners) {
    final bool hasMemberDevice = devices.any(
      (Device device) =>
          device.id == runner.deviceId &&
          device.workspaces.contains(workspaceId),
    );
    if (hasMemberDevice) {
      count += 1;
    }
  }
  return count;
}

void main() {
  test('test_build_project_activity_label_property_running_count_words', () {
    final Random random = seededRandom(1050701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int running = 1 + random.nextInt(5000);
      final StatusLabel label = buildProjectActivityLabel(
        runningTaskCount: running,
        lastRunAt: random.nextBool() ? galleryNow : null,
        now: galleryNow,
      );

      expect(
        label.text,
        '${describeCount(running, singular: 'task', plural: 'tasks')} running',
      );
      expect(label.tone, StatusTone.normal);
    }
  });

  test('test_build_project_activity_label_property_idle_reads_run_age', () {
    final Random random = seededRandom(1050702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomUtcMoment(random);
      final DateTime lastRunAt = now.subtract(
        Duration(minutes: random.nextInt(100000)),
      );
      final StatusLabel label = buildProjectActivityLabel(
        runningTaskCount: 0,
        lastRunAt: lastRunAt,
        now: now,
      );

      expect(label.text, describeRunAge(lastRunAt, now));
      expect(label.icon, AppIconKind.clock);
      expect(label.tone, StatusTone.muted);
    }
  });

  test('test_describe_agent_access_property_matches_the_design', () {
    for (final AgentAccess access in AgentAccess.values) {
      expect(describeAgentAccess(access), _designedAccessWords[access]);
    }
  });

  test('test_describe_agent_access_property_one_wording_per_access', () {
    final Set<String> wordings = <String>{
      for (final AgentAccess access in AgentAccess.values)
        describeAgentAccess(access),
    };

    expect(wordings, hasLength(AgentAccess.values.length));
  });

  test('test_describe_agent_access_property_short_capitalised_words', () {
    for (final AgentAccess access in AgentAccess.values) {
      final String wording = describeAgentAccess(access);

      expect(wording.trim(), wording);
      expect(wording[0], wording[0].toUpperCase());
      expect(wording, isNot(endsWith('.')));
    }
  });

  test('test_build_agent_access_label_property_tone_follows_push', () {
    for (final AgentAccess access in AgentAccess.values) {
      final StatusLabel label = buildAgentAccessLabel(access);
      final bool canPush = access == AgentAccess.pushAfterApproval;

      expect(label.tone, canPush ? StatusTone.normal : StatusTone.muted);
    }
  });

  test('test_build_agent_access_label_property_distinct_icons', () {
    final Set<AppIconKind?> icons = <AppIconKind?>{
      for (final AgentAccess access in AgentAccess.values)
        buildAgentAccessLabel(access).icon,
    };

    expect(icons, hasLength(AgentAccess.values.length));
    expect(icons, isNot(contains(null)));
  });

  test('test_count_workspace_runners_property_matches_a_model', () {
    final Random random = seededRandom(1050703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = <Runner>[
        for (final Runner runner in galleryRunners)
          if (random.nextBool()) runner,
      ];
      final List<Device> devices = <Device>[
        for (final Device device in galleryDevices)
          if (random.nextInt(4) > 0) device,
      ];
      final WorkspaceId workspaceId = pickOne(random, <WorkspaceId>[
        GalleryWorkspaceIds.acme,
        GalleryWorkspaceIds.personal,
        const WorkspaceId('elsewhere'),
      ]);

      expect(
        countWorkspaceRunners(
          workspaceId: workspaceId,
          runners: runners,
          devices: devices,
        ),
        _countRunnersByModel(workspaceId, runners, devices),
      );
    }
  });

  test('test_count_workspace_runners_property_never_more_than_runners', () {
    final Random random = seededRandom(1050704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = <Runner>[
        for (final Runner runner in galleryRunners)
          if (random.nextBool()) runner,
      ];

      expect(
        countWorkspaceRunners(
          workspaceId: GalleryWorkspaceIds.acme,
          runners: runners,
          devices: galleryDevices,
        ),
        inInclusiveRange(0, runners.length),
      );
    }
  });

  test('test_describe_repository_entry_problem_property_any_spelling_of_'
      'an_added_address', () {
    final Random random = seededRandom(1050705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = randomCanonicalHostedAddress(random);
      final List<String> added = <String>[
        randomCanonicalHostedAddress(random),
        if (random.nextBool()) address,
      ];

      expect(
        describeRepositoryEntryProblem(
          text: randomSpellingOf(random, address),
          addedAddresses: added,
        ),
        added.contains(address) ? repositoryAlreadyAddedProblem : isNull,
      );
    }
  });

  test('test_describe_repository_entry_problem_property_null_only_for_'
      'new_addresses', () {
    final Random random = seededRandom(1050706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = random.nextBool()
          ? randomHostileText(random)
          : randomSpellingOf(random, randomCanonicalHostedAddress(random));
      final List<String> added = <String>[
        if (random.nextBool()) ?parseRepositoryAddress(text),
      ];
      final String? problem = describeRepositoryEntryProblem(
        text: text,
        addedAddresses: added,
      );
      final String? address = parseRepositoryAddress(text);

      expect(problem == null, address != null && !added.contains(address));
      expect(problem, isNot(''));
    }
  });
}
