import 'package:flutter/material.dart';

import '../../main.dart' show samanvayThemeMode;
import '../../samanvay_design.dart';
import 'session.dart';
import 'shell.dart';
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

class _Gate extends StatelessWidget {
  const _Gate();
  @override
  Widget build(BuildContext context) {
    final s = context.session;
    final repo = s.repo;
    final Widget child = s.restoring
        ? const _Splash()
        : repo == null
            ? const WelcomeScreen()
            : AppShell(key: ValueKey(repo.user.id));
    return AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: child);
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
}
