import 'package:flutter/material.dart';

import '../../main.dart' show samanvayThemeMode;
import '../../samanvay_design.dart';
import 'session.dart';
import 'shell.dart';
import 'splash.dart';
import 'welcome.dart';

/// SAMANVAY application root: one flow for every role, running on the device.
class SamanvayV2App extends StatefulWidget {
  const SamanvayV2App({super.key});
  @override
  State<SamanvayV2App> createState() => _SamanvayV2AppState();
}

class _SamanvayV2AppState extends State<SamanvayV2App> {
  final AppSession session = AppSession();

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: session,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: samanvayThemeMode,
        builder: (context, mode, _) => MaterialApp(
          title: 'SAMANVAY',
          debugShowCheckedModeBanner: false,
          theme: samanvayAppTheme(dark: false),
          darkTheme: samanvayAppTheme(dark: true),
          themeMode: mode,
          home: const _Gate(),
        ),
      ),
    );
  }
}

class _Gate extends StatefulWidget {
  const _Gate();
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    final s = context.session;
    final repo = s.repo;
    final Widget child = s.restoring || !_splashDone
        ? SamanvaySplash(key: const ValueKey('splash'), onDone: () => setState(() => _splashDone = true))
        : repo == null
            ? const WelcomeScreen()
            : AppShell(key: ValueKey(repo.user.id));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: .97, end: 1.0).animate(anim), child: child),
      ),
      child: child,
    );
  }
}
