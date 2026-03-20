import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo_item.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  static const String _todosKey = 'cyberpunk_todos_v1';
  static const String _apiKeyKey = 'cyberpunk_api_key_v1';
  static const String _baseUrlKey = 'cyberpunk_base_url_v1';
  static const String _modelNameKey = 'cyberpunk_model_name_v1';
  static const String _languageCodeKey = 'pickplan_language_code_v1';

  static const String defaultBaseUrl = 'https://api.openai.com/v1';
  static const String defaultModelName = 'gpt-4o-mini';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- Todos ---

  Future<List<TodoItem>> getTodos() async {
    final String? todosJson = _prefs.getString(_todosKey);
    if (todosJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(todosJson);
      return decoded
          .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing todos from SharedPreferences: $e');
      }
      return [];
    }
  }

  Future<void> saveTodos(List<TodoItem> todos) async {
    final List<Map<String, dynamic>> jsonList = todos
        .map((e) => e.toJson())
        .toList();
    await _prefs.setString(_todosKey, jsonEncode(jsonList));
  }

  // --- API Settings ---

  String? getApiKey() {
    return _prefs.getString(_apiKeyKey);
  }

  Future<void> saveApiKey(String apiKey) async {
    await _prefs.setString(_apiKeyKey, apiKey);
  }

  String getBaseUrl() {
    return _prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
  }

  Future<void> saveBaseUrl(String baseUrl) async {
    await _prefs.setString(_baseUrlKey, baseUrl);
  }

  String getModelName() {
    final stored = _prefs.getString(_modelNameKey);
    if (stored == null || stored.trim().isEmpty) {
      return defaultModelName;
    }
    if (stored.trim() == 'gpt-3.5-turbo') {
      return defaultModelName;
    }
    return stored;
  }

  Future<void> saveModelName(String modelName) async {
    await _prefs.setString(_modelNameKey, modelName);
  }

  String getLanguageCode() {
    return _prefs.getString(_languageCodeKey) ?? 'zh';
  }

  Future<void> saveLanguageCode(String languageCode) async {
    await _prefs.setString(_languageCodeKey, languageCode);
  }
}
