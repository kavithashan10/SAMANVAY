import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'atlas/india_map.dart' show AtlasColors;
import 'brand.dart';

/// Opening sequence: a field of map dots wakes up, an orbit arc sweeps round,
/// the SAMANVAY mark springs in and catches the light, its pin sends out a
/// ripple, then the name spells itself out. About 2.8 s; still under
/// "reduce motion".
class SamanvaySplash extends StatefulWidget {
  const SamanvaySplash({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<SamanvaySplash> createState() => _SamanvaySplashState();
}

class _SamanvaySplashState extends State<SamanvaySplash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2900));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    precacheImage(const AssetImage(kBrandLogoAsset), context);
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
      Future.delayed(const Duration(milliseconds: 700), _done);
    } else {
      _c.forward().whenComplete(_done);
    }
  }

  void _done() {
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0→1 over [a, b] seconds of the timeline, eased.
  double _seg(double a, double b, [Curve curve = Curves.easeOutCubic]) {
    final s = _c.value * 2.9;
    return curve.transform(((s - a) / (b - a)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logo = math.min(size.width * .46, 210.0);
    return Scaffold(
      backgroundColor: AtlasColors.deep,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final dots = _seg(0, 1.2);
          final arc = _seg(.2, 1.15, Curves.easeInOutCubic);
          final pop = _seg(.3, 1.05, Curves.easeOutBack);
          final fade = _seg(.3, .7);
          final shine = _seg(1.1, 1.7, Curves.easeInOutSine);
          final ripple = _seg(1.15, 2.4, Curves.linear);
          final tag = _seg(1.85, 2.35);
          final bar = _seg(0, 2.75, Curves.easeInOut);
          final exit = _seg(2.6, 2.9, Curves.easeInCubic);
          return Opacity(
            opacity: 1 - exit,
            child: Transform.scale(
              scale: 1 + exit * .06,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(center: Alignment(0, -.15), radius: 1.0, colors: [AtlasColors.night, AtlasColors.deep]),
                ),
                child: Stack(children: [
                  Positioned.fill(child: CustomPaint(painter: _DotField(dots, _c.value * 2.9))),
                  Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: logo * 1.5,
                        height: logo * 1.5,
                        child: Stack(alignment: Alignment.center, children: [
                          CustomPaint(size: Size.square(logo * 1.5), painter: _Orbit(arc, _c.value * 2.9)),
                          Opacity(
                            opacity: fade,
                            child: Transform.scale(
                              scale: .35 + .65 * pop,
                              child: _Shine(
                                t: shine,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(logo * .22),
                                    boxShadow: [BoxShadow(color: AtlasColors.dot.withValues(alpha: .45 * fade), blurRadius: 40, spreadRadius: 2)],
                                  ),
                                  child: BrandMark(size: logo),
                                ),
                              ),
                            ),
                          ),
                          // The pin's ripple, at the tip of the logo's pin.
                          Positioned(
                            left: logo * .25 + logo * .54 - 40,
                            top: logo * .25 + logo * .22 - 40,
                            child: CustomPaint(size: const Size.square(80), painter: _Ripple(ripple)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      _Wordmark(t: _c.value * 2.9),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: tag,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - tag)),
                          child: Text(
                            'Map once · Dig once · Work together',
                            style: TextStyle(color: AtlasColors.label.withValues(alpha: .75), fontSize: 13.5, letterSpacing: .6),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  Positioned(
                    left: size.width * .3,
                    right: size.width * .3,
                    bottom: 56 + MediaQuery.paddingOf(context).bottom,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: bar,
                        minHeight: 2.5,
                        backgroundColor: Colors.white.withValues(alpha: .08),
                        valueColor: const AlwaysStoppedAnimation(AtlasColors.glow),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.t});
  final double t;
  @override
  Widget build(BuildContext context) {
    const word = 'SAMANVAY';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < word.length; i++)
        () {
          final k = Curves.easeOutCubic.transform(((t - 1.25 - i * .07) / .45).clamp(0.0, 1.0));
          return Opacity(
            opacity: k,
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - k)),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 2 + 3 * (1 - k)),
                child: Text(
                  word[i],
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 2),
                ),
              ),
            ),
          );
        }(),
    ]);
  }
}

/// A diagonal glint passing across the mark.
class _Shine extends StatelessWidget {
  const _Shine({required this.t, required this.child});
  final double t;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (t <= 0 || t >= 1) return child;
    return Stack(children: [
      child,
      Positioned.fill(
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(1000),
            child: ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (r) => LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: .55), Colors.white.withValues(alpha: 0)],
                stops: [(t * 1.6 - .5).clamp(0.0, 1.0), (t * 1.6 - .3).clamp(0.0, 1.0), (t * 1.6 - .1).clamp(0.0, 1.0)],
              ).createShader(r),
              child: child,
            ),
          ),
        ),
      ),
    ]);
  }
}

class _DotField extends CustomPainter {
  _DotField(this.reveal, this.t);
  final double reveal, t;
  @override
  void paint(Canvas canvas, Size size) {
    if (reveal <= 0) return;
    final c = Offset(size.width / 2, size.height * .45);
    final maxR = size.longestSide * .75;
    const sp = 22.0;
    final paint = Paint();
    for (var y = sp / 2; y < size.height; y += sp * .866) {
      final odd = ((y / (sp * .866)).floor()).isOdd;
      for (var x = odd ? sp / 2 : 0.0; x < size.width; x += sp) {
        final d = (Offset(x, y) - c).distance;
        final front = reveal * maxR - d;
        if (front < 0) continue;
        final wave = math.exp(-math.pow(front - 40, 2) / 1800);
        final fall = (1 - d / maxR).clamp(0.0, 1.0);
        final twinkle = .5 + .5 * math.sin(t * 2.2 + x * .05 + y * .07);
        paint.color = AtlasColors.dot.withValues(alpha: (.07 + .1 * twinkle) * fall + .5 * wave);
        canvas.drawCircle(Offset(x, y), 1.4 + 1.2 * wave, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotField old) => old.reveal != reveal || old.t != t;
}

class _Orbit extends CustomPainter {
  _Orbit(this.k, this.t);
  final double k, t;
  @override
  void paint(Canvas canvas, Size size) {
    if (k <= 0) return;
    final rect = Offset.zero & size;
    final r = rect.deflate(6);
    final start = -math.pi / 2 + t * .5;
    final sweep = 2 * math.pi * .82 * k;
    final shader = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      transform: GradientRotation(start),
      colors: const [Color(0x003DB8FF), AtlasColors.glow, AtlasColors.dot, Color(0x003D7BFF)],
      stops: const [0, .35, .75, 1],
    ).createShader(rect);
    canvas.drawArc(
      r,
      start,
      sweep,
      false,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    // Satellite dot riding the arc's head.
    final head = start + sweep;
    final p = r.center + Offset(math.cos(head), math.sin(head)) * r.width / 2;
    canvas.drawCircle(p, 4.5, Paint()..color = Colors.white);
    canvas.drawCircle(p, 10, Paint()..color = AtlasColors.glow.withValues(alpha: .25));
  }

  @override
  bool shouldRepaint(covariant _Orbit old) => old.k != k || old.t != t;
}

class _Ripple extends CustomPainter {
  _Ripple(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    for (var i = 0; i < 2; i++) {
      final f = ((t - i * .3) / .7).clamp(0.0, 1.0);
      if (f <= 0 || f >= 1) continue;
      canvas.drawCircle(
        c,
        6 + 32 * Curves.easeOut.transform(f),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AtlasColors.pin.withValues(alpha: (1 - f) * .9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Ripple old) => old.t != t;
}
