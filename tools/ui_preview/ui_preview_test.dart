// Screenshots of the main screens on a phone-sized surface, plus every
// framework error (overflow, exception) seen while navigating. CI only.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:samanvay/main.dart' show samanvayThemeMode;
import 'package:samanvay/busstand_demo_app.dart';
import 'package:samanvay/src/core/models.dart';
import 'package:samanvay/src/ui/app.dart';
import 'package:samanvay/src/ui/session.dart';
import 'package:samanvay/src/ui/welcome.dart';

final _key = GlobalKey();
final _errors = <String>[];
var _shot = 0;

Future<void> _font(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final bytes = f.readAsBytesSync();
  await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
}

Future<void> _settle(WidgetTester t, {int ms = 1600}) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _snap(WidgetTester t, String name) async {
  await _settle(t);
  await t.runAsync(() async {
    try {
      await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 8));
    } catch (_) {}
  });
  await t.pump(const Duration(milliseconds: 50));
  final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  print('snap $name');
  await t.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 1.6);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    _shot++;
    final file = File('preview/${_shot.toString().padLeft(2, '0')}_$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  });
  _errors.add('--- after screenshot $name ---');
  File('preview/errors.txt').writeAsStringSync(_errors.join('\n\n'));
}

Future<bool> _tapText(WidgetTester t, String text, {bool last = false}) async {
  final f = find.text(text);
  if (f.evaluate().isEmpty) {
    _errors.add('NOT FOUND: "$text"');
    return false;
  }
  await t.tap(last ? f.last : f.first, warnIfMissed: false);
  await _settle(t, ms: 900);
  return true;
}

Future<void> _tab(WidgetTester t, String label) async {
  final f = find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
  if (f.evaluate().isEmpty) {
    _errors.add('NO TAB: $label');
    return;
  }
  await t.tap(f.first);
  await _settle(t, ms: 900);
}

Future<void> _scrollDown(WidgetTester t) async {
  final s = find.byType(Scrollable);
  if (s.evaluate().isEmpty) return;
  await t.drag(s.first, const Offset(0, -700), warnIfMissed: false);
  await _settle(t, ms: 700);
}

void main() {
  setUpAll(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('gf').path,
    );
    final root = Platform.environment['FLUTTER_ROOT'] ?? '';
    await _font('MaterialIcons', '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    await _font('Roboto', '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
  });

  Future<void> run(WidgetTester t, Future<void> Function() body) async {
    await t.runAsync(() async {
      const weights = [FontWeight.w300, FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800];
      for (final w in weights) {
        for (final st in [FontStyle.normal, FontStyle.italic]) {
          GoogleFonts.inter(fontWeight: w, fontStyle: st);
          GoogleFonts.fraunces(fontWeight: w, fontStyle: st);
          GoogleFonts.spaceGrotesk(fontWeight: w);
          GoogleFonts.robotoMono(fontWeight: w);
        }
      }
      try {
        await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 60));
      } catch (e) {
        print('font prefetch: $e');
      }
    });
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.625;
    final previous = FlutterError.onError;
    FlutterError.onError = (d) {
      final text = d.toString().split('\n').where((l) => l.trim().isNotEmpty).take(14).join('\n');
      if (!text.contains('google_fonts') && !text.contains('GoogleFonts')) _errors.add(text);
    };
    try {
      await body();
    } catch (e, s) {
      _errors.add('THROWN: $e\n${s.toString().split('\n').take(8).join('\n')}');
    } finally {
      FlutterError.onError = previous;
      File('preview/errors.txt')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(_errors.join('\n\n'));
      t.view.reset();
    }
  }

  testWidgets('main app screens', timeout: const Timeout(Duration(minutes: 5)), (t) async {
    await run(t, () async {
      await t.pumpWidget(RepaintBoundary(key: _key, child: const SamanvayV2App()));
      await _settle(t, ms: 7000);
      await _snap(t, 'welcome');
      await _scrollDown(t);
      await _snap(t, 'welcome_scrolled');
      final ctx = t.element(find.byType(WelcomeScreen));
      ctx.session.chooseRole(AppRole.coordinator);
      await _settle(t, ms: 2000);
      await _snap(t, 'home_coordinator');
      await _scrollDown(t);
      await _snap(t, 'home_scrolled');
      await _tab(t, 'Map');
      await _settle(t, ms: 3000);
      await _snap(t, 'map_india');
      await t.tap(find.byIcon(Icons.directions_bus_outlined).first, warnIfMissed: false);
      await _settle(t, ms: 3000);
      await _snap(t, 'map_busstand');
      await t.tapAt(const Offset(206, 400));
      await _settle(t, ms: 1500);
      await _snap(t, 'map_busstand_tap');
      await _tab(t, 'Works');
      await _snap(t, 'works');
      if (await _tapText(t, 'Optical fibre laying')) {
        await _snap(t, 'work_detail');
        await _scrollDown(t);
        await _snap(t, 'work_detail_scrolled');
        final nav = t.state<NavigatorState>(find.byType(Navigator).last);
        nav.maybePop();
        await _settle(t, ms: 900);
      }
      await _tab(t, 'Reports');
      await _snap(t, 'reports');
      await _tab(t, 'Inbox');
      await _snap(t, 'inbox');
      samanvayThemeMode.value = ThemeMode.dark;
      await _settle(t, ms: 1200);
      await _tab(t, 'Map');
      await _settle(t, ms: 2000);
      await _snap(t, 'map_busstand_dark');
      await _tab(t, 'Home');
      await _snap(t, 'home_dark');
      samanvayThemeMode.value = ThemeMode.light;
      ctx.session.chooseRole(AppRole.citizen);
      await _settle(t, ms: 1500);
      await _tab(t, 'Home');
      await _snap(t, 'home_citizen');
    });
  });

  testWidgets('bus stand demo app', timeout: const Timeout(Duration(minutes: 3)), (t) async {
    await run(t, () async {
      await t.pumpWidget(RepaintBoundary(key: _key, child: const BusStandDemoApp()));
      await _settle(t, ms: 2000);
      await _snap(t, 'demo_welcome');
      await _scrollDown(t);
      await _snap(t, 'demo_welcome_scrolled');
      await _tapText(t, 'Enter the demo');
      await _settle(t, ms: 2000);
      await _snap(t, 'demo_home');
      final dests = find.byType(NavigationDestination);
      final n = dests.evaluate().length;
      for (var i = 1; i < n; i++) {
        await t.tap(find.byType(NavigationDestination).at(i), warnIfMissed: false);
        await _settle(t, ms: 1500);
        await _snap(t, 'demo_tab_$i');
      }
    });
  });
}
