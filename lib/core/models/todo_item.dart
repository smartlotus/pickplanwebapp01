class TodoItem {
  final String id;
  final String title;
  final DateTime? reminderTime;
  final DateTime? deadline;
  final bool isCompleted;

  TodoItem({
    required this.id,
    required this.title,
    this.reminderTime,
    this.deadline,
    this.isCompleted = false,
  });

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      title: json['title'] as String,
      reminderTime: json['reminder_time'] != null
          ? DateTime.tryParse(json['reminder_time'] as String)
          : null,
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'] as String)
          : null,
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'reminder_time': reminderTime?.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  TodoItem copyWith({
    String? id,
    String? title,
    DateTime? reminderTime,
    DateTime? deadline,
    bool? isCompleted,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      reminderTime: reminderTime ?? this.reminderTime,
      deadline: deadline ?? this.deadline,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
