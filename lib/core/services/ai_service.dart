import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/todo_item.dart';

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

    final cleanBaseUrl = baseUrl.replaceAll(' ', '');
    final finalBaseUrl = cleanBaseUrl.endsWith('/')
        ? cleanBaseUrl.substring(0, cleanBaseUrl.length - 1)
        : cleanBaseUrl;
    final url = '$finalBaseUrl/chat/completions';

    final requestBody = <String, dynamic>{
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

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode} - ${response.body}');
      }

      final decodedResponse = jsonDecode(utf8.decode(response.bodyBytes));
      final content = decodedResponse['choices'][0]['message']['content'] as String;

      // Handle models that wrap JSON in ```json blocks.
      var sanitized = content.trim();
      final regex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
      final match = regex.firstMatch(sanitized);
      if (match != null) {
        sanitized = match.group(1)!.trim();
      }

      final jsonResult = jsonDecode(sanitized) as Map<String, dynamic>;
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
    } catch (e) {
      throw Exception('AI parsing failed: $e');
    }
  }
}
