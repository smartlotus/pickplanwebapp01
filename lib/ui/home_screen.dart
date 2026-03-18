import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/language_controller.dart';
import '../core/services/storage_service.dart';
import 'ai_mode_view.dart';
import 'manual_mode_view.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;

  const HomeScreen({super.key, required this.storageService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ManualModeView(storageService: widget.storageService),
      AIModeView(storageService: widget.storageService),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final languageController = context.watch<LanguageController>();

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.list_alt),
            label: languageController.t(zh: '\u81ea\u5df1\u505a', en: 'Manual'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.smart_toy),
            label: languageController.t(zh: 'AI\u5e2e\u505a', en: 'AI'),
          ),
        ],
      ),
    );
  }
}
