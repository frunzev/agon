import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/rules/unicode_white_space.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/message_field.dart';

typedef MessageSending = Future<ActionOutcome> Function(String text);

class ChatComposer extends StatefulWidget {
  const ChatComposer({required this.onSend, super.key});

  final MessageSending onSend;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messageFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? sendTypedMessage = _isSending
        ? null
        : () => unawaited(_send());

    return Container(
      padding: const EdgeInsets.only(top: AppSpacing.space3),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: MessageField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              hintText: 'Message the agent',
              fieldLabel: 'Message to the agent',
              onSend: sendTypedMessage,
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          AppButton.primary(
            label: 'Send',
            icon: AppIconKind.send,
            onPressed: sendTypedMessage,
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final String message = trimUnicodeWhiteSpace(_messageController.text);
    if (message.isEmpty) {
      return;
    }

    setState(() => _isSending = true);
    _messageFocusNode.requestFocus();
    final ActionOutcome outcome;
    try {
      outcome = await widget.onSend(message);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }

    if (outcome == ActionOutcome.done && mounted) {
      _clearSentMessage(message);
    }
  }

  void _clearSentMessage(String sentMessage) {
    final bool isSentTextStillTyped =
        trimUnicodeWhiteSpace(_messageController.text) == sentMessage;
    if (isSentTextStillTyped) {
      _messageController.clear();
    }
  }
}
