class MessageModel {
  final int? id;
  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  final DateTime timestamp;
  final bool isAudio;

  MessageModel({
    this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isAudio = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'is_audio': isAudio ? 1 : 0,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as int?,
      role: map['role'] as String,
      content: map['content'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isAudio: (map['is_audio'] as int) == 1,
    );
  }

  /// Convert to the format OpenAI API expects
  Map<String, String> toOpenAI() {
    return {'role': role, 'content': content};
  }
}
