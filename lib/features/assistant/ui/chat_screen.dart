import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/chat_message.dart';
import '../providers/assistant_providers.dart';
import '../providers/assistant_session_notifier.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_message_tile.dart';
import 'widgets/model_status_banner.dart';

/// Main chat interface for the Flux AI assistant.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(assistantSessionProvider.notifier);
    if (state == AppLifecycleState.paused) {
      notifier.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      notifier.onAppResumed();
    }
  }

  void _startGuidedTransaction(String type) {
    ref.read(assistantSessionProvider.notifier).startGuidedTransaction(type);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text(
          'All messages in this conversation will be deleted.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(assistantSessionProvider.notifier).clearChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(assistantSessionProvider);

    // Auto-scroll when messages change
    ref.listen<AssistantSessionState>(assistantSessionProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          (prev?.messages.isNotEmpty == true &&
              next.messages.isNotEmpty &&
              prev!.messages.last.content != next.messages.last.content)) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Flux AI',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            ModelStatusBanner(
              status: sessionState.modelStatus,
              onRetry: () => ref.invalidate(modelStatusProvider),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
            ),
            onSelected: (v) {
              if (v == 'clear') _confirmClearChat();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppColors.accent,
                    ),
                    SizedBox(width: 8),
                    Text('Clear chat'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: Builder(
              builder: (_) {
                // Only show user-facing messages — strip hidden tool-call
                // JSON, internal system messages, and tool result messages.
                final visible = sessionState.messages
                    .where(
                      (m) =>
                          !m.isHidden &&
                          m.role != ChatRole.tool &&
                          m.role != ChatRole.system,
                    )
                    .toList();

                // If no messages, show greeting as first item with quick actions
                if (visible.isEmpty) {
                  return ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      _WelcomeGreeting(
                        onAddExpense: () => _startGuidedTransaction('expense'),
                        onAddIncome: () => _startGuidedTransaction('income'),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: visible.length,
                  itemBuilder: (_, i) => ChatMessageTile(message: visible[i]),
                );
              },
            ),
          ),

          // Divider
          const Divider(height: 1, color: Color(0xFFECF0F1)),

          // Input bar
          ChatInputBar(
            isGenerating: sessionState.isGenerating,
            onSend: (text) =>
                ref.read(assistantSessionProvider.notifier).sendMessage(text),
            onCancel: () =>
                ref.read(assistantSessionProvider.notifier).cancelGeneration(),
          ),
        ],
      ),
    );
  }
}

// ── Welcome greeting message ──────────────────────────────────────────────────

class _WelcomeGreeting extends StatelessWidget {
  final VoidCallback? onAddExpense;
  final VoidCallback? onAddIncome;

  const _WelcomeGreeting({this.onAddExpense, this.onAddIncome});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Personalized greeting
                  Consumer(
                    builder: (context, ref, _) {
                      final authService = ref.watch(authServiceProvider);
                      final userName =
                          authService.currentUser?.displayName ?? 'there';
                      final displayName = userName.isNotEmpty
                          ? userName.split(' ')[0]
                          : 'there';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hey $displayName,',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'how can I help you today?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Quick action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionButton(
                          icon: Icons.remove_circle_outline_rounded,
                          label: 'Add Expense',
                          onPressed: onAddExpense ?? () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickActionButton(
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Add Income',
                          onPressed: onAddIncome ?? () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ── Quick action button ────────────────────────────────────────────────────────

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
