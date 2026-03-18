
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/services/language_controller.dart';
import '../core/services/storage_service.dart';
import 'theme.dart';

class SettingsDialog extends StatefulWidget {
  final StorageService storageService;

  const SettingsDialog({super.key, required this.storageService});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();

  final List<Map<String, String>> _aiProviders = [
    {
      'name': 'DeepSeek',
      'url': 'https://api.deepseek.com/v1',
      'model': 'deepseek-chat',
    },
    {
      'name': 'Kimi (Moonshot)',
      'url': 'https://api.moonshot.cn/v1',
      'model': 'moonshot-v1-8k',
    },
    {
      'name': 'Tongyi Qwen',
      'url': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      'model': 'qwen-turbo',
    },
    {
      'name': 'GLM',
      'url': 'https://open.bigmodel.cn/api/paas/v4',
      'model': 'glm-4',
    },
    {
      'name': 'SiliconFlow',
      'url': 'https://api.siliconflow.cn/v1',
      'model': 'Qwen/Qwen2.5-7B-Instruct',
    },
    {
      'name': 'OpenAI',
      'url': 'https://api.openai.com/v1',
      'model': 'gpt-3.5-turbo',
    },
    {
      'name': 'Custom',
      'url': '',
      'model': '',
    },
  ];

  String _selectedProviderName = 'Custom';
  bool _isTesting = false;
  String _testResult = '';
  Color _testResultColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = widget.storageService.getApiKey() ?? '';
    _baseUrlController.text = widget.storageService.getBaseUrl();
    _modelController.text = widget.storageService.getModelName();
    _matchProvider();
  }

  void _matchProvider() {
    final url = _baseUrlController.text;
    bool found = false;
    for (final p in _aiProviders) {
      if (p['url'] == url && p['url']!.isNotEmpty) {
        _selectedProviderName = p['name']!;
        found = true;
        break;
      }
    }
    if (!found) {
      _selectedProviderName = 'Custom';
    }
  }

  void _onProviderChanged(String? newName) {
    if (newName == null) return;
    setState(() {
      _selectedProviderName = newName;
      if (newName != 'Custom') {
        final p = _aiProviders.firstWhere((e) => e['name'] == newName);
        _baseUrlController.text = p['url']!;
        _modelController.text = p['model']!;
        _testResult = '';
      }
    });
  }

  Future<void> _testConnection() async {
    final languageController = context.read<LanguageController>();
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      setState(() {
        _testResult = languageController.t(
          zh: '\u8bf7\u5148\u586b\u5199 Base URL \u548c API Key\u3002',
          en: 'Please fill Base URL and API Key.',
        );
        _testResultColor = AppTheme.errorColor;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = languageController.t(
        zh: '\u6b63\u5728\u6d4b\u8bd5\u8fde\u63a5\u2026',
        en: 'Testing connection...',
      );
      _testResultColor = Colors.blue;
    });

    try {
      final cleanBaseUrl = baseUrl.replaceAll(' ', '');
      final finalBaseUrl = cleanBaseUrl.endsWith('/')
          ? cleanBaseUrl.substring(0, cleanBaseUrl.length - 1)
          : cleanBaseUrl;
      final uri = Uri.parse('$finalBaseUrl/models');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        _isTesting = false;
        if (response.statusCode == 200) {
          _testResult = languageController.t(
            zh: '\u8fde\u63a5\u6210\u529f\uff08200\uff09\u3002',
            en: 'Connection OK (200).',
          );
          _testResultColor = Colors.green;
        } else {
          final body = response.body.length > 80
              ? '${response.body.substring(0, 80)}...'
              : response.body;
          _testResult =
              '${languageController.t(zh: '\u8fde\u63a5\u5931\u8d25', en: 'Connection failed')}: ${response.statusCode}\n$body';
          _testResultColor = AppTheme.errorColor;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testResult =
            '${languageController.t(zh: '\u8fde\u63a5\u5f02\u5e38', en: 'Connection error')}:\n$e';
        _testResultColor = AppTheme.errorColor;
      });
    }
  }

  Future<void> _save() async {
    await widget.storageService.saveApiKey(_apiKeyController.text.trim());
    await widget.storageService.saveBaseUrl(_baseUrlController.text.trim());
    await widget.storageService.saveModelName(_modelController.text.trim());
    if (mounted) Navigator.pop(context);
  }

  Future<void> _launchURL(String url) async {
    final languageController = context.read<LanguageController>();
    final uri = Uri.parse(url);
    final mode =
        kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
    if (!await launchUrl(uri, mode: mode)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageController.t(
              zh: '\u65e0\u6cd5\u6253\u5f00\u94fe\u63a5',
              en: 'Unable to open URL',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageController = context.watch<LanguageController>();
    final isCustom = _selectedProviderName == 'Custom';

    return AlertDialog(
      title: Text(
        languageController.t(
          zh: 'AI \u5f15\u64ce\u8bbe\u7f6e',
          en: 'AI Engine Settings',
        ),
        style: const TextStyle(color: AppTheme.primary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageController.t(
                zh: '\u53ef\u5feb\u901f\u9009\u62e9\u5e73\u53f0\uff0c\u6216\u81ea\u5b9a\u4e49\u63a5\u53e3\u4e0e\u6a21\u578b\u3002',
                en: 'Pick a provider quickly, or use custom endpoint/model.',
              ),
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedProviderName,
              dropdownColor: AppTheme.cardColor,
              style: const TextStyle(color: AppTheme.textColor),
              decoration: InputDecoration(
                labelText: languageController.t(
                  zh: '\u5e73\u53f0',
                  en: 'Provider',
                ),
              ),
              items: _aiProviders.map((p) {
                return DropdownMenuItem<String>(
                  value: p['name'],
                  child: Text(p['name']!),
                );
              }).toList(),
              onChanged: _onProviderChanged,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _baseUrlController,
              enabled: isCustom,
              decoration: InputDecoration(
                labelText: languageController.t(
                  zh: 'Base URL',
                  en: 'Base URL',
                ),
              ),
              style: TextStyle(
                color: isCustom ? AppTheme.textColor : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _modelController,
              enabled: isCustom,
              decoration: InputDecoration(
                labelText: languageController.t(
                  zh: '\u6a21\u578b',
                  en: 'Model',
                ),
              ),
              style: TextStyle(
                color: isCustom ? AppTheme.textColor : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: languageController.t(
                  zh: 'API Key',
                  en: 'API Key',
                ),
              ),
              obscureText: true,
            ),
            if (kIsWeb)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  languageController.t(
                    zh: 'Web/PWA\uff1aAPI Key \u4f1a\u5b58\u5728\u6d4f\u89c8\u5668\u672c\u5730\u5b58\u50a8\uff0c\u6b63\u5f0f\u73af\u5883\u5efa\u8bae\u4f7f\u7528\u540e\u7aef\u4ee3\u7406\u3002',
                    en: 'Web/PWA: API key is stored in browser storage. Use backend proxy in production.',
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.orangeAccent),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.network_check, size: 18),
                label: Text(
                  languageController.t(
                    zh: '\u6d4b\u8bd5\u8fde\u63a5',
                    en: 'Test Connection',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_testResult.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testResultColor.withOpacity(0.1),
                  border: Border.all(color: _testResultColor.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _testResult,
                  style: TextStyle(color: _testResultColor, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Divider(color: Colors.grey, thickness: 0.5),
            const SizedBox(height: 12),
            Center(
              child: InkWell(
                onTap: () => _launchURL('https://pickplan.netlify.app/'),
                child: Text(
                  languageController.t(
                    zh: '\u5b98\u65b9\u7f51\u7ad9\uff1ahttps://pickplan.netlify.app/',
                    en: 'Official Website: https://pickplan.netlify.app/',
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            languageController.t(zh: '\u53d6\u6d88', en: 'Cancel'),
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(languageController.t(zh: '\u4fdd\u5b58', en: 'Save')),
        ),
      ],
    );
  }
}
