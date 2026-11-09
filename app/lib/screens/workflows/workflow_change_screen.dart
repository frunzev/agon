import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';

const SectionRoute _workflowsRoute = SectionRoute(AppSection.workflows);
const String _discardChangeLabel = 'Discard change';
const String _signChangeLabel = 'Sign change';

typedef WorkflowChangeSettlement = Future<Workflow> Function(
  WorkflowId workflowId,
);

class WorkflowChangeScreen extends StatefulWidget {
  const WorkflowChangeScreen({
    required this.workflowId,
    required this.workflowRepository,
    required this.deviceRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final WorkflowId workflowId;
  final WorkflowRepository workflowRepository;
  final DeviceRepository deviceRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  State<WorkflowChangeScreen> createState() => _WorkflowChangeScreenState();
}

class _WorkflowChangeScreenState extends State<WorkflowChangeScreen> {
  bool _isSettling = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.workflowRepository,
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final WorkflowRepository workflowRepository = widget.workflowRepository;
    final Workflow workflow = workflowRepository.findWorkflow(
      widget.workflowId,
    );
    final WorkflowChange? change = workflowRepository.findPendingChange(
      widget.workflowId,
    );
    final DateTime now = widget.clock.now();
    final BackLink backLink = BackLink(
      label: 'Workflows',
      onPressed: () => widget.navigation.returnTo(_workflowsRoute),
    );

    if (change == null) {
      return AppPage(
        children: <Widget>[
          PageHeader(title: workflow.name, backLink: backLink),
          const MutedNote('There is no change waiting to be signed.'),
        ],
      );
    }

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: workflow.name,
          summary: <TextSegment>[
            TextSegment(
              describeChangeSummary(
                change: change,
                deviceNames: DeviceNames(
                  widget.deviceRepository.listDevices(),
                ),
                now: now,
              ),
            ),
          ],
          backLink: backLink,
          actions: <Widget>[
            AppButton.secondary(
              label: _discardChangeLabel,
              onPressed: _isSettling
                  ? null
                  : () => unawaited(
                      _settleChange(
                        title: workflow.name,
                        actionLabel: _discardChangeLabel,
                        settle: workflowRepository.discardChange,
                      ),
                    ),
            ),
            AppButton.primary(
              label: _signChangeLabel,
              onPressed: _isSettling
                  ? null
                  : () => unawaited(
                      _settleChange(
                        title: workflow.name,
                        actionLabel: _signChangeLabel,
                        settle: workflowRepository.signWorkflow,
                      ),
                    ),
            ),
          ],
        ),
        NoticeBanner(
          tone: BannerTone.attention,
          icon: AppIconKind.alert,
          title: "This version won't run until you sign it",
          body: <Widget>[Text(describeKeptVersion(workflow.signature, now))],
        ),
        SplitLayout(
          start: PageSection(
            title: 'What changes',
            children: <Widget>[
              FactList(
                facts: <Fact>[
                  for (final WorkflowDifference difference
                      in change.differences)
                    Fact(
                      term: difference.subject,
                      description: <TextSegment>[
                        TextSegment(difference.change),
                      ],
                    ),
                ],
              ),
            ],
          ),
          end: PageSection(
            title: 'Changes',
            children: <Widget>[
              CodeBlock(
                lines: diffDocumentLines(
                  change.signedDocument,
                  change.changedDocument,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _settleChange({
    required String title,
    required String actionLabel,
    required WorkflowChangeSettlement settle,
  }) async {
    if (_isSettling) {
      return;
    }

    final AppRoute changePage = widget.navigation.currentRoute;
    setState(() => _isSettling = true);
    final ActionOutcome outcome = await runShowingRefusal(
      context: context,
      title: title,
      actionLabel: actionLabel,
      action: () => settle(widget.workflowId),
    ).whenComplete(_stopSettling);

    final bool isChangePageShown =
        widget.navigation.currentRoute == changePage;
    if (outcome == ActionOutcome.done && isChangePageShown) {
      widget.navigation.returnTo(_workflowsRoute);
    }
  }

  void _stopSettling() {
    if (mounted) {
      setState(() => _isSettling = false);
    }
  }
}
