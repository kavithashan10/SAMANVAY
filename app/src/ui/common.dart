import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart' show samanvayThemeMode;
import '../../samanvay_design.dart';
import '../core/models.dart';
import '../core/repository.dart';
import 'session.dart';

String fmtDate(DateTime? d) {
  if (d == null) return 'Not set';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

String fmtRange(DateTime? a, DateTime? b) => a == null ? 'Dates not set' : '${fmtDate(a)} – ${fmtDate(b ?? a)}';

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.isNegative || d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 30) return '${d.inDays} d ago';
  return fmtDate(t);
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SvIconCircle(
      icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      tooltip: dark ? 'Light theme' : 'Dark theme',
      onPressed: () async {
        samanvayThemeMode.value = dark ? ThemeMode.light : ThemeMode.dark;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('samanvay_light_mode', dark);
        } catch (_) {}
      },
    );
  }
}

/// Loads [load] and reloads whenever the session revision changes, with
/// consistent loading, error and empty states.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder, this.isEmpty, this.empty});
  final Future<T> Function(SamanvayRepository repo) load;
  final Widget Function(BuildContext context, T data) builder;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  Future<T>? _future;
  int _rev = -1;
  Object? _repoIdentity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.session;
    if (s.revision != _rev || !identical(s.repo, _repoIdentity)) {
      _rev = s.revision;
      _repoIdentity = s.repo;
      _future = widget.load(s.repo!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        // Keep showing the previous data while a refresh is in flight, so a
        // background change (a ticked box, a new status) never blanks the page
        // or loses the scroll position.
        final loading = snap.connectionState != ConnectionState.done;
        if (loading && !snap.hasData) {
          return const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (!loading && snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SvCard(
              color: p.surfaceAlt,
              child: Row(children: [
                Icon(Icons.cloud_off_outlined, color: p.muted),
                const SizedBox(width: 12),
                Expanded(child: Text(friendlyError(snap.error!), style: SvType.bodySm(p.inkSoft))),
                TextButton(onPressed: () => setState(() => _future = widget.load(context.repo)), child: const Text('Retry')),
              ]),
            ),
          );
        }
        final data = snap.data as T;
        if (widget.isEmpty?.call(data) == true && widget.empty != null) return widget.empty!;
        return widget.builder(context, data);
      },
    );
  }
}

class StatusTag extends StatelessWidget {
  const StatusTag(this.status, {super.key, this.solid = false});
  final String status;
  final bool solid;
  @override
  Widget build(BuildContext context) => SvTag(CaseStatus.label(status), color: CaseStatus.color(status), solid: solid);
}

class CaseCard extends StatelessWidget {
  const CaseCard({super.key, required this.c, required this.onTap, this.trailing, this.extra});
  final CaseSummary c;
  final VoidCallback onTap;
  final Widget? trailing;
  final List<Widget>? extra;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return SvCard(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle, color: p.surfaceAlt),
          child: Icon(categoryIcon(c.category), color: p.inkSoft, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.number, style: SvType.eyebrow(p.muted)),
            const SizedBox(height: 4),
            Text(c.title, style: SvType.title(p.ink).copyWith(fontSize: 17)),
            if (c.place.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(c.place, maxLines: 1, overflow: TextOverflow.ellipsis, style: SvType.bodySm(p.inkSoft)),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              StatusTag(c.status),
              SvTag(fmtRange(c.start, c.end), color: SvColors.stone),
              ...?extra,
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        trailing ?? Icon(Icons.arrow_forward, color: p.muted, size: 20),
      ]),
    );
  }
}

/// Standard scrolling page body with generous editorial spacing.
class PageList extends StatelessWidget {
  const PageList({super.key, required this.children, this.onRefresh});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final list = ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 48), children: children);
    return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class Gap extends StatelessWidget {
  const Gap(this.h, {super.key});
  final double h;
  @override
  Widget build(BuildContext context) => SizedBox(height: h);
}

/// A number that counts up when it first appears or changes.
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, required this.style, this.duration = const Duration(milliseconds: 1200), this.suffix = ''});
  final num value;
  final TextStyle style;
  final Duration duration;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return Text('${value.round()}$suffix', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}
