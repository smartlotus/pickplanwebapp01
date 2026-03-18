import 'package:flutter/foundation.dart';

import 'storage_service.dart';

enum AppLanguage { zh, en }

class LanguageController extends ChangeNotifier {
  final StorageService _storageService;
  AppLanguage _language;

  LanguageController(this._storageService)
      : _language = _fromCode(_storageService.getLanguageCode());

  AppLanguage get language => _language;

  bool get isChinese => _language == AppLanguage.zh;

  String t({required String zh, required String en}) {
    return isChinese ? zh : en;
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    await _storageService.saveLanguageCode(_code(language));
    notifyListeners();
  }

  static AppLanguage _fromCode(String code) {
    return code.toLowerCase() == 'en' ? AppLanguage.en : AppLanguage.zh;
  }

  static String _code(AppLanguage language) {
    return language == AppLanguage.en ? 'en' : 'zh';
  }
}
