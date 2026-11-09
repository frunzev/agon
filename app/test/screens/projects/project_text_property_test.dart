import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/presentation/scope_text.dart';
import 'package:agent_orchestration/screens/projects.dart';

import '../../support/random_inputs.dart';
import '../../support/random_nowhere_scopes.dart';
import '../../support/random_scope_catalogs.dart';
import '../../support/sample_scopes.dart';
import 'project_repositories_editor_inputs.dart';

final RegExp _runAgeWording = RegExp(
  r'^Ran (today|yesterday|[2-9] days ago|[1-9][0-9]+ days ago)$',
);

Project _buildProjectWith(List<String> addresses) {
  return Project(
    id: const ProjectId('text-project'),
    workspaceId: GalleryWorkspaceIds.acme,
    name: 'text',
    repositories: <Repository>[
      for (final String address in addresses)
        Repository(
          address: address,
          defaultBranch: 'main',
          agentAccess: AgentAccess.readOnly,
        ),
    ],
    approvalPolicy: null,
  );
}

List<String> _randomAddresses(Random random) {
  return <String>[
    for (int index = 0; index < random.nextInt(6); index += 1)
      if (random.nextBool())
        randomCanonicalHostedAddress(random)
      else
        renderEditorFolderAddress(randomFolderPath(random, index)),
  ];
}

void main() {
  test('test_describe_repository_place_property_hosted_place_is_the_host', () {
    final Random random = seededRandom(1050601);
    final DeviceNames deviceNames = DeviceNames(galleryDevices);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = randomCanonicalHostedAddress(random);
      final String place = describeRepositoryPlace(address, deviceNames);

      expect(place, isNot(contains('/')));
      expect('$place/${describeRepositoryPath(address)}', address);
    }
  });

  test('test_describe_repository_paths_property_one_part_per_repo', () {
    final Random random = seededRandom(1050602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> addresses = _randomAddresses(random);
      final String paths = describeRepositoryPaths(
        _buildProjectWith(addresses),
      );

      final List<String> expected = <String>[
        for (final String address in addresses)
          describeRepositoryPath(address),
      ];
      expect(paths, expected.join(', '));
      expect(paths.isEmpty, addresses.isEmpty);
    }
  });

  test('test_describe_repository_paths_property_never_shows_hosts', () {
    final Random random = seededRandom(1050603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> addresses = _randomAddresses(random);
      final String paths = describeRepositoryPaths(
        _buildProjectWith(addresses),
      );

      expect(paths, isNot(contains('local:')));
      for (final String address in addresses) {
        if (!address.startsWith('local:')) {
          expect(paths, isNot(contains(address)));
        }
      }
    }
  });

  test('test_describe_repository_paths_property_keeps_repo_order', () {
    final Random random = seededRandom(1050604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> addresses = _randomAddresses(random);
      final String forward = describeRepositoryPaths(
        _buildProjectWith(addresses),
      );
      final String backward = describeRepositoryPaths(
        _buildProjectWith(addresses.reversed.toList()),
      );

      expect(backward.split(', ').reversed.join(', '), forward);
    }
  });

  test('test_describe_run_age_property_wording_is_total', () {
    final Random random = seededRandom(1050605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomUtcMoment(random);
      final DateTime now = randomUtcMoment(random);

      expect(describeRunAge(moment, now), matches(_runAgeWording));
    }
  });

  test('test_describe_run_age_property_older_runs_never_read_newer', () {
    final Random random = seededRandom(1050606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final DateTime newer = now.subtract(
        Duration(hours: random.nextInt(24 * 40)),
      );
      final DateTime older = newer.subtract(
        Duration(hours: random.nextInt(24 * 40)),
      );

      expect(
        _readDays(describeRunAge(older, now)),
        greaterThanOrEqualTo(_readDays(describeRunAge(newer, now))),
      );
    }
  });

  test('test_describe_workspace_contents_property_counts_of_any_size', () {
    final Random random = seededRandom(1050607);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int projects = random.nextInt(1 << 31);
      final int runners = random.nextInt(3);
      final String text = describeWorkspaceContents(
        projectCount: projects,
        runnerCount: runners,
      );

      expect(text.split(' · '), hasLength(2));
      expect(text, endsWith(runners == 1 ? ' runner' : ' runners'));
      expect(text.replaceAll(',', ''), startsWith('$projects project'));
    }
  });

  test('test_describe_workspace_contents_property_negative_counts_fail', () {
    final Random random = seededRandom(1050608);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int negative = -1 - random.nextInt(1000);

      expect(
        () => describeWorkspaceContents(
          projectCount: random.nextBool() ? negative : 1,
          runnerCount: negative,
        ),
        throwsArgumentError,
      );
    }
  });

  test('test_describe_rule_reach_property_empty_scopes_read_nowhere', () {
    final Random random = seededRandom(1050609);
    final Project project = _buildProjectWith(const <String>[]);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = randomScopeListingNoPlace(random);

      expect(
        describeRuleReach(
          scope: scope,
          project: project,
          catalog: galleryCatalog,
        ),
        'Nowhere',
      );
    }
  });

  test('test_describe_rule_reach_property_this_project_only_when_it_'
      'applies', () {
    final Random random = seededRandom(1050610);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      if (catalog.projects.isEmpty) {
        continue;
      }
      final Project project = pickOne(random, catalog.projects);
      final Scope scope = Scope(
        workspaces: random.nextBool()
            ? const AllWorkspaces()
            : OnlyWorkspaces(
                pickSome(random, listCatalogWorkspaceIds(catalog)),
              ),
        projects: OnlyProjects(<ProjectId>[project.id]),
      );
      final String reach = describeRuleReach(
        scope: scope,
        project: project,
        catalog: catalog,
      );
      final bool applies = doesScopeApply(
        scope: scope,
        workspaceId: project.workspaceId,
        projectId: project.id,
      );

      expect(reach == 'This project', applies);
    }
  });

  test('test_describe_rule_reach_property_agrees_with_the_scope_line', () {
    final Random random = seededRandom(1050611);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool usesGallery = random.nextBool();
      final ScopeCatalog catalog = usesGallery
          ? galleryCatalog
          : randomScopeCatalog(random);
      final Scope scope = usesGallery
          ? randomScopeOrNowhere(random)
          : randomScopeInCatalog(random, catalog);
      final Project project = catalog.projects.isEmpty
          ? _buildProjectWith(const <String>[])
          : pickOne(random, catalog.projects);
      final String reach = describeRuleReach(
        scope: scope,
        project: project,
        catalog: catalog,
      );
      final String line = describeScopeLine(scope, catalog);

      if (line == 'Nowhere' || line == 'Everywhere') {
        expect(reach, line);
      }
      if (reach != 'This project' && !reach.startsWith('All ')) {
        expect(reach, line);
      }
    }
  });
}

int _readDays(String runAge) {
  if (runAge == 'Ran today') {
    return 0;
  }
  if (runAge == 'Ran yesterday') {
    return 1;
  }
  return int.parse(runAge.split(' ')[1]);
}
