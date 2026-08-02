enum ChatRole { user, assistant, system, tool }

/// Distinguishes special interactive messages from plain text bubbles.
enum ChatMessageType {
  /// Ordinary text message (default).
  text,

  /// Account type picker — shows Bank / Credit Card / Wallet / Cash / Savings buttons.
  accountTypePicker,

  /// Account picker — shows a list of accounts filtered by a chosen type.
  accountPicker,
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.messageType = ChatMessageType.text,
    this.metadata,
    this.isStreaming = false,
    this.isHidden = false,
    this.timestamp,
    this.sessionId,
  });

  final String id;
  final ChatRole role;
  final String content;

  /// Distinguishes interactive picker messages from plain text.
  final ChatMessageType messageType;

  /// Arbitrary key-value payload for interactive messages.
  /// e.g. for [ChatMessageType.accountPicker]: {'accountType': 'creditCard'}
  final Map<String, dynamic>? metadata;

  final bool isStreaming;

  /// When `true` the message is excluded from the chat UI.
  final bool isHidden;

  final DateTime? timestamp;
  final String? sessionId;

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    ChatMessageType? messageType,
    Map<String, dynamic>? metadata,
    bool? isStreaming,
    bool? isHidden,
    DateTime? timestamp,
    String? sessionId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      metadata: metadata ?? this.metadata,
      isStreaming: isStreaming ?? this.isStreaming,
      isHidden: isHidden ?? this.isHidden,
      timestamp: timestamp ?? this.timestamp,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}
