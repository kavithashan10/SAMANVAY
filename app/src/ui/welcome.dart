import 'package:flutter/material.dart';

import '../../busstand_demo_data.dart' show demoDepartments;
import '../../samanvay_design.dart';
import '../core/models.dart';
import 'brand.dart';
import 'common.dart';
import 'session.dart';

/// First launch: what SAMANVAY is, then "who are you?". No account needed —
/// the role is remembered on this device and can be changed from the profile.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    const steps = [
      ('01', 'Request', 'Mark where and when you need to dig. Every request gets a reference number.'),
      ('02', 'Check', 'Each department ticks its own checklist; the map flags pipes, cables and other planned works nearby.'),
      ('03', 'Dig once', 'Combine works on the same road, record the restoration, and close with evidence.'),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            Row(children: [
              const Expanded(child: SvEyebrow('Infrastructure coordination')),
              const ThemeToggleButton(),
            ]),
            const Gap(28),
            const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 96)),
            const Gap(26),
            Text('Know below.\nDig above.', style: SvType.display(p.ink)),
            const Gap(16),
            Text('One shared map and one workflow for every department that digs the same road.', style: SvType.lead(p.inkSoft)),
            const Gap(36),
            const SvEyebrow('Get started'),
            const Gap(8),
            Text('Who is using SAMANVAY?', style: SvType.heading2(p.ink)),
            const Gap(6),
            Text('Pick your role. You can change it any time from your profile.', style: SvType.bodySm(p.inkSoft)),
            const Gap(18),
            const RoleChooser(),
            const Gap(44),
            const SvEyebrow('How it works'),
            const Gap(8),
            Text('Three steps, every department', style: SvType.heading2(p.ink)),
            const Gap(16),
            for (final (n, title, body) in steps) ...[
              SvCard(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n, style: SvType.heading2(SvColors.gold).copyWith(fontSize: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: SvType.title(p.ink).copyWith(fontSize: 17)),
                      const Gap(4),
                      Text(body, style: SvType.bodySm(p.inkSoft)),
                    ]),
                  ),
                ]),
              ),
              const Gap(12),
            ],
            const Gap(28),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: SvColors.inkBandSoft, borderRadius: BorderRadius.circular(SvRadius.lg)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SvEyebrow('Honest by design', color: SvColors.mute),
                const Gap(10),
                Text('A map is advice, not clearance.', style: SvType.heading2(SvColors.canvas)),
                const Gap(10),
                Text(
                  'Every record says where it came from and how sure we are. Empty map areas mean “no data”, never “nothing buried”. '
                  'Field verification and the owning department’s clearance always come first.',
                  style: SvType.bodySm(SvColors.mute),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Role cards; the department officer card carries a department choice.
class RoleChooser extends StatefulWidget {
  const RoleChooser({super.key, this.onChosen});
  final VoidCallback? onChosen;
  @override
  State<RoleChooser> createState() => _RoleChooserState();
}

class _RoleChooserState extends State<RoleChooser> {
  late String _dept = context.session.repo?.user.departmentId ?? 'power';

  static String _blurb(AppRole r) => switch (r) {
        AppRole.citizen => 'See works near you, request work, report a problem.',
        AppRole.department => 'Review works that touch your network and tick your checklist.',
        AppRole.coordinator => 'See who has cleared what and move works forward.',
        AppRole.admin => 'Everything a coordinator sees, across all departments.',
      };

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final current = context.session.repo?.user;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final role in AppRole.values) ...[
        SvCard(
          onTap: () {
            context.session.chooseRole(role, departmentId: _dept);
            widget.onChosen?.call();
          },
          borderColor: current?.role == role ? p.ink : null,
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          child: Row(children: [
            Icon(role.icon, color: p.inkSoft),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(role.label, style: SvType.body(p.ink).copyWith(fontWeight: FontWeight.w600)),
                const Gap(2),
                Text(_blurb(role), style: SvType.caption(p.inkSoft)),
              ]),
            ),
            Icon(Icons.arrow_forward, color: p.muted, size: 18),
          ]),
        ),
        if (role == AppRole.department) ...[
          const Gap(8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final d in demoDepartments)
                ChoiceChip(label: Text(d.short), selected: _dept == d.id, onSelected: (_) => setState(() => _dept = d.id)),
            ]),
          ),
        ],
        const Gap(8),
      ],
    ]);
  }
}

/// Bottom sheet for changing role later.
Future<void> showRolePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final p = SvPalette.of(sheet);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SvEyebrow('Change role'),
            const Gap(6),
            Text('Use SAMANVAY as…', style: SvType.heading2(p.ink)),
            const Gap(18),
            RoleChooser(onChosen: () => Navigator.of(sheet).pop()),
          ]),
        ),
      );
    },
  );
}
