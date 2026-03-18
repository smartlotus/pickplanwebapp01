import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/models/todo_item.dart';
import '../core/services/ai_service.dart';
import '../core/services/language_controller.dart';
import '../core/services/storage_service.dart';
import '../core/services/todo_provider.dart';
import 'language_switch_button.dart';
import 'settings_dialog.dart';
import 'theme.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final TodoItem? parsedTodo;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.parsedTodo,
  });
}

class AIModeView extends StatefulWidget {
  final StorageService storageService;

  const AIModeView({super.key, required this.storageService});

  @override
  State<AIModeView> createState() => _AIModeViewState();
}

class _AIModeViewState extends State<AIModeView> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) =>
          SettingsDialog(storageService: widget.storageService),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final languageController = context.read<LanguageController>();
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final apiKey = widget.storageService.getApiKey() ?? '';
    final baseUrl = widget.storageService.getBaseUrl();
    final modelName = widget.storageService.getModelName();

    if (apiKey.isEmpty) {
      _showError(
        languageController.t(
          zh: '\u8bf7\u5148\u5728\u8bbe\u7f6e\u4e2d\u586b\u5199 API Key\u3002',
          en: 'Please set API Key first from Settings.',
        ),
      );
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final todo = await AIService.parseTodoFromText(
        text: text,
        apiKey: apiKey,
        baseUrl: baseUrl,
        modelName: modelName,
      );

      if (todo != null && mounted) {
        context.read<TodoProvider>().addTodo(todo);
      }

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: todo != null
                  ? languageController.t(
                      zh: '\u89e3\u6790\u6210\u529f\uff0c\u5df2\u6dfb\u52a0\u4efb\u52a1\u3002',
                      en: 'Parsed successfully. Task has been added.',
                    )
                  : languageController.t(
                      zh: '\u672a\u80fd\u89e3\u6790\u51fa\u6709\u6548\u4efb\u52a1\u3002',
                      en: 'Could not parse a valid task.',
                    ),
              isUser: false,
              parsedTodo: todo,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  '${languageController.t(zh: '\u89e3\u6790\u5931\u8d25', en: 'Parse failed')}: $e',
              isUser: false,
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _scrollToBottom();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final languageController = context.watch<LanguageController>();
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primary.withAlpha(50) : AppTheme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
          border: Border.all(
            color: isUser ? AppTheme.primary : AppTheme.primary.withAlpha(150),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                color: AppTheme.textColor,
                fontSize: 16,
              ),
            ),
            if (message.parsedTodo != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Builder(
                  builder: (context) {
                    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${languageController.t(zh: '\u4efb\u52a1', en: 'Task')}: ${message.parsedTodo!.title}',
                          style: const TextStyle(color: AppTheme.primary),
                        ),
                        if (message.parsedTodo!.reminderTime != null)
                          Text(
                            '${languageController.t(zh: '\u63d0\u9192', en: 'Reminder')}: ${dateFormatter.format(message.parsedTodo!.reminderTime!)}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        if (message.parsedTodo!.deadline != null)
                          Text(
                            '${languageController.t(zh: '\u622a\u6b62', en: 'Deadline')}: ${dateFormatter.format(message.parsedTodo!.deadline!)}',
                            style: const TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
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
          const LanguageSwitchButton(),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: languageController.t(zh: '\u8bbe\u7f6e', en: 'Settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      languageController.t(
                        zh: '\u8bd5\u8bd5\uff1a\u660e\u5929\u4e0b\u53483\u70b9\u63d0\u9192\u6211\u7ed9\u5ba2\u6237\u6253\u7535\u8bdd\u3002',
                        en: 'Try: "Remind me tomorrow at 3 PM to call client."',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.withAlpha(150)),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 10, bottom: 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.cardColor,
              border: Border(top: BorderSide(color: Colors.black54, width: 2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: languageController.t(
                        zh: '\u63cf\u8ff0\u4f60\u7684\u4efb\u52a1\u2026',
                        en: 'Describe a task...',
                      ),
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.black45,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: AppTheme.textColor),
                    onPressed: _sendMessage,
                    tooltip: languageController.t(zh: '\u53d1\u9001', en: 'Send'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
