import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/screens/pairing.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/code_tracking.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/numbered_list.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

const String _pageTitle = 'Pair a device';
const String _cancelLabel = 'Cancel';
const String _showNewCodeLabel = 'Show a new code';

const List<String> _newDeviceSteps = <String>[
  'Open the app and choose how the device will be used.',
  'Enter this code, or scan the QR code with a phone.',
  'Come back here, check four words match, then approve.',
];

class PairingCodeScreen extends StatefulWidget {
  const PairingCodeScreen({
    required this.pairingRepository,
    required this.workspaceRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final PairingRepository pairingRepository;
  final WorkspaceRepository workspaceRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  State<PairingCodeScreen> createState() => _PairingCodeScreenState();
}

class _PairingCodeScreenState extends State<PairingCodeScreen> {
  bool _isCancelling = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.pairingRepository,
        widget.workspaceRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final String? rendezvousProblem = widget.pairingRepository
        .findActiveSession()
        ?.rendezvousProblem;

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: _pageTitle,
          backLink: BackLink(
            label: 'Devices',
            onPressed: widget.navigation.closeRoute,
          ),
          summary: const <TextSegment>[
            TextSegment(
              'Pair it once, then use it in any of your workspaces.',
            ),
          ],
          actions: <Widget>[
            AppButton.secondary(
              label: _cancelLabel,
              onPressed: _isCancelling
                  ? null
                  : () => unawaited(_cancelPairing()),
            ),
          ],
        ),
        if (rendezvousProblem != null)
          RendezvousProblemBanner(problem: rendezvousProblem),
        SplitLayout(
          start: _buildCodeCard(context),
          end: PageSection(
            title: 'On the new device',
            children: <Widget>[
              const NumberedList(entries: _newDeviceSteps),
              ?_buildRequestState(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _cancelPairing() async {
    setState(() => _isCancelling = true);
    final ActionOutcome outcome = await runShowingRefusal(
      context: context,
      title: _pageTitle,
      actionLabel: _cancelLabel,
      action: _cancelShownCode,
    ).whenComplete(_stopCancelling);

    if (outcome == ActionOutcome.done && mounted) {
      widget.navigation.closeRoute();
    }
  }

  void _stopCancelling() {
    if (mounted) {
      setState(() => _isCancelling = false);
    }
  }

  Future<void> _cancelShownCode() async {
    if (widget.pairingRepository.findActiveSession() != null) {
      await widget.pairingRepository.cancelPairing();
    }
  }

  Widget _buildCodeCard(BuildContext context) {
    final PairingSession? session = widget.pairingRepository
        .findActiveSession();
    final String serverAddress = widget.workspaceRepository
        .currentWorkspace()
        .appServerAddress;
    final List<Widget> cardContent = session == null
        ? <Widget>[
            const Text('This code expired.'),
            AppButton.primary(
              label: _showNewCodeLabel,
              onPressed: () => unawaited(_showNewCode()),
            ),
          ]
        : <Widget>[
            PairingQrCode(
              invitation: PairingInvitation(
                code: session.code,
                serverAddress: serverAddress,
              ),
            ),
            Semantics(
              label: 'Pairing code ${session.code}',
              excludeSemantics: true,
              child: Text(
                session.code,
                style: AppTextStyles.monospace.copyWith(
                  color: AppColors.ink,
                  fontSize: AppFontSizes.title,
                  fontWeight: FontWeight.w700,
                  letterSpacing: codeLetterSpacingFor(
                    textScaler: MediaQuery.textScalerOf(context),
                    fontSize: AppFontSizes.title,
                  ),
                ),
              ),
            ),
            StatusLabel(
              text: describeTimeLeft(
                expiresAt: session.expiresAt,
                now: widget.clock.now(),
              ),
              tone: StatusTone.muted,
              icon: AppIconKind.clock,
            ),
            MixedText(<TextSegment>[
              const TextSegment('App server '),
              TextSegment.monospace(describeServerHost(serverAddress)),
            ], style: AppTextStyles.smallMuted),
          ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space5),
      decoration: BoxDecoration(
        color: AppColors.raised,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: Column(children: spaceVertically(cardContent, AppSpacing.space3)),
    );
  }

  Future<void> _showNewCode() {
    return runShowingRefusal(
      context: context,
      title: _pageTitle,
      actionLabel: _showNewCodeLabel,
      action: widget.pairingRepository.startPairing,
    );
  }

  Widget? _buildRequestState() {
    if (widget.pairingRepository.findActiveSession() == null) {
      return null;
    }

    final PairingRequest? request = widget.pairingRepository
        .findPendingRequest();
    if (request == null) {
      return const StatusLabel(
        text: 'Waiting for the new device',
        tone: StatusTone.normal,
        icon: AppIconKind.spinner,
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: AppButton.primary(
        label: 'Check ${request.deviceName}',
        onPressed: () =>
            widget.navigation.openRoute(const PairingApprovalRoute()),
      ),
    );
  }
}
