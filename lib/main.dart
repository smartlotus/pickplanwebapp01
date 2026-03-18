import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/language_controller.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/todo_provider.dart';
import 'ui/splash_screen.dart';
import 'ui/theme.dart';

Future<void> _initNotificationsSafely() async {
  try {
    await NotificationService.init();
  } catch (error, stackTrace) {
    debugPrint('NotificationService.init failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = await StorageService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TodoProvider(storageService)),
        ChangeNotifierProvider(create: (_) => LanguageController(storageService)),
      ],
      child: App(storageService: storageService),
    ),
  );

  if (!kIsWeb) {
    await _initNotificationsSafely();
  } else {
    unawaited(_initNotificationsSafely());
  }
}

class App extends StatelessWidget {
  final StorageService storageService;

  const App({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pickplan',
      theme: AppTheme.theme,
      home: SplashScreen(storageService: storageService),
      debugShowCheckedModeBanner: false,
    );
  }
}
