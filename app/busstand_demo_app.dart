import 'package:flutter/material.dart';

import 'busstand_demo_data.dart';
import 'busstand_demo_map.dart';
import 'samanvay_design.dart';
import 'src/ui/map/underground_3d.dart';

// =============================================================================
// SAMANVAY · Manaparai Bus Stand demonstration
//
// A self-contained, offline walkthrough of the four roles. The role switch is
// a presentation aid only — it is not authentication, and every record is a
// synthetic demonstration record.
// =============================================================================

/// Standalone app (used with --dart-define=SAMANVAY_START=busstand-demo).
class BusStandDemoApp extends StatelessWidget {
  const BusStandDemoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SAMANVAY · Manaparai demo',
        debugShowCheckedModeBanner: false,
        theme: samanvayFieldTheme(dark: false),
        home: const BusStandDemoRoot(),
      );
}

/// Opens the demo on top of the main application. With [map] it opens
/// straight at Manaparai Bus Stand utility schematic.
Future<void> openBusStandDemo(BuildContext context, {bool map = false}) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BusStandDemoRoot(onExit: () => Navigator.of(context).pop(), startOnMap: map)),
    );

/// Owns the demo store, theme and a nested navigator so every demo screen
/// shares the field-journal theme regardless of the host app's theme.
class BusStandDemoRoot extends StatefulWidget {
  const BusStandDemoRoot({super.key, this.onExit, this.startOnMap = false});
  final VoidCallback? onExit;

  /// Skip the welcome screen and open the shell on its Map tab.
  final bool startOnMap;
  @override
  State<BusStandDemoRoot> createState() => _BusStandDemoRootState();
}

class _BusStandDemoRootState extends State<BusStandDemoRoot> {
  final store = BusStandDemoStore();
  final _navKey = GlobalKey<NavigatorState>();

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BusStandDemoScope(
      store: store,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => Theme(
          data: samanvayFieldTheme(dark: store.dark),
          child: ScaffoldMessenger(
            child: NavigatorPopHandler(
              onPopWithResult: (_) => _navKey.currentState?.maybePop(),
              child: Navigator(
                key: _navKey,
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => widget.startOnMap
                      ? const BusStandDemoShell(initialTab: 1)
                      : BusStandDemoWelcome(onExit: widget.onExit),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _date(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

class _SamanvayMark extends StatelessWidget {
  const _SamanvayMark({this.size = 34});
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/brand/samanvay_logo.png',
        width: size,
        height: size,
        semanticLabel: 'SAMANVAY logo',
      );
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();
  @override
  Widget build(BuildContext context) {
    final store = BusStandDemoScope.of(context);
    return SvIconCircle(
      icon: store.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      tooltip: store.dark ? 'Switch to light theme' : 'Switch to dark theme',
      onPressed: store.toggleDark,
    );
  }
}

// =============================================================================
// Welcome
// =============================================================================

class BusStandDemoWelcome extends StatelessWidget {
  const BusStandDemoWelcome({super.key, this.onExit});
  final VoidCallback? onExit;

  void _enter(BuildContext context, DemoRole role) {
    BusStandDemoScope.of(context).setRole(role);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BusStandDemoShell()));
  }

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            Row(children: [
              const Expanded(child: SvEyebrow('Manaparai Bus Stand · live demonstration')),
              const _ThemeToggle(),
            ]),
            const SizedBox(height: 32),
            const Align(alignment: Alignment.centerLeft, child: _SamanvayMark(size: 112)),
            const SizedBox(height: 28),
            Text('Know below.\nDig above.', style: SvType.display(p.ink)),
            const SizedBox(height: 18),
            Text(
              'One shared map and one workflow for every department that digs the same road — '
              'before, during and after the work.',
              style: SvType.lead(p.inkSoft),
            ),
            const SizedBox(height: 32),
            SvPillButton(
              label: 'Enter the demo',
              kind: SvButtonKind.primary,
              expand: true,
              onPressed: () => _enter(context, store.role),
            ),
            if (onExit != null) ...[
              const SizedBox(height: 12),
              SvPillButton(label: 'Back to SAMANVAY', kind: SvButtonKind.outline, expand: true, onPressed: onExit),
            ],
            const SizedBox(height: 48),
            const SvEyebrow('Step in as'),
            const SizedBox(height: 8),
            Text('Four people, one street', style: SvType.heading2(p.ink)),
            const SizedBox(height: 16),
            for (final role in DemoRole.values) ...[
              SvCard(
                onTap: () => _enter(context, role),
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: p.surfaceAlt),
                    child: Icon(role.icon, color: p.inkSoft, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(role.label, style: SvType.title(p.ink).copyWith(fontSize: 17)),
                      const SizedBox(height: 3),
                      Text(role.blurb, style: SvType.bodySm(p.inkSoft)),
                    ]),
                  ),
                  Icon(Icons.arrow_forward, color: p.muted, size: 20),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 36),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: SvColors.inkBandSoft, borderRadius: BorderRadius.circular(SvRadius.lg)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SvEyebrow('About this demonstration', color: SvColors.mute),
                const SizedBox(height: 10),
                Text('Everything here is synthetic.', style: SvType.heading2(SvColors.canvas)),
                const SizedBox(height: 10),
                Text(
                  'The bus stand layout is an illustrative schematic and every utility record, department reply and person is '
                  'demonstration data. Nothing on these screens may be used for excavation or construction decisions.',
                  style: SvType.bodySm(SvColors.mute),
                ),
                const SizedBox(height: 22),
                Wrap(spacing: 18, runSpacing: 18, children: [
                  _InkStat('${store.assets.length}', 'demo records'),
                  const _InkStat('7', 'utility layers'),
                  _InkStat('${demoDepartments.length}', 'departments'),
                  _InkStat('${store.works.length}', 'work items'),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _InkStat extends StatelessWidget {
  const _InkStat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 120,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: SvType.heading3(SvColors.canvas)),
          Text(label, style: SvType.caption(SvColors.mute)),
        ]),
      );
}

// =============================================================================
// Shell
// =============================================================================

class BusStandDemoShell extends StatefulWidget {
  const BusStandDemoShell({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<BusStandDemoShell> createState() => _BusStandDemoShellState();
}

class _BusStandDemoShellState extends State<BusStandDemoShell> {
  late int _tab = widget.initialTab;

  void goTo(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    final pages = [
      _HomeTab(onOpenMap: () => goTo(1), onOpenReports: () => goTo(3)),
      const BusStandDemoMapTab(),
      const _WorksTab(),
      const _ReportsTab(),
      const _ActivityTab(),
    ];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        toolbarHeight: 64,
        title: Row(children: [
          const _SamanvayMark(size: 32),
          const SizedBox(width: 12),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('SAMANVAY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SvType.ui(p.inkSoft).copyWith(fontWeight: FontWeight.w700, letterSpacing: 2.4)),
              Text('Manaparai Bus Stand · demo', maxLines: 1, overflow: TextOverflow.ellipsis, style: SvType.caption(p.muted)),
            ]),
          ),
        ]),
        actions: [
          const _ThemeToggle(),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SvPillButton(
              label: store.role.short,
              icon: Icons.swap_horiz,
              compact: true,
              onPressed: () => _showRoleSwitcher(context),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Container(
            height: 30,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: SvColors.goldPale.withValues(alpha: p.isDark ? .18 : .45),
            alignment: Alignment.centerLeft,
            child: Text(
              'DEMO MODE · ${store.role.label.toUpperCase()}'
              '${store.role == DemoRole.officer ? ' · ${deptById(store.officerDept).name.toUpperCase()}' : ''} · SYNTHETIC DATA',
              overflow: TextOverflow.ellipsis,
              style: SvType.eyebrow(p.isDark ? SvColors.goldPale : SvColors.goldDeep).copyWith(fontSize: 10),
            ),
          ),
        ),
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: goTo,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.layers_outlined), selectedIcon: Icon(Icons.layers), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.construction_outlined), selectedIcon: Icon(Icons.construction), label: 'Works'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history), label: 'Activity'),
        ],
      ),
    );
  }
}

void _showRoleSwitcher(BuildContext context) {
  final store = BusStandDemoScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => ListenableBuilder(
      listenable: store,
      builder: (sheet, _) {
        final p = SvPalette.of(sheet);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SvEyebrow('Demo profile switch'),
              const SizedBox(height: 6),
              Text('Who is looking?', style: SvType.heading2(p.ink)),
              const SizedBox(height: 6),
              Text('A presentation aid for this demonstration — not a sign-in, and it grants no real access.',
                  style: SvType.bodySm(p.inkSoft)),
              const SizedBox(height: 18),
              for (final role in DemoRole.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SvCard(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    borderColor: store.role == role ? (p.isDark ? p.inkSoft : SvColors.silver) : null,
                    onTap: () {
                      store.setRole(role);
                      if (role != DemoRole.officer) Navigator.of(sheet).pop();
                    },
                    child: Row(children: [
                      Icon(role.icon, color: p.inkSoft),
                      const SizedBox(width: 14),
                      Expanded(child: Text(role.label, style: SvType.body(p.ink).copyWith(fontWeight: FontWeight.w600))),
                      if (store.role == role) const Icon(Icons.check, color: SvColors.forest, size: 20),
                    ]),
                  ),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(sheet).pop();
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  icon: Icon(Icons.logout, size: 18, color: p.inkSoft),
                  label: Text('Exit to the welcome screen', style: SvType.ui(p.inkSoft)),
                ),
              ),
              if (store.role == DemoRole.officer) ...[
                const SizedBox(height: 8),
                const SvEyebrow('Officer of'),
                const SizedBox(height: 8),
                SvPillTabs<String>(
                  options: [for (final d in demoDepartments) (d.id, d.short)],
                  selected: store.officerDept,
                  onChanged: store.setOfficerDept,
                ),
                const SizedBox(height: 16),
                SvPillButton(label: 'Done', expand: true, onPressed: () => Navigator.of(sheet).pop()),
              ],
            ]),
          ),
        );
      },
    ),
  );
}

// =============================================================================
// Home (role-specific)
// =============================================================================

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.onOpenMap, required this.onOpenReports});
  final VoidCallback onOpenMap;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final store = BusStandDemoScope.of(context);
    return switch (store.role) {
      DemoRole.citizen => _CitizenHome(onOpenMap: onOpenMap, onOpenReports: onOpenReports),
      DemoRole.officer => const _OfficerHome(),
      DemoRole.coordinator => const _CoordinatorHome(),
      DemoRole.admin => const _AdminHome(),
    };
  }
}

String _greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning.' : (h < 17 ? 'Good afternoon.' : 'Good evening.');
}

class _Page extends StatelessWidget {
  const _Page({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: children,
      );
}

class _CitizenHome extends StatelessWidget {
  const _CitizenHome({required this.onOpenMap, required this.onOpenReports});
  final VoidCallback onOpenMap;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    final active = store.works.where((w) => w.isPublicActive && w.status != WorkStatus.completed).toList();
    final restoring = store.works.where((w) => w.status == WorkStatus.restorationPending).length;
    final open = store.grievances.where((g) => g.status.index < GrievanceStatus.resolved.index).length;
    final mine = store.grievances.where((g) => g.mine).toList();
    return _Page(children: [
      Text(_greeting(), style: SvType.heading1(p.ink)),
      const SizedBox(height: 8),
      Text("Here is what is happening beneath Manaparai's roads this week.", style: SvType.lead(p.inkSoft)),
      const SizedBox(height: 24),
      SvBand(
        color: SvColors.clay,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _BandStat('${active.length}', 'works planned\nor active'),
          _BandStat('$restoring', 'road awaiting\nrestoration'),
          _BandStat('$open', 'open citizen\nreports'),
        ]),
      ),
      const SizedBox(height: 20),
      SvPillButton(
        label: 'Report a problem',
        icon: Icons.add,
        kind: SvButtonKind.primary,
        expand: true,
        onPressed: () => _openGrievanceForm(context),
      ),
      const SizedBox(height: 12),
      SvPillButton(label: 'Explore the underground map', icon: Icons.layers_outlined, expand: true, onPressed: onOpenMap),
      const SizedBox(height: 40),
      const SvSectionHeader(eyebrow: 'Public works', title: 'On bus stand roads now'),
      const SizedBox(height: 16),
      for (final w in active) ...[_WorkCard(work: w), const SizedBox(height: 12)],
      const SizedBox(height: 28),
      SvSectionHeader(
        eyebrow: 'Your reports',
        title: 'Tracking',
        trailing: TextButton(onPressed: onOpenReports, child: Text('See all', style: SvType.ui(p.inkSoft))),
      ),
      const SizedBox(height: 16),
      if (mine.isEmpty)
        const SvEmptyState(title: 'No reports yet', message: 'Anything you report will be tracked here.')
      else
        for (final g in mine) ...[_GrievanceCard(g: g), const SizedBox(height: 12)],
    ]);
  }
}

class _BandStat extends StatelessWidget {
  const _BandStat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: SvType.heading1(SvColors.canvas).copyWith(fontSize: 40)),
        const SizedBox(height: 2),
        Text(label, style: SvType.caption(SvColors.canvas.withValues(alpha: .8))),
      ]);
}

class _OfficerHome extends StatelessWidget {
  const _OfficerHome();
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    final dept = deptById(store.officerDept);
    final queue = store.works.where((w) => w.reviews.any((r) => r.deptId == dept.id) && w.status != WorkStatus.completed).toList()
      ..sort((a, b) {
        int rank(WorkItem w) => w.reviews.firstWhere((r) => r.deptId == dept.id).status.isCleared ? 1 : 0;
        return rank(a).compareTo(rank(b));
      });
    final reports = store.grievances.where((g) => g.routedTo == dept.id).toList();
    final waiting = queue.where((w) => !w.reviews.firstWhere((r) => r.deptId == dept.id).status.isCleared).length;
    return _Page(children: [
      const SvEyebrow('Department officer · demo'),
      const SizedBox(height: 12),
      SvPillTabs<String>(
        options: [for (final d in demoDepartments) (d.id, d.short)],
        selected: dept.id,
        onChanged: store.setOfficerDept,
      ),
      const SizedBox(height: 24),
      Text('${dept.name}\nreview queue', style: SvType.heading1(p.ink)),
      const SizedBox(height: 8),
      Text(
        waiting == 0 ? 'Nothing is waiting on your department.' : '$waiting work item${waiting == 1 ? '' : 's'} need your department checklist.',
        style: SvType.lead(p.inkSoft),
      ),
      const SizedBox(height: 24),
      for (final w in queue) ...[
        _WorkCard(work: w, focusDept: dept.id),
        const SizedBox(height: 12),
      ],
      if (queue.isEmpty) const SvEmptyState(title: 'Queue is clear', message: 'No open work touches this department.'),
      const SizedBox(height: 28),
      const SvSectionHeader(eyebrow: 'Citizen reports', title: 'Routed to you'),
      const SizedBox(height: 16),
      if (reports.isEmpty)
        const SvEmptyState(title: 'No reports', message: 'Citizen reports routed to this department appear here.')
      else
        for (final g in reports) ...[_GrievanceCard(g: g), const SizedBox(height: 12)],
    ]);
  }
}

class _CoordinatorHome extends StatelessWidget {
  const _CoordinatorHome();
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    final open = store.works.where((w) => w.status != WorkStatus.completed && w.isPublicActive).toList();
    final pendingReviews = open.expand((w) => w.reviews).where((r) => !r.status.isCleared).length;
    final screenings = {for (final w in open) w.id: store.screen(w)};
    final overlapCount = screenings.values.where((s) => s.overlaps.isNotEmpty).length;
    final pairs = <(WorkItem, WorkItem)>[];
    for (final w in open) {
      for (final o in screenings[w.id]!.digOnce) {
        if (!pairs.any((x) => x.$1.id == o.id && x.$2.id == w.id)) pairs.add((w, o));
      }
    }
    final actionable = open.where((w) => store.nextAction(w) != null).toList();
    return _Page(children: [
      const SvEyebrow('Coordinator · demo'),
      const SizedBox(height: 10),
      Text('Bus stand\ncoordination', style: SvType.heading1(p.ink)),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        SvStatBadge(value: '$pendingReviews', label: 'department reviews open', size: 84),
        SvStatBadge(value: '$overlapCount', label: 'works with mapped overlaps', size: 84, accent: SvColors.clay),
        SvStatBadge(value: '${pairs.length}', label: 'dig-once opportunity', size: 84, accent: SvColors.olive),
      ]),
      const SizedBox(height: 36),
      const SvSectionHeader(
        eyebrow: 'Department checklists',
        title: 'Who has cleared what',
        lead: 'Each cell is a department checklist. Tap a row to open the work item.',
      ),
      const SizedBox(height: 16),
      _ChecklistMatrix(works: open),
      if (pairs.isNotEmpty) ...[
        const SizedBox(height: 36),
        const SvSectionHeader(eyebrow: 'Dig once', title: 'Same road, twice in 90 days'),
        const SizedBox(height: 16),
        for (final (a, b) in pairs) ...[
          _DigOnceCard(a: a, b: b),
          const SizedBox(height: 12),
        ],
      ],
      const SizedBox(height: 36),
      const SvSectionHeader(eyebrow: 'Needs your action', title: 'Ready to move'),
      const SizedBox(height: 16),
      if (actionable.isEmpty)
        const SvEmptyState(title: 'Nothing waiting', message: 'Work items that need a coordinator decision appear here.')
      else
        for (final w in actionable) ...[_WorkCard(work: w), const SizedBox(height: 12)],
    ]);
  }
}

/// Departments × work items grid of checklist progress.
class _ChecklistMatrix extends StatelessWidget {
  const _ChecklistMatrix({required this.works});
  final List<WorkItem> works;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return SvCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(width: 78, child: Text('WORK', style: SvType.eyebrow(p.muted))),
            for (final d in demoDepartments)
              SizedBox(
                width: 44,
                child: Tooltip(
                  message: d.name,
                  child: Column(children: [
                    Icon(d.icon, size: 18, color: d.color),
                    const SizedBox(height: 2),
                    Text(d.short.length > 5 ? d.short.substring(0, 4) : d.short, style: SvType.caption(p.muted).copyWith(fontSize: 10)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          for (final w in works)
            InkWell(
              onTap: () => _openWork(context, w),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hairline))),
                child: Row(children: [
                  SizedBox(
                    width: 78,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(w.id.replaceFirst('SR-2026-', 'SR-'), style: SvType.ui(p.ink).copyWith(fontWeight: FontWeight.w700)),
                      Text(w.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: SvType.caption(p.muted).copyWith(fontSize: 11)),
                    ]),
                  ),
                  for (final d in demoDepartments)
                    SizedBox(
                      width: 44,
                      child: Center(child: _MatrixCell(review: w.reviews.where((r) => r.deptId == d.id).firstOrNull)),
                    ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _MatrixCell extends StatelessWidget {
  const _MatrixCell({required this.review});
  final DepartmentReview? review;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final r = review;
    if (r == null) return Text('—', style: SvType.caption(p.hairline));
    if (r.status == ReviewStatus.objection || r.status == ReviewStatus.clarification) {
      return Icon(Icons.error_outline, color: p.accent(r.status.color), size: 22);
    }
    if (r.status.isCleared) {
      return Icon(r.status == ReviewStatus.cleared ? Icons.check_circle : Icons.check_circle_outline, color: p.accent(SvColors.forest), size: 22);
    }
    return SvProgressRing(done: r.done, total: r.total, size: 30);
  }
}

class _DigOnceCard extends StatelessWidget {
  const _DigOnceCard({required this.a, required this.b});
  final WorkItem a;
  final WorkItem b;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    final gap = b.start.isAfter(a.end) ? b.start.difference(a.end).inDays : a.start.difference(b.end).inDays.abs();
    final proposed = a.jointWith == b.id;
    return SvCard(
      color: SvColors.sagePale.withValues(alpha: p.isDark ? .12 : .35),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.merge_type, color: SvColors.olive),
          const SizedBox(width: 10),
          Expanded(child: Text('${a.id} + ${b.id}', style: SvType.title(p.ink).copyWith(fontSize: 16))),
        ]),
        const SizedBox(height: 8),
        Text('${a.title} and ${b.title.toLowerCase()} open the same stretch of ${a.road.split(' ·').first} only $gap days apart.',
            style: SvType.bodySm(p.inkSoft)),
        const SizedBox(height: 14),
        proposed
            ? const SvTag('Joint work proposed', color: SvColors.forest, icon: Icons.check)
            : SvPillButton(
                label: 'Propose one shared trench',
                compact: true,
                onPressed: () {
                  store.proposeJointWork(a, b);
                  _toast(context, 'Joint work proposed to both departments.');
                },
              ),
      ]),
    );
  }
}

class _AdminHome extends StatelessWidget {
  const _AdminHome();
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    final labelCounts = {for (final l in DataLabel.values) l: store.assets.where((a) => a.label == l).length};
    return _Page(children: [
      const SvEyebrow('Administrator · demo'),
      const SizedBox(height: 10),
      Text('Platform\noverview', style: SvType.heading1(p.ink)),
      const SizedBox(height: 28),
      const SvSectionHeader(eyebrow: 'Data integrity', title: 'What every record claims to be'),
      const SizedBox(height: 16),
      SvCard(
        child: Column(children: [
          for (final l in DataLabel.values) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 150, child: Align(alignment: Alignment.centerLeft, child: SvTag(l.label, color: l.color))),
              Expanded(child: Text(l.meaning, style: SvType.caption(p.inkSoft))),
              const SizedBox(width: 8),
              Text('${labelCounts[l]}', style: SvType.title(p.ink).copyWith(fontSize: 17)),
            ]),
            if (l != DataLabel.values.last) const SvHairline(vertical: 10),
          ],
        ]),
      ),
      const SizedBox(height: 36),
      const SvSectionHeader(eyebrow: 'Departments', title: 'Configured for Manaparai'),
      const SizedBox(height: 16),
      SvCard(
        child: Column(children: [
          for (final d in demoDepartments) ...[
            Row(children: [
              Icon(d.icon, color: d.color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.name, style: SvType.body(p.ink).copyWith(fontWeight: FontWeight.w600)),
                  Text('${d.checklist.length}-item checklist · '
                      '${store.works.expand((w) => w.reviews).where((r) => r.deptId == d.id && !r.status.isCleared).length} open reviews',
                      style: SvType.caption(p.muted)),
                ]),
              ),
            ]),
            if (d != demoDepartments.last) const SvHairline(vertical: 12),
          ],
        ]),
      ),
      const SizedBox(height: 36),
      const SvSectionHeader(eyebrow: 'People', title: 'Demo accounts'),
      const SizedBox(height: 16),
      SvCard(
        child: Column(children: [
          for (final person in demoPeople) ...[
            Row(children: [
              Icon(person.role.icon, size: 20, color: p.inkSoft),
              const SizedBox(width: 12),
              Expanded(child: Text(person.name, style: SvType.bodySm(p.ink))),
              SvTag(person.role.short, color: SvColors.stone),
            ]),
            if (person != demoPeople.last) const SvHairline(vertical: 10),
          ],
        ]),
      ),
      const SizedBox(height: 16),
      Text('In a real deployment roles are assigned on the server and enforced by row-level security; '
          'the demo profile switch never grants access.',
          style: SvType.caption(p.muted)),
      const SizedBox(height: 28),
      SvPillButton(
        label: 'Reset demo data',
        icon: Icons.restart_alt,
        kind: SvButtonKind.outline,
        onPressed: () {
          store.reset();
          _toast(context, 'Demo data restored to its starting state.');
        },
      ),
    ]);
  }
}

// =============================================================================
// Works
// =============================================================================

/// Lets a host app (the main SAMANVAY app) open work items and reports from
/// the bus stand map in its own screens instead of the standalone demo pages.
class BusStandDemoActions extends InheritedWidget {
  const BusStandDemoActions({super.key, required this.openWork, required this.openGrievance, required super.child});
  final void Function(BuildContext context, String workId) openWork;
  final void Function(BuildContext context, String grievanceId) openGrievance;
  static BusStandDemoActions? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<BusStandDemoActions>();
  @override
  bool updateShouldNotify(BusStandDemoActions oldWidget) => false;
}

void _openWork(BuildContext context, WorkItem w) {
  final host = BusStandDemoActions.maybeOf(context);
  if (host != null) return host.openWork(context, w.id);
  _openWorkLocal(context, w);
}

void _openWorkLocal(BuildContext context, WorkItem w) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkDetailPage(workId: w.id)));

class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.work, this.focusDept});
  final WorkItem work;
  final String? focusDept;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    final citizen = store.role == DemoRole.citizen;
    final review = focusDept == null ? null : work.reviews.where((r) => r.deptId == focusDept).firstOrNull;
    return SvCard(
      onTap: () => _openWork(context, work),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(work.id, style: SvType.eyebrow(p.muted)),
              if (review?.isApplicant ?? false) ...[
                const SizedBox(width: 8),
                const SvTag('Applicant', color: SvColors.stone),
              ],
            ]),
            const SizedBox(height: 6),
            Text(work.title, style: SvType.title(p.ink)),
            const SizedBox(height: 4),
            Text(work.road, style: SvType.bodySm(p.inkSoft)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              SvTag(work.status.label, color: work.status.color),
              if (review != null) SvTag(review.status.label, color: review.status.color),
              if (citizen) SvTag('${_date(work.start)} – ${_date(work.end)}', color: SvColors.stone),
              if (!citizen && review == null) SvTag('${work.clearedCount}/${work.reviews.length} departments cleared', color: SvColors.olive),
            ]),
          ]),
        ),
        const SizedBox(width: 12),
        if (review != null)
          SvProgressRing(done: review.done, total: review.total, size: 52)
        else
          Icon(Icons.arrow_forward, color: p.muted),
      ]),
    );
  }
}

class _WorksTab extends StatefulWidget {
  const _WorksTab();
  @override
  State<_WorksTab> createState() => _WorksTabState();
}

class _WorksTabState extends State<_WorksTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    bool keep(WorkItem w) => switch (_filter) {
          'review' => w.status == WorkStatus.underDepartmentReview || w.status == WorkStatus.coordinationPending || w.status == WorkStatus.clarificationRequired,
          'active' => w.status == WorkStatus.scheduled || w.status == WorkStatus.inProgress || w.status == WorkStatus.approvedForDemonstration,
          'restore' => w.status == WorkStatus.restorationPending,
          'done' => w.status == WorkStatus.completed,
          _ => true,
        };
    final list = store.works.where(keep).toList();
    return _Page(children: [
      const SvEyebrow('Works & excavation'),
      const SizedBox(height: 10),
      Text('Every trench,\none record', style: SvType.heading1(p.ink)),
      const SizedBox(height: 20),
      SvPillTabs<String>(
        options: const [('all', 'All'), ('review', 'In review'), ('active', 'Scheduled'), ('restore', 'Restoration'), ('done', 'Completed')],
        selected: _filter,
        onChanged: (v) => setState(() => _filter = v),
      ),
      const SizedBox(height: 20),
      if (list.isEmpty) const SvEmptyState(title: 'Nothing here', message: 'No work items match this filter.'),
      for (final w in list) ...[_WorkCard(work: w), const SizedBox(height: 12)],
    ]);
  }
}

class WorkDetailPage extends StatelessWidget {
  const WorkDetailPage({super.key, required this.workId});
  final String workId;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    final w = store.work(workId);
    final citizen = store.role == DemoRole.citizen;
    final screening = store.screen(w);
    final next = store.nextAction(w);
    final entries = store.activity.where((a) => a.ref == w.id && (!citizen || a.public)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(w.id, style: SvType.ui(p.inkSoft).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        actions: const [_ThemeToggle(), SizedBox(width: 12)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
        children: [
          SvEyebrow('${deptById(w.applicantDept).name} · applicant'),
          const SizedBox(height: 8),
          Text(w.title, style: SvType.heading1(p.ink)),
          const SizedBox(height: 6),
          Text(w.road, style: SvType.bodyLg(p.inkSoft)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SvTag(w.status.label, color: w.status.color, solid: true),
            SvTag(DataLabel.demonstration.label, color: DataLabel.demonstration.color, icon: Icons.science_outlined),
            if (w.jointWith != null) SvTag('Joint work with ${w.jointWith}', color: SvColors.olive, icon: Icons.merge_type),
          ]),
          const SizedBox(height: 24),
          _StatusStepper(work: w),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(SvRadius.lg),
            child: SizedBox(height: 210, child: BusStandMap(store: store, focusWork: w, interactive: false)),
          ),
          const SizedBox(height: 24),
          SvCard(
            child: Column(children: [
              _Fact('Contractor', w.contractor),
              _Fact('Work window', '${_date(w.start)} – ${_date(w.end)}'),
              _Fact('Length', '${w.lengthM.round()} m'),
              _Fact('Method', w.workType),
              _Fact('Scope', w.description, last: true),
            ]),
          ),
          if (next != null) ...[
            const SizedBox(height: 24),
            SvPillButton(
              label: next.$1,
              kind: SvButtonKind.primary,
              expand: true,
              onPressed: () {
                final error = store.advance(w);
                _toast(context, error ?? 'Status updated: ${w.status.label}.');
              },
            ),
          ],
          const SizedBox(height: 40),
          _ScreeningSection(work: w, result: screening, citizen: citizen),
          const SizedBox(height: 40),
          _DepartmentChecklists(work: w),
          const SizedBox(height: 40),
          _RestorationSection(work: w),
          const SizedBox(height: 40),
          const SvSectionHeader(eyebrow: 'Below the surface', title: 'Cross-section at mid-route'),
          const SizedBox(height: 16),
          SvCard(padding: const EdgeInsets.all(14), child: UndergroundCrossSection(store: store, work: w)),
          const SizedBox(height: 40),
          const SvSectionHeader(eyebrow: 'History', title: 'Activity on this work'),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text('No recorded activity yet.', style: SvType.bodySm(p.muted))
          else
            for (final e in entries) _TimelineRow(entry: e),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.last = false});
  final String label;
  final String value;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 104, child: Text(label, style: SvType.bodySm(p.muted))),
        Expanded(child: Text(value, style: SvType.bodySm(p.ink))),
      ]),
      if (!last) const SvHairline(vertical: 10),
    ]);
  }
}

class _StatusStepper extends StatelessWidget {
  const _StatusStepper({required this.work});
  final WorkItem work;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final currentIndex = work.status == WorkStatus.clarificationRequired
        ? workLifecycle.indexOf(WorkStatus.underDepartmentReview)
        : workLifecycle.indexOf(work.status);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < workLifecycle.length; i++) ...[
          SizedBox(
            width: 86,
            child: Column(children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < currentIndex ? SvColors.forest : (i == currentIndex ? p.ink : Colors.transparent),
                  border: Border.all(color: i <= currentIndex ? Colors.transparent : p.hairline, width: 1.5),
                ),
                child: i < currentIndex
                    ? const Icon(Icons.check, size: 16, color: SvColors.canvas)
                    : Text('${i + 1}', style: SvType.caption(i == currentIndex ? p.canvas : p.muted).copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Text(
                workLifecycle[i].label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: SvType.caption(i == currentIndex ? p.ink : p.muted)
                    .copyWith(fontSize: 11, fontWeight: i == currentIndex ? FontWeight.w700 : FontWeight.w400),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ScreeningSection extends StatelessWidget {
  const _ScreeningSection({required this.work, required this.result, required this.citizen});
  final WorkItem work;
  final ScreeningResult result;
  final bool citizen;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    Widget check(String n, String title, String question, String answer, Color c) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 1.5)),
              child: Text(n, style: SvType.ui(c).copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: SvType.body(p.ink).copyWith(fontWeight: FontWeight.w600)),
                Text(question, style: SvType.caption(p.muted)),
                const SizedBox(height: 4),
                Text(answer, style: SvType.bodySm(p.inkSoft)),
              ]),
            ),
          ]),
        );
    final ids = result.overlaps.take(4).map((a) => a.id).join(', ');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SvSectionHeader(
        eyebrow: 'Screening',
        title: 'Three checks before the road opens',
        lead: 'Screening informs people. It never certifies that ground is safe and never approves work.',
      ),
      const SizedBox(height: 16),
      SvCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(result.headline, style: SvType.title(p.ink)),
          const SizedBox(height: 4),
          Text('Corridor ±${work.corridorHalfWidth} m · clearance 10 m · demonstration records only', style: SvType.caption(p.muted)),
          const SvHairline(),
          check(
            '1',
            'Spatial',
            'Does the corridor touch mapped records?',
            result.overlaps.isEmpty
                ? '${result.nearby.length} records within clearance; none inside the corridor.'
                : '${result.overlaps.length} inside the corridor${citizen ? '' : ' ($ids${result.overlaps.length > 4 ? '…' : ''})'}, ${result.nearby.length} more within clearance.',
            result.overlaps.isEmpty ? SvColors.olive : SvColors.error,
          ),
          check(
            '2',
            'Data confidence',
            'How far can we trust those records?',
            result.uncertain.isEmpty
                ? 'No estimated or unverified records involved.'
                : '${result.uncertain.length} estimated or unverified records — field verification suggested before digging.',
            result.uncertain.isEmpty ? SvColors.olive : SvColors.gold,
          ),
          check(
            '3',
            'Dig once',
            'Is anyone else opening this road soon?',
            result.digOnce.isEmpty
                ? 'No other work on this segment within 90 days.'
                : '${result.digOnce.map((o) => '${o.id} (${o.title.toLowerCase()})').join(', ')} on the same segment — consider one shared trench.',
            result.digOnce.isEmpty ? SvColors.olive : SvColors.clay,
          ),
          Text('“No mapped conflict” means nothing is mapped there — not that nothing is buried.', style: SvType.caption(p.muted)),
        ]),
      ),
    ]);
  }
}

// -----------------------------------------------------------------------------
// Department-wise checklist boxes
// -----------------------------------------------------------------------------

class _DepartmentChecklists extends StatelessWidget {
  const _DepartmentChecklists({required this.work});
  final WorkItem work;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    final totalDone = work.reviews.fold<int>(0, (s, r) => s + r.done);
    final total = work.reviews.fold<int>(0, (s, r) => s + r.total);
    final mine = work.reviews.where(store.canEditReview).toList();
    final others = work.reviews.where((r) => !store.canEditReview(r)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SvSectionHeader(
        eyebrow: 'Department checklists',
        title: '${work.clearedCount} of ${work.reviews.length} departments cleared',
        trailing: SvProgressRing(done: totalDone, total: total, size: 56),
      ),
      const SizedBox(height: 6),
      Text(
        store.role == DemoRole.officer
            ? (mine.isEmpty
                ? '${deptById(store.officerDept).name} is not part of this work item.'
                : 'Tick your department’s items, then record a decision. Other departments are read-only.')
            : store.role == DemoRole.citizen
                ? 'Each department confirms its own checklist before work can be approved.'
                : 'Each box is owned by one department. Approval needs every box cleared.',
        style: SvType.bodySm(p.inkSoft),
      ),
      const SizedBox(height: 16),
      for (final r in [...mine, ...others]) ...[
        DepartmentChecklistBox(work: work, review: r),
        const SizedBox(height: 12),
      ],
    ]);
  }
}

class DepartmentChecklistBox extends StatefulWidget {
  const DepartmentChecklistBox({super.key, required this.work, required this.review});
  final WorkItem work;
  final DepartmentReview review;
  @override
  State<DepartmentChecklistBox> createState() => _DepartmentChecklistBoxState();
}

class _DepartmentChecklistBoxState extends State<DepartmentChecklistBox> {
  bool? _expanded;

  Future<void> _decide(ReviewStatus decision) async {
    final store = BusStandDemoScope.of(context);
    var note = '';
    if (decision != ReviewStatus.cleared) {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) {
          final p = SvPalette.of(dialog);
          return AlertDialog(
            title: Text(decision.label, style: SvType.heading2(p.ink)),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: decision == ReviewStatus.clearedWithConditions ? 'Conditions the site team must follow' : 'What needs to change, and why',
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text('Cancel', style: SvType.ui(p.inkSoft))),
              SvPillButton(label: 'Record', compact: true, onPressed: () => Navigator.pop(dialog, true)),
            ],
          );
        },
      );
      note = controller.text;
      controller.dispose();
      if (ok != true) return;
    }
    if (!mounted) return;
    final error = store.decide(widget.work, widget.review, decision, note);
    _toast(context, error ?? '${widget.review.dept.name}: ${decision.label.toLowerCase()}.');
  }

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    final r = widget.review;
    final d = r.dept;
    final editable = store.canEditReview(r);
    final citizen = store.role == DemoRole.citizen;
    final expanded = _expanded ?? (editable || (store.role == DemoRole.coordinator && !r.status.isCleared));
    return SvCard(
      padding: EdgeInsets.zero,
      borderColor: editable ? d.color.withValues(alpha: .6) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: citizen ? null : () => setState(() => _expanded = !expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: d.color.withValues(alpha: p.isDark ? .25 : .12)),
                child: Icon(d.icon, color: p.isDark ? Color.lerp(d.color, Colors.white, .4) : d.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.name, style: SvType.body(p.ink).copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    SvTag(r.status.label, color: r.status.color),
                    if (r.isApplicant) const SvTag('Applicant', color: SvColors.stone),
                  ]),
                ]),
              ),
              SvProgressRing(done: r.done, total: r.total, size: 44),
              if (!citizen) Icon(expanded ? Icons.expand_less : Icons.expand_more, color: p.muted),
            ]),
          ),
        ),
        if (expanded && !citizen) ...[
          Divider(height: 1, color: p.hairline),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 16, 4),
            child: Column(children: [
              for (var i = 0; i < r.checks.length; i++)
                InkWell(
                  onTap: editable ? () => store.toggleCheck(widget.work, r, i) : null,
                  borderRadius: BorderRadius.circular(SvRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Checkbox(
                        value: r.checks[i],
                        onChanged: editable ? (_) => store.toggleCheck(widget.work, r, i) : null,
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            d.checklist[i],
                            style: SvType.bodySm(r.checks[i] ? p.ink : p.inkSoft),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
          if (r.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(SvRadius.md)),
                child: Text('“${r.note}”', style: SvType.lead(p.inkSoft).copyWith(fontSize: 15, fontStyle: FontStyle.italic)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
            child: editable
                ? Wrap(spacing: 8, runSpacing: 8, children: [
                    SvPillButton(
                      label: 'Clear',
                      icon: Icons.check,
                      compact: true,
                      onPressed: r.complete ? () => _decide(ReviewStatus.cleared) : null,
                    ),
                    SvPillButton(
                      label: 'Clear with conditions',
                      compact: true,
                      kind: SvButtonKind.outline,
                      onPressed: r.complete ? () => _decide(ReviewStatus.clearedWithConditions) : null,
                    ),
                    SvPillButton(label: 'Ask to clarify', compact: true, kind: SvButtonKind.outline, onPressed: () => _decide(ReviewStatus.clarification)),
                    SvPillButton(label: 'Raise objection', compact: true, kind: SvButtonKind.outline, onPressed: () => _decide(ReviewStatus.objection)),
                    if (!r.complete)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Tick all ${r.total} items to clear.', style: SvType.caption(p.muted)),
                      ),
                  ])
                : Row(children: [
                    Icon(Icons.lock_outline, size: 15, color: p.muted),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Only the ${d.name} officer can tick this checklist.', style: SvType.caption(p.muted))),
                  ]),
          ),
        ],
      ]),
    );
  }
}

class _RestorationSection extends StatelessWidget {
  const _RestorationSection({required this.work});
  final WorkItem work;
  @override
  Widget build(BuildContext context) {
    final store = BusStandDemoScope.of(context);
    final r = work.restoration;
    final stageColor = switch (r.stage) {
      RestorationStage.inspectionPassed => SvColors.forest,
      RestorationStage.inspectionFailed => SvColors.error,
      RestorationStage.restored => SvColors.ochre,
      RestorationStage.workInProgress => const Color(0xFF3F6E8C),
      RestorationStage.notStarted => SvColors.ash,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SvSectionHeader(eyebrow: 'After the work', title: 'Road restoration'),
      const SizedBox(height: 16),
      SvCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SvTag(r.stage.label, color: stageColor),
          const SizedBox(height: 14),
          _Fact('Specification', r.method),
          _Fact('Cut area', '${r.lengthM.round()} m × ${r.widthM} m'),
          _Fact('Evidence', r.photos == 0 ? 'No photos yet' : '${r.photos} demo photos on record', last: true),
          if (store.canInspectRestoration(work)) ...[
            const SizedBox(height: 18),
            Wrap(spacing: 8, runSpacing: 8, children: [
              SvPillButton(label: 'Inspection passed', icon: Icons.verified_outlined, compact: true, onPressed: () => store.recordInspection(work, true)),
              SvPillButton(label: 'Request rework', compact: true, kind: SvButtonKind.outline, onPressed: () => store.recordInspection(work, false)),
            ]),
          ],
        ]),
      ),
    ]);
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry});
  final ActivityEntry entry;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(shape: BoxShape.circle, color: p.surfaceAlt),
          child: Icon(entry.icon, size: 17, color: p.inkSoft),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.text, style: SvType.bodySm(p.ink)),
            const SizedBox(height: 2),
            Text('${entry.actor} · ${_ago(entry.time)}${entry.ref == null ? '' : ' · ${entry.ref}'}', style: SvType.caption(p.muted)),
          ]),
        ),
      ]),
    );
  }
}

// =============================================================================
// Map tab
// =============================================================================

class BusStandDemoMapTab extends StatefulWidget {
  const BusStandDemoMapTab({super.key});
  @override
  State<BusStandDemoMapTab> createState() => _MapTabState();
}

class _MapTabState extends State<BusStandDemoMapTab> {
  bool _in3d = false;

  /// Zoomed far in: open the 3D underground view of the road in the middle.
  void _checkZoom() {
    final m = _mapKey.currentState;
    if (m == null || _in3d || !underground3dAuto.value) return;
    if (m.scale >= kUnderground3dScale) _open3d(m.centreInStand);
  }

  Future<void> _open3d(Offset? centre) async {
    final store = BusStandDemoScope.of(context);
    final c = centre ?? _mapKey.currentState?.centreInStand ?? const Offset(500, 300);
    _in3d = true;
    final openId = await openUnderground3D(context, store, c);
    if (!mounted) return;
    _mapKey.currentState?.showAt(c, kUnderground3dReturnScale);
    _in3d = false;
    if (openId == null) return;
    final a = store.assets.where((a) => a.id == openId).firstOrNull;
    if (a != null) setState(() => _selection = AssetSelection(a));
  }

  final _mapKey = GlobalKey<BusStandMapState>();
  MapSelection? _selection;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    return Stack(children: [
      Positioned.fill(
        child: BusStandMap(key: _mapKey, store: store, onSelect: (s) => setState(() => _selection = s), onViewChanged: _checkZoom),
      ),
      Positioned(
        left: 16,
        right: 76,
        top: 14,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: p.isDark ? const Color(0xFF3A3020) : SvColors.goldPale.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(SvRadius.full),
            ),
            child: Text(
              'SAMPLE RECORDS · NOT FOR EXCAVATION',
              style: SvType.eyebrow(p.isDark ? SvColors.goldPale : SvColors.goldDeep).copyWith(fontSize: 10),
            ),
          ),
        ),
      ),
      Positioned(
        right: 16,
        top: 12,
        child: Column(children: [
          SvIconCircle(
            icon: Icons.layers_outlined,
            filled: true,
            tooltip: 'Layers',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => FractionallySizedBox(heightFactor: .78, child: MapLayerPanel(store: store)),
            ),
          ),
          const SizedBox(height: 10),
          SvIconCircle(icon: Icons.center_focus_strong_outlined, filled: true, tooltip: 'Fit bus stand', onPressed: () => _mapKey.currentState?.recenter()),
          const SizedBox(height: 10),
          SvIconCircle(icon: Icons.view_in_ar_outlined, filled: true, tooltip: 'Underground in 3D', onPressed: () => _open3d(null)),
        ]),
      ),
      Positioned(
        left: 16,
        right: 16,
        bottom: 16,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _selection == null
              ? Container(
                  key: const ValueKey('legend'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: p.surface.withValues(alpha: .96),
                    borderRadius: BorderRadius.circular(SvRadius.full),
                    border: Border.all(color: p.hairline),
                  ),
                  child: MapLegendStrip(store: store),
                )
              : _SelectionCard(
                  key: ValueKey(_selection),
                  selection: _selection!,
                  onClose: () => _mapKey.currentState?.clearSelection(),
                ),
        ),
      ),
    ]);
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({super.key, required this.selection, required this.onClose});
  final MapSelection selection;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    final citizen = store.role == DemoRole.citizen;
    final (String eyebrow, String title, List<Widget> body) = switch (selection) {
      AssetSelection(:final asset) => (
          '${asset.kind.label} · ${asset.owner.name}',
          asset.isPoint ? '${asset.pointType![0].toUpperCase()}${asset.pointType!.substring(1)} ${asset.id}' : asset.id,
          [
            Wrap(spacing: 8, runSpacing: 8, children: [
              SvTag(asset.label.label, color: asset.label.color),
              if (!asset.isPoint) SvTag('${asset.lengthM.round()} m', color: SvColors.stone),
            ]),
            const SizedBox(height: 12),
            Text(
              citizen
                  ? '${asset.road}. Detailed attributes are shown to departments only.'
                  : '${asset.road} · ${asset.material} · ${asset.size} · '
                      '${asset.label == DataLabel.estimated ? 'est. ' : ''}${asset.depthM.toStringAsFixed(1)} m deep · laid ${asset.installYear}',
              style: SvType.bodySm(p.inkSoft),
            ),
          ],
        ),
      WorkSelection(:final work) => (
          '${work.id} · ${deptById(work.applicantDept).name}',
          work.title,
          [
            SvTag(work.status.label, color: work.status.color),
            const SizedBox(height: 10),
            Text('${work.road} · ${_date(work.start)} – ${_date(work.end)}', style: SvType.bodySm(p.inkSoft)),
            const SizedBox(height: 14),
            SvPillButton(label: 'Open work item', compact: true, onPressed: () => _openWork(context, work)),
          ],
        ),
      GrievanceSelection(:final grievance) => (
          '${grievance.id} · citizen report',
          grievance.title,
          [
            SvTag(grievance.status.label, color: grievance.status.color),
            const SizedBox(height: 10),
            Text(grievance.location, style: SvType.bodySm(p.inkSoft)),
            const SizedBox(height: 14),
            SvPillButton(label: 'Open report', compact: true, onPressed: () => _openGrievance(context, grievance)),
          ],
        ),
    };
    return SvCard(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SvEyebrow(eyebrow),
              const SizedBox(height: 4),
              Text(title, style: SvType.heading2(p.ink).copyWith(fontSize: 22)),
            ]),
          ),
          IconButton(onPressed: onClose, icon: Icon(Icons.close, color: p.muted), tooltip: 'Close'),
        ]),
        const SizedBox(height: 8),
        ...body,
      ]),
    );
  }
}

// =============================================================================
// Reports (grievances)
// =============================================================================

class _GrievanceCard extends StatelessWidget {
  const _GrievanceCard({required this.g});
  final Grievance g;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return SvCard(
      onTap: () => _openGrievance(context, g),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(g.id, style: SvType.eyebrow(p.muted))),
          Text(_ago(g.submitted), style: SvType.caption(p.muted)),
        ]),
        const SizedBox(height: 6),
        Text(g.title, style: SvType.title(p.ink).copyWith(fontSize: 17)),
        const SizedBox(height: 4),
        Text(g.location, style: SvType.bodySm(p.inkSoft)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          SvTag(g.status.label, color: g.status.color),
          SvTag(deptById(g.routedTo).name, color: SvColors.stone, icon: Icons.call_split),
          if (g.linkedWork != null) SvTag('Linked to ${g.linkedWork}', color: SvColors.olive),
        ]),
      ]),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    final citizen = store.role == DemoRole.citizen;
    final visible = store.role == DemoRole.officer ? store.grievances.where((g) => g.routedTo == store.officerDept).toList() : store.grievances;
    return _Page(children: [
      const SvEyebrow('Citizen reports'),
      const SizedBox(height: 10),
      Text(citizen ? 'Tell us what\nyou see' : 'Reports from\nthe street', style: SvType.heading1(p.ink)),
      const SizedBox(height: 8),
      Text(
        citizen
            ? 'Leaks, open trenches, waterlogging — every report gets a reference number and a visible trail.'
            : 'Each report is routed to the department that owns the problem.',
        style: SvType.lead(p.inkSoft),
      ),
      if (citizen) ...[
        const SizedBox(height: 20),
        SvPillButton(label: 'Report a problem', icon: Icons.add, kind: SvButtonKind.primary, expand: true, onPressed: () => _openGrievanceForm(context)),
      ],
      const SizedBox(height: 28),
      if (visible.isEmpty) const SvEmptyState(title: 'No reports', message: 'Nothing has been routed here yet.'),
      for (final g in visible) ...[_GrievanceCard(g: g), const SizedBox(height: 12)],
    ]);
  }
}

void _openGrievance(BuildContext context, Grievance g) {
  final host = BusStandDemoActions.maybeOf(context);
  if (host != null) return host.openGrievance(context, g.id);
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => _GrievanceDetail(id: g.id)));
}

void _openGrievanceForm(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _GrievanceForm()));

class _GrievanceDetail extends StatelessWidget {
  const _GrievanceDetail({required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    final g = store.grievances.firstWhere((x) => x.id == id);
    final canAct = store.canHandleGrievance(g) && g.status != GrievanceStatus.closed;
    final nextLabel = g.status == GrievanceStatus.closed ? null : GrievanceStatus.values[GrievanceStatus.values.indexOf(g.status) + 1].label;
    return Scaffold(
      appBar: AppBar(title: Text(g.id, style: SvType.ui(p.inkSoft).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 48), children: [
        SvEyebrow(grievanceCategories.firstWhere((c) => c.$1 == g.category).$2),
        const SizedBox(height: 8),
        Text(g.title, style: SvType.heading1(p.ink)),
        const SizedBox(height: 8),
        Text(g.location, style: SvType.bodyLg(p.inkSoft)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          SvTag(g.status.label, color: g.status.color, solid: true),
          SvTag('Routed to ${deptById(g.routedTo).name}', color: SvColors.stone),
          if (g.photos > 0) SvTag('${g.photos} photo${g.photos == 1 ? '' : 's'}', color: SvColors.stone, icon: Icons.photo_camera_outlined),
        ]),
        const SizedBox(height: 20),
        SvCard(child: Text(g.description, style: SvType.body(p.ink))),
        if (g.linkedWork != null) ...[
          const SizedBox(height: 12),
          SvCard(
            onTap: () => _openWork(context, store.work(g.linkedWork!)),
            child: Row(children: [
              const Icon(Icons.link, color: SvColors.olive),
              const SizedBox(width: 12),
              Expanded(child: Text('Linked to ${g.linkedWork} · ${store.work(g.linkedWork!).title}', style: SvType.bodySm(p.ink))),
              Icon(Icons.arrow_forward, color: p.muted),
            ]),
          ),
        ],
        if (canAct && nextLabel != null) ...[
          const SizedBox(height: 20),
          SvPillButton(label: 'Mark as $nextLabel', kind: SvButtonKind.primary, expand: true, onPressed: () => store.advanceGrievance(g)),
        ],
        const SizedBox(height: 36),
        const SvSectionHeader(eyebrow: 'Trail', title: 'What happened'),
        const SizedBox(height: 12),
        for (final (t, text) in g.trail.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: g.status.color)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(text, style: SvType.bodySm(p.ink)),
                  Text(_ago(t), style: SvType.caption(p.muted)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _GrievanceForm extends StatefulWidget {
  const _GrievanceForm();
  @override
  State<_GrievanceForm> createState() => _GrievanceFormState();
}

class _GrievanceFormState extends State<_GrievanceForm> {
  String _category = grievanceCategories.first.$1;
  String _place = standPlaces.first.$1;
  final _title = TextEditingController();
  final _description = TextEditingController();
  int _photos = 0;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      _toast(context, 'Add a short title for the report.');
      return;
    }
    final store = BusStandDemoScope.of(context);
    final g = store.submitGrievance(
      category: _category,
      title: _title.text.trim(),
      location: _place,
      description: _description.text.trim().isEmpty ? 'No further details given.' : _description.text.trim(),
      photos: _photos,
    );
    await showDialog<void>(
      context: context,
      builder: (dialog) {
        final p = SvPalette.of(dialog);
        return AlertDialog(
          title: Text('Report received', style: SvType.heading2(p.ink)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your reference', style: SvType.caption(p.muted)),
            Text(g.id, style: SvType.heading3(p.ink)),
            const SizedBox(height: 10),
            Text('Suggested route: ${deptById(g.routedTo).name}. You can track every step under Reports.', style: SvType.bodySm(p.inkSoft)),
          ]),
          actions: [SvPillButton(label: 'Done', compact: true, onPressed: () => Navigator.pop(dialog))],
        );
      },
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('New report', style: SvType.ui(p.inkSoft).copyWith(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 48), children: [
        Text('What did\nyou notice?', style: SvType.heading1(p.ink)),
        const SizedBox(height: 24),
        const SvEyebrow('Category'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (id, label) in grievanceCategories)
            ChoiceChip(
              label: Text(label),
              selected: _category == id,
              onSelected: (_) => setState(() => _category = id),
              shape: StadiumBorder(side: BorderSide(color: _category == id ? SvColors.silver : p.hairline, width: _category == id ? 2 : 1)),
              showCheckmark: false,
              backgroundColor: Colors.transparent,
              selectedColor: p.surface,
              labelStyle: SvType.ui(p.ink),
            ),
        ]),
        const SizedBox(height: 24),
        const SvEyebrow('Where'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _place,
          items: [for (final (name, _) in standPlaces) DropdownMenuItem(value: name, child: Text(name, style: SvType.bodySm(p.ink)))],
          onChanged: (v) => setState(() => _place = v ?? _place),
          dropdownColor: p.surface,
        ),
        const SizedBox(height: 24),
        const SvEyebrow('Details'),
        const SizedBox(height: 10),
        TextField(controller: _title, decoration: const InputDecoration(hintText: 'Short title, e.g. “Pipe leaking near gate 2”')),
        const SizedBox(height: 12),
        TextField(controller: _description, maxLines: 4, decoration: const InputDecoration(hintText: 'What, since when, anything unsafe?')),
        const SizedBox(height: 16),
        SvPillButton(
          label: _photos == 0 ? 'Attach a photo (demo)' : '$_photos demo photo${_photos == 1 ? '' : 's'} attached',
          icon: Icons.photo_camera_outlined,
          kind: SvButtonKind.outline,
          onPressed: () => setState(() => _photos++),
        ),
        const SizedBox(height: 8),
        Text('Your name and contact details are never shown on the public map.', style: SvType.caption(p.muted)),
        const SizedBox(height: 28),
        SvPillButton(label: 'Submit report', kind: SvButtonKind.primary, expand: true, onPressed: _submit),
      ]),
    );
  }
}

// =============================================================================
// Activity
// =============================================================================

class _ActivityTab extends StatelessWidget {
  const _ActivityTab();
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final store = BusStandDemoScope.of(context);
    final citizen = store.role == DemoRole.citizen;
    final entries = store.activity.where((a) => !citizen || a.public).toList();
    return _Page(children: [
      SvEyebrow(citizen ? 'Public updates' : 'Audit trail'),
      const SizedBox(height: 10),
      Text(citizen ? 'What changed\nat the bus stand' : 'Who did what,\nand when', style: SvType.heading1(p.ink)),
      const SizedBox(height: 8),
      Text(
        citizen ? 'Public status changes for works and reports.' : 'Every tick, decision and status change is recorded.',
        style: SvType.lead(p.inkSoft),
      ),
      const SizedBox(height: 20),
      for (final e in entries) ...[
        _TimelineRow(entry: e),
        Divider(height: 1, color: p.hairline),
      ],
    ]);
  }
}
