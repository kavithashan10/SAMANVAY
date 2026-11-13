import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models.dart';
import '../core/repository.dart';
import '../data/demo_repository.dart';
import '../data/live_repository.dart';

/// Who is signed in, and which data source the screens use.
class AppSession extends ChangeNotifier {
  AppSession(Future<void> backendBoot) {
    backendBoot.then((_) async {
      backendReady = true;
      await _restore();
    }).catchError((Object e) {
      backendError = 'Live sign-in is not configured in this build. The LPU demonstration works offline.';
      restoring = false;
      notifyListeners();
    });
  }

  bool backendReady = false;
  String? backendError;
  bool restoring = true;
  SamanvayRepository? repo;

  /// Bumped after every change so screens reload their data.
  int revision = 0;
  void touch() {
    revision++;
    notifyListeners();
  }

  Future<void> _restore() async {
    try {
      if (Supabase.instance.client.auth.currentSession != null) {
        final user = await LiveRepository.loadCurrentUser();
        if (user != null) repo = LiveRepository(user);
      }
    } catch (_) {
      // A stale session simply returns the user to the welcome screen.
    }
    restoring = false;
    notifyListeners();
  }

  Future<String?> signIn(String email, String password) async {
    if (!backendReady) return backendError ?? 'Live sign-in is still starting. Try again in a moment.';
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email.trim(), password: password);
      final user = await LiveRepository.loadCurrentUser();
      if (user == null) return 'Signed in, but the profile could not be loaded.';
      repo = LiveRepository(user);
      touch();
      return null;
    } on AuthException catch (e) {
      return e.message.toLowerCase().contains('email not confirmed')
          ? 'Confirm your email first — check your inbox, then sign in.'
          : e.message.toLowerCase().contains('invalid')
              ? 'That email and password do not match an account.'
              : e.message;
    } catch (e) {
      return friendlyError(e);
    }
  }

  /// Returns (success, message).
  Future<(bool, String)> signUp(String name, String email, String password) async {
    if (!backendReady) return (false, backendError ?? 'Live sign-up is not available yet.');
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: 'in.samanvay://login-callback/',
        data: {'display_name': name.trim()},
      );
      if (res.session != null) {
        final user = await LiveRepository.loadCurrentUser();
        if (user != null) {
          repo = LiveRepository(user);
          touch();
        }
        return (true, 'Welcome to SAMANVAY.');
      }
      return (true, 'Almost there — open the confirmation email we sent, then sign in.');
    } on AuthException catch (e) {
      return (false, e.message);
    } catch (e) {
      return (false, friendlyError(e));
    }
  }

  Future<String> resendConfirmation(String email) async {
    try {
      await Supabase.instance.client.auth.resend(type: OtpType.signup, email: email.trim(), emailRedirectTo: 'in.samanvay://login-callback/');
      return 'Confirmation email sent again. Check inbox and spam.';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return friendlyError(e);
    }
  }

  void enterDemo(AppRole role, {String departmentId = 'power'}) {
    final demo = DemoRepository(role: role, departmentId: departmentId);
    demo.store.addListener(touch);
    repo = demo;
    touch();
  }

  void switchDemoRole(AppRole role, {String? departmentId}) {
    final r = repo;
    if (r is DemoRepository) {
      r.switchRole(role, departmentId: departmentId);
      touch();
    }
  }

  Future<void> signOut() async {
    final r = repo;
    if (r is DemoRepository) {
      r.store.removeListener(touch);
    } else if (backendReady) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
    repo = null;
    touch();
  }
}

class SessionScope extends InheritedNotifier<AppSession> {
  const SessionScope({super.key, required AppSession session, required super.child}) : super(notifier: session);
  static AppSession of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}

extension SessionContext on BuildContext {
  AppSession get session => SessionScope.of(this);
  SamanvayRepository get repo => SessionScope.of(this).repo!;
}
