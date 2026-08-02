import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Text input bar at the bottom of the chat screen.
///
/// - Send button enabled when input is non-empty and [isGenerating] is false.
/// - Cancel button visible only while [isGenerating] is true.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.isGenerating,
    required this.onSend,
    required this.onCancel,
  });

  final bool isGenerating;
  final void Function(String text) onSend;
  final VoidCallback onCancel;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isGenerating) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isGenerating
                      ? AppColors.textLight
                      : AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: TextField(
                controller: _controller,
                enabled: !widget.isGenerating,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Ask Flux AI…',
                  hintStyle: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 14,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: widget.isGenerating ? null : (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Cancel button (visible while generating)
          if (widget.isGenerating)
            _IconBtn(
              icon: Icons.stop_circle_rounded,
              color: AppColors.accent,
              tooltip: 'Cancel',
              onTap: widget.onCancel,
            )
          else
            // Send button
            _IconBtn(
              icon: Icons.send_rounded,
              color: _hasText ? AppColors.primary : AppColors.textLight,
              tooltip: 'Send',
              onTap: _hasText ? _send : null,
            ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }
}
