import 'package:flutter/foundation.dart';
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
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

  Future<void> _refreshTodos({bool showFeedback = true}) async {
    await context.read<TodoProvider>().refresh();
    if (!mounted || !showFeedback) return;

    final languageController = context.read<LanguageController>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          languageController.t(
            zh: '\u5df2\u5237\u65b0\u5f85\u529e\u5217\u8868\u3002',
            en: 'Todo list refreshed.',
          ),
        ),
      ),
    );
  }

  String _permissionGuide(LanguageController languageController) {
    if (!kIsWeb) {
      return languageController.t(
        zh:
            '\u8bf7\u5728\u7cfb\u7edf\u8bbe\u7f6e\u91cc\u5f00\u542f Pickplan \u7684\u901a\u77e5\u6743\u9650\uff0c\u7136\u540e\u91cd\u8bd5\u3002',
        en:
            'Enable notification permission for Pickplan in system settings, then try again.',
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return languageController.t(
        zh:
            'iPhone/iPad \u9700\u8981\u5148\u5728 Safari \u4e2d\u201c\u6dfb\u52a0\u5230\u4e3b\u5c4f\u5e55\u201d\uff0c\u518d\u4ece\u684c\u9762\u56fe\u6807\u6253\u5f00\u5e76\u5141\u8bb8\u901a\u77e5\u3002\u82e5\u6b64\u524d\u62d2\u7edd\uff0c\u8bf7\u5230\u7cfb\u7edf\u8bbe\u7f6e\u91cd\u65b0\u5f00\u542f\u901a\u77e5\u6743\u9650\u3002',
        en:
            'On iPhone/iPad, first Add to Home Screen in Safari, then open from the home-screen icon and allow notifications. If previously denied, re-enable notifications in system settings.',
      );
    }

    return languageController.t(
      zh:
          '\u8bf7\u5728\u6d4f\u89c8\u5668\u7ad9\u70b9\u8bbe\u7f6e\u91cc\u5141\u8bb8\u901a\u77e5\uff08\u5730\u5740\u680f\u9501\u56fe\u6807/\u7ad9\u70b9\u8bbe\u7f6e -> \u901a\u77e5 -> \u5141\u8bb8\uff09\uff0c\u7136\u540e\u5237\u65b0\u9875\u9762\u91cd\u8bd5\u3002',
      en:
          'Allow notifications in your browser site settings (lock icon/site settings -> Notifications -> Allow), then refresh and try again.',
    );
  }

  void _showPermissionHelp(LanguageController languageController) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageController.t(
            zh: '\u901a\u77e5\u672a\u5f00\u542f',
            en: 'Notifications disabled',
          ),
        ),
        content: Text(_permissionGuide(languageController)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              languageController.t(
                zh: '\u6211\u77e5\u9053\u4e86',
                en: 'OK',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationLimits(LanguageController languageController) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageController.t(
            zh: '\u7f51\u9875\u63d0\u9192\u8bf4\u660e',
            en: 'Web reminder notes',
          ),
        ),
        content: Text(
          languageController.t(
            zh:
                '\u7f51\u9875\u7248\u63d0\u9192\u5e76\u4e0d\u50cf Android App \u90a3\u6837\u7edd\u5bf9\u51c6\u65f6\u3002\u4f60\u73b0\u5728\u7684 Cloudflare Worker \u6bcf\u5206\u949f\u626b\u4e00\u6b21\uff0c\u6240\u4ee5\u540e\u53f0\u63a8\u9001\u901a\u5e38\u4f1a\u5728\u8bbe\u5b9a\u65f6\u95f4\u540e 1 \u5206\u949f\u5185\u9001\u8fbe\u3002iPhone/iPad \u53ea\u6709\u4ece Safari \u201c\u6dfb\u52a0\u5230\u4e3b\u5c4f\u5e55\u201d\u540e\uff0c\u540e\u53f0\u63a8\u9001\u624d\u6bd4\u8f83\u53ef\u9760\uff1b\u666e\u901a Safari \u6807\u7b7e\u9875\u9000\u5230\u540e\u53f0\u540e\uff0c\u63d0\u9192\u53ef\u80fd\u53ea\u4f1a\u5728\u56de\u5230\u9875\u9762\u65f6\u624d\u51fa\u73b0\u3002\u90e8\u5206 Android \u5382\u5546\u7684\u7701\u7535\u7ba1\u7406\u4e5f\u53ef\u80fd\u5ef6\u8fdf Chrome \u540e\u53f0\u901a\u77e5\u3002',
            en:
                'Web reminders are not as exact as the Android app. Your current Cloudflare Worker scans once per minute, so background push usually arrives within about one minute after the scheduled time. On iPhone/iPad, background push is only reliable after adding the site to the Home Screen from Safari. In a normal Safari tab, reminders may only appear after you return to the page. Some Android vendors also delay Chrome background notifications under battery-saving rules.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              languageController.t(
                zh: '\u6211\u77e5\u9053\u4e86',
                en: 'OK',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebNoticeCard(LanguageController languageController) {
    if (!kIsWeb) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.info_outline,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                languageController.t(
                  zh:
                      '\u7f51\u9875\u7248\u540e\u53f0\u63d0\u9192\u901a\u5e38\u4f1a\u5728\u8bbe\u5b9a\u65f6\u95f4\u540e 1 \u5206\u949f\u5185\u9001\u8fbe\u3002iPhone/iPad \u8bf7\u5148\u201c\u6dfb\u52a0\u5230\u4e3b\u5c4f\u5e55\u201d\uff0c\u90e8\u5206 Android \u7701\u7535\u7ba1\u7406\u4e5f\u53ef\u80fd\u5ef6\u8fdf\u901a\u77e5\u3002',
                  en:
                      'Web background reminders usually arrive within about one minute after the scheduled time. On iPhone/iPad, add the site to the Home Screen first. Some Android battery rules may also delay notifications.',
                ),
                style: const TextStyle(fontSize: 12.5, height: 1.45),
              ),
            ),
            TextButton(
              onPressed: () => _showNotificationLimits(languageController),
              child: Text(
                languageController.t(
                  zh: '\u8be6\u60c5',
                  en: 'Details',
                ),
              ),
            ),
          ],
        ),
      ),
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
                  zh:
                      '\u5df2\u83b7\u53d6\u901a\u77e5\u6743\u9650\uff0c\u6b63\u5728\u53d1\u9001\u6d4b\u8bd5\u901a\u77e5\u3002',
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

    if (!ok) {
      _showPermissionHelp(languageController);
      return;
    }

    try {
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageController.t(
              zh: '\u901a\u77e5\u6d4b\u8bd5\u8bf7\u6c42\u5df2\u53d1\u51fa\uff0c\u4f46\u6d4f\u89c8\u5668\u6ca1\u6709\u5b8c\u6210\u63a8\u9001\u53d1\u9001\u3002\u8bf7\u5237\u65b0\u540e\u91cd\u8bd5\uff0c\u6216\u91cd\u65b0\u5f00\u542f\u901a\u77e5\u6743\u9650\u3002',
              en: 'The test request was sent, but the browser did not complete push delivery. Refresh and try again, or re-enable notification permission.',
            ),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      _showNotificationLimits(languageController);
    }
  }

  Widget _buildEmptyState(LanguageController languageController) {
    return RefreshIndicator(
      onRefresh: () => _refreshTodos(showFeedback: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          _buildWebNoticeCard(languageController),
          SizedBox(height: MediaQuery.of(context).size.height * 0.24),
          Text(
            languageController.t(
              zh: '\u6682\u65e0\u4efb\u52a1\u3002\n\u70b9\u51fb + \u6dfb\u52a0',
              en: 'No tasks yet.\nTap + to add one.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.withAlpha(160)),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoList(
    LanguageController languageController,
    List<TodoItem> todos,
  ) {
    final hasWebNotice = kIsWeb;

    return RefreshIndicator(
      onRefresh: () => _refreshTodos(showFeedback: false),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: todos.length + (hasWebNotice ? 1 : 0),
        itemBuilder: (context, index) {
          if (hasWebNotice && index == 0) {
            return _buildWebNoticeCard(languageController);
          }

          final todoIndex = index - (hasWebNotice ? 1 : 0);
          final todo = todos[todoIndex];
          final dateFormatter = DateFormat('yyyy-MM-dd HH:mm');

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Checkbox(
                value: todo.isCompleted,
                onChanged: (_) => _toggleTodoCompletion(todoIndex),
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
                onPressed: () => _deleteTodo(todoIndex),
              ),
            ),
          );
        },
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
            icon: const Icon(
              Icons.notifications_active,
              color: AppTheme.primary,
            ),
            onPressed: _testNotification,
            tooltip: languageController.t(
              zh: '\u6d4b\u8bd5\u901a\u77e5',
              en: 'Test notifications',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshTodos(),
            tooltip: languageController.t(
              zh: '\u5237\u65b0',
              en: 'Refresh',
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
            tooltip: languageController.t(
              zh: '\u8bbe\u7f6e',
              en: 'Settings',
            ),
          ),
        ],
      ),
      body: Consumer<TodoProvider>(
        builder: (context, todoProvider, child) {
          final todos = todoProvider.todos;
          if (todos.isEmpty) {
            return _buildEmptyState(languageController);
          }
          return _buildTodoList(languageController, todos);
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
          languageController.t(
            zh: '\u65b0\u5efa\u4efb\u52a1',
            en: 'New Task',
          ),
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
              child: Text(
                languageController.t(
                  zh: '\u9009\u62e9',
                  en: 'Select',
                ),
              ),
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
              child: Text(
                languageController.t(
                  zh: '\u9009\u62e9',
                  en: 'Select',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _submit,
          child: Text(
            languageController.t(
              zh: '\u6dfb\u52a0',
              en: 'Add',
            ),
          ),
        ),
      ],
    );
  }
}
