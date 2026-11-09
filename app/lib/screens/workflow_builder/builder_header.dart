import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/compact_page_header.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const String cancelBuildingLabel = 'Cancel';
const String signAndSaveLabel = 'Sign and save';

typedef LeaveBuilderAction = FutureOr<void> Function();

class BuilderHeader extends StatefulWidget {
  const BuilderHeader({
    required this.title,
    required this.summary,
    required this.onBack,
    required this.onCancel,
    required this.onSigned,
    super.key,
  });

  final String title;
  final String summary;
  final VoidCallback onBack;
  final LeaveBuilderAction onCancel;
  final LeaveBuilderAction onSigned;

  @override
  State<BuilderHeader> createState() => _BuilderHeaderState();
}

class _BuilderHeaderState extends State<BuilderHeader> {
  bool _isLeaving = false;

  @override
  Widget build(BuildContext context) {
    return CompactPageHeader(
      title: widget.title,
      summary: widget.summary,
      backLink: BackLink(label: 'Workflows', onPressed: widget.onBack),
      actions: <Widget>[
        AppButton.secondary(
          label: cancelBuildingLabel,
          onPressed: _isLeaving
              ? null
              : () => unawaited(_leaveOnce(widget.onCancel)),
        ),
        AppButton.primary(
          label: signAndSaveLabel,
          onPressed: _isLeaving
              ? null
              : () => unawaited(_leaveOnce(widget.onSigned)),
        ),
      ],
    );
  }

  Future<void> _leaveOnce(LeaveBuilderAction leave) async {
    if (_isLeaving) {
      return;
    }

    setState(() => _isLeaving = true);
    try {
      await leave();
    } finally {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        setState(() => _isLeaving = false);
      }
    }
  }
}
