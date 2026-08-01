enum ChatRole { user, assistant, system, tool }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.timestamp,
  });

  final String id;
  final ChatRole role;
  final String content;
  final bool isStreaming;
  final DateTime? timestamp;

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    bool? isStreaming,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
