import 'package:flutter/material.dart';

import '../models/todo_item.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class TodoProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<TodoItem> _todos = [];

  TodoProvider(this._storageService) {
    _loadTodos();
  }

  List<TodoItem> get todos => _todos;

  Future<void> _loadTodos() async {
    try {
      _todos = await _storageService.getTodos();
    } catch (e) {
      debugPrint('Load todos failed: $e');
      _todos = [];
    }

    for (final todo in _todos) {
      if (!todo.isCompleted) {
        await _scheduleNotifications(todo);
      }
    }

    notifyListeners();
  }

  int _getIdFast(String stringId) {
    // Keep notification IDs in a safe positive int range.
    return stringId.hashCode.abs() % 1000000000;
  }

  Future<void> _scheduleNotifications(TodoItem todo) async {
    if (todo.isCompleted) return;
    final baseId = _getIdFast(todo.id);

    if (todo.reminderTime != null) {
      try {
        await NotificationService.scheduleTodoNotification(
          id: baseId,
          title: 'Reminder: ${todo.title}',
          body: 'Your reminder time has arrived.',
          scheduledTime: todo.reminderTime!,
        );
      } catch (e) {
        debugPrint('Schedule reminder notification failed: $e');
      }
    }

    if (todo.deadline != null) {
      try {
        await NotificationService.scheduleTodoNotification(
          id: baseId + 1,
          title: 'Deadline: ${todo.title}',
          body: 'This task has reached its deadline.',
          scheduledTime: todo.deadline!,
        );
      } catch (e) {
        debugPrint('Schedule deadline notification failed: $e');
      }
    }
  }

  Future<void> _cancelNotifications(TodoItem todo) async {
    final baseId = _getIdFast(todo.id);
    try {
      await NotificationService.cancelNotification(baseId);
      await NotificationService.cancelNotification(baseId + 1);
    } catch (e) {
      debugPrint('Cancel notification failed: $e');
    }
  }

  Future<void> addTodo(TodoItem todo) async {
    _todos.insert(0, todo);
    try {
      await _storageService.saveTodos(_todos);
    } catch (e) {
      debugPrint('Save todos failed (add): $e');
    }
    await _scheduleNotifications(todo);
    notifyListeners();
  }

  Future<void> toggleTodoCompletion(int index) async {
    final current = _todos[index];
    final updated = current.copyWith(isCompleted: !current.isCompleted);
    _todos[index] = updated;

    try {
      await _storageService.saveTodos(_todos);
    } catch (e) {
      debugPrint('Save todos failed (toggle): $e');
    }

    if (updated.isCompleted) {
      await _cancelNotifications(updated);
    } else {
      await _scheduleNotifications(updated);
    }

    notifyListeners();
  }

  Future<void> deleteTodo(int index) async {
    final current = _todos[index];
    _todos.removeAt(index);

    try {
      await _storageService.saveTodos(_todos);
    } catch (e) {
      debugPrint('Save todos failed (delete): $e');
    }

    await _cancelNotifications(current);
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadTodos();
  }
}
