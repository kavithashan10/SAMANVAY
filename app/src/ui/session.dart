import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';
import '../core/repository.dart';
import '../data/local_repository.dart';

/// Holds the person's chosen role and the app's data. Everything runs on the
/// device: no account and no server. Changes are saved automatically.
class AppSession extends ChangeNotifier {
  AppSession() {
    _init();
  }

  static const _dataKey = 'samanvay_local_data_v1';
  static const _roleKey = 'samanvay_role';
  static const _deptKey = 'samanvay_department';

  final LocalRepository _local = LocalRepository();
  SharedPreferences? _prefs;
  Timer? _saveTimer;
  bool _roleChosen = false;

  /// Set to a work's id to show it on the Map tab (the shell switches tab,
  /// the map flies to it). Cleared once handled.
  final mapFocus = ValueNotifier<String?>(null);

  /// True until saved data and the remembered role are loaded.
  bool restoring = true;

  /// The data source, once the person has said who they are.
  SamanvayRepository? get repo => _roleChosen ? _local : null;

  /// Bumped after every change so screens reload their data.
  int revision = 0;
  void touch() {
    revision++;
    notifyListeners();
  }

  Future<void> _init() async {
    try {
      final prefs = _prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_dataKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) _local.loadJson(Map<String, dynamic>.from(decoded));
      }
      final role = AppRole.values.where((r) => r.name == prefs.getString(_roleKey)).firstOrNull;
      if (role != null) {
        _local.switchRole(role, departmentId: prefs.getString(_deptKey) ?? 'power');
        _roleChosen = true;
      }
    } catch (_) {
      // Unreadable saved data: start from the sample set.
    }
    _local.store.addListener(_changed);
    restoring = false;
    notifyListeners();
  }

  void _changed() {
    touch();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), save);
  }

  /// Writes the current data to the device.
  Future<void> save() async {
    _saveTimer?.cancel();
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    try {
      await prefs.setString(_dataKey, jsonEncode(_local.toJson()));
    } catch (_) {
      // Storage full or unavailable: the data stays in memory for this run.
    }
  }

  /// Sets who is using the app, and remembers it for next time.
  void chooseRole(AppRole role, {String? departmentId}) {
    final dept = departmentId ?? _local.user.departmentId ?? 'power';
    _local.switchRole(role, departmentId: dept);
    _roleChosen = true;
    _prefs?.setString(_roleKey, role.name);
    _prefs?.setString(_deptKey, dept);
    touch();
  }

  /// Puts the original sample works and reports back.
  Future<void> resetData() async {
    _local.resetData();
    await save();
    touch();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _local.store.removeListener(_changed);
    mapFocus.dispose();
    super.dispose();
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
