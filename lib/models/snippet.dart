class Snippet {
  int? id;
  String title;
  String content;
  int useCount;
  bool isPinned;
  DateTime createdAt;
  DateTime lastUsedAt;

  Snippet({
    this.id,
    this.title = '',
    this.content = '',
    this.useCount = 0,
    this.isPinned = false,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       lastUsedAt = lastUsedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'useCount': useCount,
      'isPinned': isPinned ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'lastUsedAt': lastUsedAt.toIso8601String(),
    };
  }

  factory Snippet.fromMap(Map<String, dynamic> map) {
    return Snippet(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      useCount: map['useCount'] as int? ?? 0,
      isPinned: (map['isPinned'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastUsedAt: DateTime.parse(map['lastUsedAt'] as String),
    );
  }
}
