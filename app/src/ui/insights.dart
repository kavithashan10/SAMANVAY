import 'package:flutter/material.dart';

import '../../samanvay_design.dart';
import '../core/geo.dart';
import '../core/models.dart';
import 'common.dart';
import 'shell.dart';

/// "What the map holds": network inventory by layer, and how far the records
/// can be trusted. Bars grow in when the section first appears.
class NetworkDashboard extends StatelessWidget {
  const NetworkDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      sectionHeader(context, 'Network & data', 'What the map holds',
          lead: 'Lengths come from the campus records; confidence says how far each record can be trusted.'),
      const Gap(14),
      Loader<NetworkStats>(
        load: (r) => r.networkStats(),
        builder: (context, s) {
          final longest = s.layers.isEmpty ? 1.0 : s.layers.first.lengthM;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SvCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CountUp(s.totalM, suffix: ' m', style: SvType.heading1(p.ink).copyWith(fontSize: 40)),
                Text('of utility lines across ${s.layers.length} layers · ${s.structures} manholes, valves and chambers',
                    style: SvType.caption(p.muted)),
                const Gap(16),
                for (final (i, l) in s.layers.indexed) ...[
                  _Bar(label: l.label, value: formatDistance(l.lengthM), fraction: l.lengthM / longest, color: p.accent(l.color), delay: i * 70),
                  const Gap(10),
                ],
              ]),
            ),
            const Gap(12),
            SvCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Data confidence', style: SvType.title(p.ink).copyWith(fontSize: 17)),
                const Gap(4),
                Text('${s.records} records. Only verified records can support an excavation decision.', style: SvType.caption(p.muted)),
                const Gap(14),
                _StackedBar(parts: [for (final c in s.confidence) (c.count.toDouble(), p.accent(c.color))]),
                const Gap(14),
                for (final c in s.confidence)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(width: 10, height: 10, decoration: BoxDecoration(color: p.accent(c.color), borderRadius: BorderRadius.circular(3))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.label, style: SvType.bodySm(p.ink).copyWith(fontWeight: FontWeight.w600)),
                          Text(c.meaning, style: SvType.caption(p.muted)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      CountUp(c.count, style: SvType.ui(p.ink).copyWith(fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ]),
            ),
          ]);
        },
      ),
    ]);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.fraction, required this.color, this.delay = 0});
  final String label;
  final String value;
  final double fraction;
  final Color color;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final still = MediaQuery.of(context).disableAnimations;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: SvType.bodySm(p.ink))),
        Text(value, style: SvType.caption(p.inkSoft)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 8,
          color: p.surfaceAlt,
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: still ? fraction : 0, end: fraction),
            duration: Duration(milliseconds: 900 + delay),
            curve: Interval(delay / (900 + delay), 1, curve: Curves.easeOutCubic),
            builder: (context, f, _) => FractionallySizedBox(
              widthFactor: f.clamp(0.0, 1.0),
              child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _StackedBar extends StatelessWidget {
  const _StackedBar({required this.parts});
  final List<(double, Color)> parts;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final total = parts.fold(0.0, (a, x) => a + x.$1);
    final still = MediaQuery.of(context).disableAnimations;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 14,
        color: p.surfaceAlt,
        child: LayoutBuilder(
          builder: (context, box) => TweenAnimationBuilder<double>(
            tween: Tween(begin: still ? 1 : 0, end: 1),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => Row(children: [
              for (final (v, c) in parts)
                if (v > 0 && total > 0) Container(width: box.maxWidth * v / total * t, color: c),
            ]),
          ),
        ),
      ),
    );
  }
}
