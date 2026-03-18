import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/models/todo_item.dart';
import '../core/services/language_controller.dart';
import '../core/services/notification_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/todo_provider.dart';
import 'language_switch_button.dart';
import 'settings_dialog.dart';
import 'theme.dart';

class ManualModeView extends StatefulWidget {
  final StorageService storageService;

  const ManualModeView({super.key, required this.storageService});

  @override
  State<ManualModeView> createState() => _ManualModeViewState();
}

class _ManualModeViewState extends State<ManualModeView> {
  void _addTodo(TodoItem todo) => context.read<TodoProvider>().addTodo(todo);
  void _toggleTodoCompletion(int index) =>
      context.read<TodoProvider>().toggleTodoCompletion(index);
  void _deleteTodo(int index) => context.read<TodoProvider>().deleteTodo(index);

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: AppTheme.primary, width: 2),
            ),
            padding: const EdgeInsets.all(20),
            child: _AddTodoForm(
              onAdd: (todo) {
                Navigator.pop(context);
                _addTodo(todo);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _testNotification() async {
    final languageController = context.read<LanguageController>();
    final ok = await NotificationService.checkPermissions();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? languageController.t(
                  zh: '\u5df2\u83b7\u53d6\u901a\u77e5\u6743\u9650\uff0c\u6b63\u5728\u53d1\u9001\u6d4b\u8bd5\u901a\u77e5\u3002',
                  en: 'Notification permission granted. Sending test notification...',
                )
              : languageController.t(
                  zh: '\u8bf7\u5148\u5f00\u542f\u901a\u77e5\u6743\u9650\u3002',
                  en: 'Please grant notification permission.',
                ),
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );

    if (!ok) return;
    await NotificationService.showInstantNotification(
      title: languageController.t(
        zh: 'Pickplan \u901a\u77e5\u6d4b\u8bd5',
        en: 'Pickplan notification test',
      ),
      body: languageController.t(
        zh: '\u770b\u5230\u8fd9\u6761\u6d88\u606f\u5c31\u8bf4\u660e\u901a\u77e5\u6b63\u5e38\u3002',
        en: 'If you can see this, notification is working.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageController = context.watch<LanguageController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageController.t(
            zh: '\u4f60\u60f3\u505a\u4ec0\u4e48\uff1f',
            en: 'What do you want to do?',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active, color: AppTheme.primary),
            onPressed: _testNotification,
            tooltip: languageController.t(
              zh: '\u6d4b\u8bd5\u901a\u77e5',
              en: 'Test notifications',
            ),
          ),
          const LanguageSwitchButton(),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) =>
                    SettingsDialog(storageService: widget.storageService),
              );
            },
            tooltip: languageController.t(zh: '\u8bbe\u7f6e', en: 'Settings'),
          ),
        ],
      ),
      body: Consumer<TodoProvider>(
        builder: (context, todoProvider, child) {
          final todos = todoProvider.todos;
          if (todos.isEmpty) {
            return Center(
              child: Text(
                languageController.t(
                  zh: '\u6682\u65e0\u4efb\u52a1\u3002\n\u70b9\u51fb + \u6dfb\u52a0',
                  en: 'No tasks yet.\nTap + to add one.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.withAlpha(160)),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: todos.length,
            itemBuilder: (context, index) {
              final todo = todos[index];
              final dateFormatter = DateFormat('yyyy-MM-dd HH:mm');
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Checkbox(
                    value: todo.isCompleted,
                    onChanged: (_) => _toggleTodoCompletion(index),
                  ),
                  title: Text(
                    todo.title,
                    style: TextStyle(
                      decoration:
                          todo.isCompleted ? TextDecoration.lineThrough : null,
                      color: todo.isCompleted ? Colors.grey : AppTheme.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (todo.reminderTime != null)
                        Text(
                          '${languageController.t(zh: '\u63d0\u9192', en: 'Reminder')}: ${dateFormatter.format(todo.reminderTime!)}',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                          ),
                        ),
                      if (todo.deadline != null)
                        Text(
                          '${languageController.t(zh: '\u622a\u6b62', en: 'Deadline')}: ${dateFormatter.format(todo.deadline!)}',
                          style: const TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.grey),
                    onPressed: () => _deleteTodo(index),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddTodoForm extends StatefulWidget {
  final void Function(TodoItem) onAdd;

  const _AddTodoForm({required this.onAdd});

  @override
  State<_AddTodoForm> createState() => _AddTodoFormState();
}

class _AddTodoFormState extends State<_AddTodoForm> {
  final _titleController = TextEditingController();
  DateTime? _reminderTime;
  DateTime? _deadline;

  Future<void> _pickDateTime(bool isReminder) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isReminder) {
        _reminderTime = selected;
      } else {
        _deadline = selected;
      }
    });
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) return;

    final newTodo = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      reminderTime: _reminderTime,
      deadline: _deadline,
    );
    widget.onAdd(newTodo);
  }

  @override
  Widget build(BuildContext context) {
    final languageController = context.watch<LanguageController>();
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          languageController.t(zh: '\u65b0\u5efa\u4efb\u52a1', en: 'New Task'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: languageController.t(
              zh: '\u4efb\u52a1\u6807\u9898\uff08\u5fc5\u586b\uff09',
              en: 'Task title (required)',
            ),
          ),
          autofocus: true,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${languageController.t(zh: '\u63d0\u9192', en: 'Reminder')}: ${_reminderTime != null ? dateFormatter.format(_reminderTime!) : languageController.t(zh: '\u672a\u8bbe\u7f6e', en: 'Not set')}',
            ),
            TextButton(
              onPressed: () => _pickDateTime(true),
              child: Text(languageController.t(zh: '\u9009\u62e9', en: 'Select')),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${languageController.t(zh: '\u622a\u6b62', en: 'Deadline')}: ${_deadline != null ? dateFormatter.format(_deadline!) : languageController.t(zh: '\u672a\u8bbe\u7f6e', en: 'Not set')}',
            ),
            TextButton(
              onPressed: () => _pickDateTime(false),
              child: Text(languageController.t(zh: '\u9009\u62e9', en: 'Select')),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _submit,
          child: Text(languageController.t(zh: '\u6dfb\u52a0', en: 'Add')),
        ),
      ],
    );
  }
}
