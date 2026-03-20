import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/todo_item.dart';
import 'ai_proxy_endpoint.dart';

class AIService {
  static Future<TodoItem?> parseTodoFromText({
    required String text,
    required String apiKey,
    required String baseUrl,
    required String modelName,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('API key is empty. Please set it in Settings.');
    }

    final finalBaseUrl = _normalizeBaseUrl(baseUrl);
    final reqBody = _buildRequestBody(text: text, modelName: modelName);

    Exception? directError;
    try {
      final directResponse = await _requestChatCompletions(
        baseUrl: finalBaseUrl,
        apiKey: apiKey,
        requestBody: reqBody,
      );
      return _todoFromChatResponse(directResponse);
    } catch (e) {
      directError = Exception('Direct API failed: $e');
    }

    final proxyBaseUrl = resolveAiProxyBaseUrl();
    if (kIsWeb && proxyBaseUrl != null) {
      try {
        final proxyTodo = await _requestViaProxy(
          proxyBaseUrl: proxyBaseUrl,
          upstreamBaseUrl: finalBaseUrl,
          apiKey: apiKey,
          modelName: modelName,
          text: text,
        );
        if (proxyTodo != null) return proxyTodo;
      } catch (e) {
        throw Exception(
          'AI parsing failed. $directError; Proxy failed: $e',
        );
      }
    }

    throw Exception('AI parsing failed. $directError');
  }

  static String _normalizeBaseUrl(String baseUrl) {
    final cleanBaseUrl = baseUrl.replaceAll(' ', '');
    return cleanBaseUrl.endsWith('/')
        ? cleanBaseUrl.substring(0, cleanBaseUrl.length - 1)
        : cleanBaseUrl;
  }

  static Map<String, dynamic> _buildRequestBody({
    required String text,
    required String modelName,
  }) {
    return <String, dynamic>{
      'model': modelName,
      'messages': [
        {
          'role': 'system',
          'content': '''
You are a task parser.
Extract a task from user text and return JSON only (no markdown), with this schema:
{
  "task": "string",
  "reminder_time": "ISO8601 string or null",
  "deadline": "ISO8601 string or null"
}
Current time: ${DateTime.now().toIso8601String()}
''',
        },
        {'role': 'user', 'content': text},
      ],
      'temperature': 0.1,
    };
  }

  static Future<Map<String, dynamic>> _requestChatCompletions({
    required String baseUrl,
    required String apiKey,
    required Map<String, dynamic> requestBody,
  }) async {
    final url = '$baseUrl/chat/completions';
    final response = await http
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        'status=${response.statusCode}, body=${utf8.decode(response.bodyBytes)}',
      );
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  static TodoItem _todoFromChatResponse(Map<String, dynamic> decodedResponse) {
    final rawContent = decodedResponse['choices'][0]['message']['content'];
    final content = _contentToText(rawContent);
    if (content.trim().isEmpty) {
      throw Exception('Model returned empty content.');
    }
    final jsonResult = _extractJsonMap(content);
    return TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: (jsonResult['task'] as String?)?.trim() ?? 'Untitled Task',
      reminderTime: jsonResult['reminder_time'] != null
          ? DateTime.tryParse(jsonResult['reminder_time'] as String)
          : null,
      deadline: jsonResult['deadline'] != null
          ? DateTime.tryParse(jsonResult['deadline'] as String)
          : null,
    );
  }

  static Map<String, dynamic> _extractJsonMap(String content) {
    var sanitized = content.trim();
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(
      sanitized,
    );
    if (fenced != null) {
      sanitized = fenced.group(1)!.trim();
    }
    return jsonDecode(sanitized) as Map<String, dynamic>;
  }

  static String _contentToText(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      final chunks = <String>[];
      for (final item in content) {
        if (item is String) {
          chunks.add(item);
          continue;
        }
        if (item is Map) {
          final text = item['text'];
          if (text is String && text.isNotEmpty) {
            chunks.add(text);
          }
        }
      }
      return chunks.join('\n');
    }
    return '';
  }

  static Future<TodoItem?> _requestViaProxy({
    required String proxyBaseUrl,
    required String upstreamBaseUrl,
    required String apiKey,
    required String modelName,
    required String text,
  }) async {
    final uri = Uri.parse('$proxyBaseUrl/api/ai/parse');
    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            'apiKey': apiKey,
            'upstreamBaseUrl': upstreamBaseUrl,
            'modelName': modelName,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        'status=${response.statusCode}, body=${utf8.decode(response.bodyBytes)}',
      );
    }

    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final task = (payload['task'] as String?)?.trim();
    if (task == null || task.isEmpty) return null;

    return TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: task,
      reminderTime: payload['reminder_time'] != null
          ? DateTime.tryParse(payload['reminder_time'] as String)
          : null,
      deadline: payload['deadline'] != null
          ? DateTime.tryParse(payload['deadline'] as String)
          : null,
    );
  }
}
