import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../samanvay_design.dart';

/// The one place the SAMANVAY logo is referenced. To change the logo, replace
/// app/assets/brand/samanvay_logo.svg (same name) or point this at a new asset.
const kBrandLogoAsset = 'assets/brand/samanvay_logo.svg';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(kBrandLogoAsset, width: size, height: size, semanticsLabel: 'SAMANVAY');
}

class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, required this.subtitle});
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Row(children: [
      const BrandMark(size: 32),
      const SizedBox(width: 12),
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('SAMANVAY', maxLines: 1, style: SvType.ui(p.inkSoft).copyWith(fontWeight: FontWeight.w700, letterSpacing: 2.4)),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: SvType.caption(p.muted)),
        ]),
      ),
    ]);
  }
}
