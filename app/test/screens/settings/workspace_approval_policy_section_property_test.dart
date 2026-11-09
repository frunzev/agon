import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/server_group_repositories.dart';
import '../../support/widget_harness.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_place_repositories.dart';

typedef _PolicyPage = ({
  FakeWorkspaceRepository stored,
  PlannedRefusal refusal,
});

Future<_PolicyPage> _pumpPolicySection(
  WidgetTester tester,
  Random random,
) async {
  final FakeWorkspaceRepository stored = buildServerGroupRepository(
    galleryAppServerGroup,
  );
  await stored.changeApprovalPolicy(
    workspaceId: GalleryWorkspaceIds.acme,
    approvalPolicy: pickOne(random, ApprovalPolicy.values),
  );
  final PlannedRefusal refusal = PlannedRefusal();
  final WorkspaceRepository repository = RefusingWorkspaceRepository(
    stored: stored,
    refusal: refusal,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: ListenableBuilder(
      listenable: stored,
      builder: (BuildContext context, Widget? child) =>
          WorkspaceApprovalPolicySection(workspaceRepository: repository),
    ),
  );
  return (stored: stored, refusal: refusal);
}

ApprovalPolicy _readPolicy(FakeWorkspaceRepository stored) {
  return stored.currentWorkspace().approvalPolicy;
}

Future<void> _tapPolicy(WidgetTester tester, ApprovalPolicy policy) async {
  final Finder choice = find.text(describeApprovalPolicyTitle(policy));
  await tester.ensureVisible(choice);
  await tester.tap(choice);
  await pumpFrames(tester);
}

ApprovalPolicy _otherPolicy(ApprovalPolicy policy) {
  return approvalPolicyChoiceOrder.firstWhere(
    (ApprovalPolicy candidate) => candidate != policy,
  );
}

void main() {
  testWidgets(
    'test_workspace_approval_policy_section_constructor_property_keeps_fields',
    (WidgetTester tester) async {
      final Random random = seededRandom(311021);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final FakeWorkspaceRepository repository = buildServerGroupRepository(
          galleryAppServerGroup,
        );
        final Key key = ValueKey<int>(random.nextInt(1000));

        final WorkspaceApprovalPolicySection section =
            WorkspaceApprovalPolicySection(
              workspaceRepository: repository,
              key: key,
            );

        expect(identical(section.workspaceRepository, repository), isTrue);
        expect(section.key, key);
      }
    },
  );

  testWidgets(
    'test_workspace_approval_policy_section_constructor_property_no_key',
    (WidgetTester tester) async {
      final WorkspaceApprovalPolicySection section =
          WorkspaceApprovalPolicySection(
            workspaceRepository: buildServerGroupRepository(
              galleryAppServerGroup,
            ),
          );

      expect(section.key, isNull);
    },
  );

  testWidgets(
    'test_workspace_approval_policy_section_constructor_property_own_policy',
    (WidgetTester tester) async {
      final Random random = seededRandom(311022);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _PolicyPage page = await _pumpPolicySection(tester, random);

        final ChoiceListField<ApprovalPolicy> field = tester
            .widget<ChoiceListField<ApprovalPolicy>>(
              find.byType(ChoiceListField<ApprovalPolicy>),
            );
        expect(field.selected, _readPolicy(page.stored));
      }
    },
  );

  testWidgets(
    'test_workspace_approval_policy_section_build_property_no_overflow',
    (WidgetTester tester) async {
      final Random random = seededRandom(311023);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        await _pumpPolicySection(tester, random);

        expect(tester.takeException(), isNull);
        expect(find.text(approvalPolicyLabel), findsOneWidget);
        expect(find.text(workspaceApprovalPolicyNote), findsOneWidget);
        for (final ApprovalPolicy policy in approvalPolicyChoiceOrder) {
          expect(
            find.text(describeApprovalPolicyTitle(policy)),
            findsOneWidget,
          );
          expect(
            find.text(describeApprovalPolicyDetail(policy)),
            findsOneWidget,
          );
        }
      }
    },
  );

  testWidgets(
    'test_workspace_approval_policy_section_build_property_design_order',
    (WidgetTester tester) async {
      final Random random = seededRandom(311024);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        await _pumpPolicySection(tester, random);

        final List<String> designOrder = <String>[
          approvalPolicyLabel,
          workspaceApprovalPolicyNote,
          for (final ApprovalPolicy policy in approvalPolicyChoiceOrder)
            describeApprovalPolicyTitle(policy),
        ];
        double previousTop = double.negativeInfinity;
        for (final String text in designOrder) {
          final double top = tester.getTopLeft(find.text(text)).dy;
          expect(top, greaterThan(previousTop), reason: text);
          previousTop = top;
        }
      }
    },
  );

  testWidgets(
    'test_workspace_approval_policy_section_build_property_offers_every_policy',
    (WidgetTester tester) async {
      final Random random = seededRandom(311025);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        await _pumpPolicySection(tester, random);

        final ChoiceListField<ApprovalPolicy> field = tester
            .widget<ChoiceListField<ApprovalPolicy>>(
              find.byType(ChoiceListField<ApprovalPolicy>),
            );
        final List<ApprovalPolicy> offered = <ApprovalPolicy>[
          for (final ChoiceOption<ApprovalPolicy> option in field.options)
            option.value,
        ];
        expect(offered.toSet(), ApprovalPolicy.values.toSet());
        expect(offered.length, ApprovalPolicy.values.length);
      }
    },
  );

  testWidgets('test_change_approval_policy_property_saves_the_tapped_policy', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311026);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _PolicyPage page = await _pumpPolicySection(tester, random);
      final int tapCount = 1 + random.nextInt(4);

      for (int tap = 0; tap < tapCount; tap += 1) {
        final ApprovalPolicy tapped = _otherPolicy(_readPolicy(page.stored));
        await _tapPolicy(tester, tapped);
        expect(_readPolicy(page.stored), tapped);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'test_change_approval_policy_property_selected_choice_sends_nothing',
    (WidgetTester tester) async {
      final Random random = seededRandom(311027);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _PolicyPage page = await _pumpPolicySection(tester, random);
        final ApprovalPolicy selected = _readPolicy(page.stored);
        page.refusal.problem = PeopleFacingRefusal('offline $i');

        await _tapPolicy(tester, selected);

        expect(page.refusal.attempts, 0);
        expect(_readPolicy(page.stored), selected);
        expect(
          find.text(describeRefusalTitle(changeSettingLabel)),
          findsNothing,
        );
      }
    },
  );

  testWidgets(
    'test_change_approval_policy_property_refusal_keeps_the_policy',
    (WidgetTester tester) async {
      final Random random = seededRandom(311028);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _PolicyPage page = await _pumpPolicySection(tester, random);
        final ApprovalPolicy before = _readPolicy(page.stored);
        final ExplainedRefusal planned = randomExplainedRefusal(random);
        page.refusal.problem = planned.problem;

        await _tapPolicy(tester, _otherPolicy(before));

        expect(_readPolicy(page.stored), before);
        expect(find.text(describeRefusalTitle(changeSettingLabel)), findsOne);
        expect(find.text(planned.explanation), findsOneWidget);
        expect(find.text(approvalPolicyLabel), findsWidgets);
        await tapButtonLabelled(tester, refusalCloseLabel);
        expect(
          find.text(describeRefusalTitle(changeSettingLabel)),
          findsNothing,
        );
      }
    },
  );
}
