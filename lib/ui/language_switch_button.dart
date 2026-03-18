import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/language_controller.dart';

class LanguageSwitchButton extends StatelessWidget {
  const LanguageSwitchButton({super.key});

  @override
  Widget build(BuildContext context) {
    final languageController = context.watch<LanguageController>();

    return PopupMenuButton<AppLanguage>(
      tooltip: languageController.t(
        zh: '\u5207\u6362\u8bed\u8a00',
        en: 'Switch language',
      ),
      initialValue: languageController.language,
      onSelected: (language) {
        context.read<LanguageController>().setLanguage(language);
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: AppLanguage.zh,
          child: Text('\u4e2d\u6587'),
        ),
        PopupMenuItem(
          value: AppLanguage.en,
          child: Text('English'),
        ),
      ],
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white38),
        ),
        child: Text(
          languageController.isChinese ? '\u4e2d' : 'EN',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
