import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/language_controller.dart';
import '../core/services/storage_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  final StorageService storageService;

  const SplashScreen({super.key, required this.storageService});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 900);

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  bool _didPrecacheLogo = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: _duration);

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.04), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.04, end: 1), weight: 50),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.08, 0.62, curve: Curves.easeInOut),
      ),
    );

    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 1, curve: Cubic(0.8, 0, 0.2, 1)),
      ),
    );

    _controller.forward().whenComplete(() {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (_, __, ___) =>
              HomeScreen(storageService: widget.storageService),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheLogo) return;
    _didPrecacheLogo = true;
    precacheImage(const AssetImage('assets/pickplanlogo.jpg'), context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageController = context.watch<LanguageController>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Opacity(
            opacity: _opacity.value,
            child: Center(
              child: Transform.scale(
                scale: _scale.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/pickplanlogo.jpg',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, _, __) {
                          return Container(
                            width: 120,
                            height: 120,
                            color: Colors.black,
                            alignment: Alignment.center,
                            child: const Text(
                              'P',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 56,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'PICKPLAN',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      languageController.t(
                        zh: '\u505a\u8ba1\u5212\uff0c\u8bf4\u5927\u767d\u8bdd',
                        en: 'Plan in plain words',
                      ),
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.58),
                        fontSize: 13,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
