import 'package:flutter/material.dart';

import '../../lpu_demo_app.dart' show LpuDemoMapTab, LpuDemoActions;
import '../../lpu_demo_data.dart' show LpuDemoScope;
import '../../samanvay_design.dart';
import '../core/geo.dart';
import '../data/local_repository.dart';
import 'common.dart';
import 'session.dart';
import 'shell.dart';
import 'works.dart';

class MapTab extends StatelessWidget {
  const MapTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.repo as LocalRepository;
    return LpuDemoScope(
      store: repo.store,
      child: LpuDemoActions(
        openWork: (ctx, id) => openCase(ctx, id),
        openGrievance: (ctx, _) => ShellController.of(context).go(ShellTab.reports),
        child: Stack(children: [
          const Positioned.fill(child: LpuDemoMapTab()),
          Positioned(
            right: 16,
            top: 116,
            child: SvIconCircle(
              icon: Icons.info_outline,
              filled: true,
              tooltip: 'About this map',
              onPressed: () => showMapMetadata(context),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Map metadata, as every map should carry: reference system, source, date,
/// accuracy and how to read the symbols.
void showMapMetadata(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) {
      final p = SvPalette.of(sheet);
      Widget row(String k, String v) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 110, child: Text(k, style: SvType.bodySm(p.muted))),
              Expanded(child: Text(v, style: SvType.bodySm(p.ink))),
            ]),
          );
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SvEyebrow('About this map'),
            const Gap(6),
            Text('LPU campus utility schematic', style: SvType.heading2(p.ink)),
            const Gap(16),
            row('Reference', 'Local schematic grid in metres, anchored at ${lpuAnchor.format(decimals: 4)} (${GeoCrs.wgs84}). Distances in the app are geodesic.'),
            row('Source', 'SAMANVAY sample dataset for the LPU campus — synthetic records, not a survey.'),
            row('Date', 'Generated on this device (${fmtDate(DateTime.now())}). Works and reports you add are saved on this device.'),
            row('Accuracy', 'Illustrative only. Positions are not surveyed and the campus layout is schematic.'),
            row('Solid line', 'Sample record.'),
            row('Dashed line', 'Estimated or pending verification — field-verify before digging.'),
            row('Empty area', 'No data recorded. It does not mean nothing is buried.'),
            const Gap(6),
            Text('Not for excavation or construction decisions.', style: SvType.bodySm(SvColors.error)),
          ]),
        ),
      );
    },
  );
}
