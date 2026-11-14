import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../samanvay_design.dart';
import '../core/models.dart';
import 'common.dart';
import 'works.dart' show openCase;

/// Works on a shared calendar: one bar per work window, the months across the
/// top and a line for today. Works on the same road within 90 days of each
/// other are linked — candidates to dig once.
class WorksTimeline extends StatelessWidget {
  const WorksTimeline({super.key, required this.cases});
  final List<CaseSummary> cases;

  static String _road(CaseSummary c) => (c.road ?? '').split(' · ').first.trim().toLowerCase();

  /// Other works on the same road whose windows are within 90 days.
  static List<CaseSummary> partners(CaseSummary c, List<CaseSummary> all) {
    final road = _road(c);
    if (road.isEmpty || c.start == null) return const [];
    final aS = c.start!, aE = c.end ?? c.start!;
    int gap(CaseSummary o) {
      final bS = o.start!, bE = o.end ?? o.start!;
      return bS.isAfter(aE) ? bS.difference(aE).inDays : (aS.isAfter(bE) ? aS.difference(bE).inDays : 0);
    }

    return [
      for (final o in all)
        if (o.id != c.id && o.start != null && _road(o) == road && gap(o) <= 90) o,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final dated = cases.where((c) => c.start != null).toList()..sort((a, b) => a.start!.compareTo(b.start!));
    if (dated.isEmpty) {
      return const SvEmptyState(title: 'No dated works', message: 'Works with planned dates appear here on a shared calendar.', icon: Icons.event_busy);
    }
    final now = DateUtils.dateOnly(DateTime.now());
    var from = dated.first.start!, to = dated.first.end ?? dated.first.start!;
    for (final c in dated) {
      if (c.start!.isBefore(from)) from = c.start!;
      final e = c.end ?? c.start!;
      if (e.isAfter(to)) to = e;
    }
    if (now.isBefore(from)) from = now;
    if (now.isAfter(to)) to = now;
    from = DateTime(from.year, from.month);
    to = DateTime(to.year, to.month + 1);
    final days = math.max(1, to.difference(from).inDays);
    final still = MediaQuery.of(context).disableAnimations;

    return SvCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        double x(DateTime d) => w * (d.difference(from).inDays / days).clamp(0.0, 1.0);
        final months = <DateTime>[for (var m = from; m.isBefore(to); m = DateTime(m.year, m.month + 1)) m];
        const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Month ruler.
          SizedBox(
            height: 20,
            child: Stack(children: [
              for (final m in months)
                Positioned(
                  left: x(m),
                  top: 0,
                  child: Text(
                    m.month == 1 || m == months.first ? '${names[m.month - 1]} ${m.year % 100}' : names[m.month - 1],
                    style: SvType.caption(p.muted).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
            ]),
          ),
          Stack(children: [
            // Month gridlines and today.
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(xs: [for (final m in months) x(m)], today: x(now), color: p.hairline),
              ),
            ),
            Column(children: [
              for (final (i, c) in dated.indexed) _Row(c: c, x: x, partners: partners(c, dated), delay: i * 80, still: still),
            ]),
          ]),
          const Gap(6),
          Row(children: [
            Container(width: 10, height: 2, color: SvColors.primary),
            const SizedBox(width: 6),
            Text('Today', style: SvType.caption(p.muted)),
            const SizedBox(width: 14),
            Icon(Icons.link, size: 14, color: p.accent(SvColors.olive)),
            const SizedBox(width: 4),
            Expanded(child: Text('Same road within 90 days — dig once', style: SvType.caption(p.muted))),
          ]),
        ]);
      }),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.c, required this.x, required this.partners, required this.delay, required this.still});
  final CaseSummary c;
  final double Function(DateTime) x;
  final List<CaseSummary> partners;
  final int delay;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final left = x(c.start!), right = math.max(x(c.end ?? c.start!), left + 6);
    final color = p.accent(CaseStatus.color(c.status));
    return InkWell(
      onTap: () => openCase(context, c.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(c.number, style: SvType.caption(p.muted).copyWith(fontWeight: FontWeight.w700, letterSpacing: .4)),
            const SizedBox(width: 6),
            Expanded(child: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: SvType.bodySm(p.ink))),
            if (partners.isNotEmpty) ...[
              Icon(Icons.link, size: 14, color: p.accent(SvColors.olive)),
              const SizedBox(width: 2),
              Text(partners.map((o) => o.number.split('-').last).join(', '), style: SvType.caption(p.accent(SvColors.olive))),
            ],
          ]),
          const SizedBox(height: 6),
          SizedBox(
            height: 12,
            child: Stack(children: [
              Positioned(
                left: left,
                top: 0,
                bottom: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: still ? 1 : 0, end: 1),
                  duration: Duration(milliseconds: 700 + delay),
                  curve: Interval(delay / (700 + delay), 1, curve: Curves.easeOutCubic),
                  builder: (context, t, _) => Container(
                    width: (right - left) * t,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 3),
          Text('${fmtRange(c.start, c.end)} · ${CaseStatus.label(c.status)}', style: SvType.caption(p.muted)),
        ]),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.xs, required this.today, required this.color});
  final List<double> xs;
  final double today;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final x in xs) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    canvas.drawLine(Offset(today, 0), Offset(today, size.height), Paint()
      ..color = SvColors.primary
      ..strokeWidth = 1.6);
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.today != today || old.xs.length != xs.length || old.color != color;
}
