import 'package:flutter/material.dart';

import '../../samanvay_design.dart';
import '../core/models.dart';
import 'brand.dart';
import 'common.dart';
import 'home.dart';
import 'map_tab.dart';
import 'more.dart';
import 'session.dart';
import 'welcome.dart';
import 'works.dart';

/// Shell tabs, in the order of the work: what is happening, where, the works
/// themselves, citizen reports, and what changed.
enum ShellTab { home, map, works, reports, inbox }

class ShellController extends InheritedWidget {
  const ShellController({super.key, required this.go, required super.child});
  final void Function(ShellTab tab) go;
  static ShellController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellController>()!;
  @override
  bool updateShouldNotify(ShellController oldWidget) => false;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  ShellTab _tab = ShellTab.home;
  ValueNotifier<String?>? _focus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final f = context.session.mapFocus;
    if (!identical(f, _focus)) {
      _focus?.removeListener(_toMap);
      _focus = f..addListener(_toMap);
    }
  }

  @override
  void dispose() {
    _focus?.removeListener(_toMap);
    super.dispose();
  }

  void _toMap() {
    if (_focus?.value != null && mounted) setState(() => _tab = ShellTab.map);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    final user = repo.user;
    final subtitle = [
      user.role.label,
      if (user.departmentName != null) user.departmentName!,
    ].join(' · ');
    return ShellController(
      go: (t) => setState(() => _tab = t),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 64,
          titleSpacing: 20,
          title: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showRolePicker(context),
            child: BrandTitle(subtitle: subtitle),
          ),
          actions: [
            const ThemeToggleButton(),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: SvIconCircle(
                icon: user.role.icon,
                tooltip: 'Profile and settings',
                filled: true,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
            ),
          ],
        ),
        body: IndexedStack(
          index: _tab.index,
          children: [const HomeScreen(), MapTab(active: _tab == ShellTab.map), const WorksScreen(), const ReportsScreen(), const InboxScreen()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (i) => setState(() => _tab = ShellTab.values[i]),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.layers_outlined), selectedIcon: Icon(Icons.layers), label: 'Map'),
            NavigationDestination(icon: Icon(Icons.construction_outlined), selectedIcon: Icon(Icons.construction), label: 'Works'),
            NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: 'Reports'),
            NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox), label: 'Inbox'),
          ],
        ),
      ),
    );
  }
}

/// Section opener used across screens.
Widget sectionHeader(BuildContext context, String eyebrow, String title, {String? lead, Widget? trailing}) =>
    SvSectionHeader(eyebrow: eyebrow, title: title, lead: lead, trailing: trailing);

/// Kept for screens that need the palette without importing the design file.
SvPalette paletteOf(BuildContext context) => SvPalette.of(context);

/// Whether this user is the one who filed the case.
bool isMine(BuildContext context, CaseSummary c) => c.requesterId != null && c.requesterId == context.repo.user.id;
