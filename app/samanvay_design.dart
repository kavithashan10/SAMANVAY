import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SAMANVAY design system — "field journal" direction.
///
/// Warm-paper canvas, a thin high-contrast serif for statements, a neutral
/// grotesque for reading, earth-tone accents reserved for data and bands, and
/// one action blue used only for the primary call to action on a view.
class SvColors {
  SvColors._();

  // Brand & accent
  static const primary = Color(0xFF2A72DE); // action blue — primary CTA only
  static const onPrimary = Color(0xFFFFFFFF);
  static const stone = Color(0xFF4A4741); // workhorse warm neutral
  static const onStone = Color(0xFFF7F1E8);
  static const clay = Color(0xFF6B443D);
  static const espresso = Color(0xFF39221E);
  static const gold = Color(0xFFAF751B);
  static const ochre = Color(0xFFBC924C);
  static const goldSoft = Color(0xFFDDAA61);
  static const goldPale = Color(0xFFDDBE78);
  static const goldDeep = Color(0xFF684D07);
  static const forest = Color(0xFF224228);
  static const olive = Color(0xFF5C6F5D);
  static const sage = Color(0xFF849671);
  static const sageMute = Color(0xFF7B886D);
  static const sagePale = Color(0xFFCED4B8);

  // Surfaces
  static const canvas = Color(0xFFF7F1E8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceGrey = Color(0xFFECECEC);
  static const silver = Color(0xFFCCCAC7);
  static const inkBand = Color(0xFF000000);
  static const inkBandSoft = Color(0xFF19191C);
  static const hairline = Color(0xFFE1DCD3);

  // Text
  static const ink = Color(0xFF1C1B1A);
  static const ash = Color(0xFF838280);
  static const mute = Color(0xFFA8A5A0);
  static const onDark = Color(0xFFFFFFFF);

  // Semantic
  static const error = Color(0xFFE33A22);
}

/// Semantic palette that flips between the cream world and the ink world.
@immutable
class SvPalette extends ThemeExtension<SvPalette> {
  const SvPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.hairline,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.neutral,
    required this.onNeutral,
    required this.isDark,
  });

  final Color canvas; // page background
  final Color surface; // elevated card
  final Color surfaceAlt; // quiet fill (chips, inputs)
  final Color hairline;
  final Color ink; // primary text
  final Color inkSoft; // secondary text
  final Color muted; // captions
  final Color neutral; // secondary pill fill
  final Color onNeutral;
  final bool isDark;

  static const light = SvPalette(
    canvas: SvColors.canvas,
    surface: SvColors.surface,
    surfaceAlt: Color(0xFFEFE8DC),
    hairline: SvColors.hairline,
    ink: SvColors.ink,
    inkSoft: SvColors.stone,
    muted: SvColors.ash,
    neutral: SvColors.stone,
    onNeutral: SvColors.onStone,
    isDark: false,
  );

  static const dark = SvPalette(
    canvas: SvColors.inkBandSoft,
    surface: Color(0xFF232226),
    surfaceAlt: Color(0xFF2C2A2E),
    hairline: Color(0xFF34312F),
    ink: SvColors.canvas,
    inkSoft: Color(0xFFD9D2C6),
    muted: SvColors.mute,
    neutral: SvColors.canvas,
    onNeutral: SvColors.stone,
    isDark: true,
  );

  /// Earth-tone accents are dark; lift them so they stay legible on ink.
  Color accent(Color c) => isDark ? Color.lerp(c, Colors.white, .45)! : c;

  static SvPalette of(BuildContext context) =>
      Theme.of(context).extension<SvPalette>() ?? light;

  @override
  SvPalette copyWith() => this;

  @override
  SvPalette lerp(ThemeExtension<SvPalette>? other, double t) =>
      other is SvPalette && t > .5 ? other : this;
}

class SvSpace {
  SvSpace._();
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const section = 48.0;
}

class SvRadius {
  SvRadius._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 24.0;
  static const xl = 40.0;
  static const full = 9999.0;
}

/// Type scale tuned for phones: serif for feeling, sans for facts.
class SvType {
  SvType._();

  static TextStyle display(Color c) => GoogleFonts.fraunces(
      fontSize: 46, fontWeight: FontWeight.w300, height: 1.05, color: c, letterSpacing: -.8);
  static TextStyle heading1(Color c) => GoogleFonts.fraunces(
      fontSize: 34, fontWeight: FontWeight.w300, height: 1.1, color: c, letterSpacing: -.4);
  static TextStyle heading2(Color c) => GoogleFonts.fraunces(
      fontSize: 27, fontWeight: FontWeight.w300, height: 1.15, color: c);
  static TextStyle lead(Color c) => GoogleFonts.fraunces(
      fontSize: 19, fontWeight: FontWeight.w300, height: 1.3, color: c);
  static TextStyle heading3(Color c) =>
      GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w400, height: 1.2, color: c);
  static TextStyle title(Color c) =>
      GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w600, height: 1.25, color: c);
  static TextStyle bodyLg(Color c) =>
      GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w400, height: 1.5, color: c);
  static TextStyle body(Color c) =>
      GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5, color: c);
  static TextStyle bodySm(Color c) =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45, color: c);
  static TextStyle button(Color c) =>
      GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, height: 1, color: c);
  static TextStyle ui(Color c) =>
      GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, height: 1.35, color: c);
  static TextStyle caption(Color c) =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4, color: c);
  static TextStyle eyebrow(Color c) => GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w700, height: 1.2, color: c, letterSpacing: 1.3);
}

ThemeData samanvayFieldTheme({required bool dark}) {
  final p = dark ? SvPalette.dark : SvPalette.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: p.canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: SvColors.stone,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: SvColors.primary,
      onPrimary: SvColors.onPrimary,
      secondary: p.neutral,
      onSecondary: p.onNeutral,
      surface: p.canvas,
      onSurface: p.ink,
      error: SvColors.error,
      outline: p.hairline,
    ),
    extensions: [p],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: GoogleFonts.inter().fontFamily,
      bodyColor: p.ink,
      displayColor: p.ink,
    ),
    dividerColor: p.hairline,
    appBarTheme: AppBarTheme(
      backgroundColor: p.canvas,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.canvas,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.surfaceAlt,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(SvType.caption(p.inkSoft)),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? p.ink : p.muted,
          )),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.canvas,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.hairline,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.canvas,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SvRadius.lg)),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SvRadius.xs)),
      side: BorderSide(color: p.inkSoft, width: 1.4),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? SvColors.forest : Colors.transparent,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      hintStyle: SvType.bodySm(p.muted),
      labelStyle: SvType.bodySm(p.inkSoft),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SvRadius.md),
        borderSide: BorderSide(color: p.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SvRadius.md),
        borderSide: BorderSide(color: p.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SvRadius.md),
        borderSide: BorderSide(color: p.inkSoft, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SvRadius.md),
        borderSide: const BorderSide(color: SvColors.error),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.isDark ? SvColors.canvas : SvColors.inkBandSoft,
      contentTextStyle: SvType.bodySm(p.isDark ? SvColors.ink : SvColors.canvas),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SvRadius.md)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Components
// ---------------------------------------------------------------------------

enum SvButtonKind { primary, secondary, outline, onDark }

/// Fully rounded pill button. Use [SvButtonKind.primary] once per view.
class SvPillButton extends StatelessWidget {
  const SvPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = SvButtonKind.secondary,
    this.icon,
    this.expand = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final SvButtonKind kind;
  final IconData? icon;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final (Color bg, Color fg, BorderSide side) = switch (kind) {
      SvButtonKind.primary => (SvColors.primary, SvColors.onPrimary, BorderSide.none),
      SvButtonKind.secondary => (p.neutral, p.onNeutral, BorderSide.none),
      SvButtonKind.outline => (Colors.transparent, p.inkSoft, BorderSide(color: p.inkSoft)),
      SvButtonKind.onDark => (SvColors.canvas, SvColors.stone, BorderSide.none),
    };
    final disabled = onPressed == null;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: compact ? 16 : 18, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: SvType.button(fg).copyWith(fontSize: compact ? 13 : 15)),
        ),
      ],
    );
    return Opacity(
      opacity: disabled ? .45 : 1,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: side),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 38 : 48, minWidth: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24, vertical: 10),
              child: Center(widthFactor: expand ? null : 1, heightFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular icon control (carousel arrows, overlay affordances).
class SvIconCircle extends StatelessWidget {
  const SvIconCircle({super.key, required this.icon, this.onPressed, this.tooltip, this.filled = false});
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final button = Material(
      color: filled ? p.surface : Colors.transparent,
      shape: CircleBorder(side: BorderSide(color: filled ? p.hairline : p.inkSoft.withValues(alpha: .5))),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: p.ink)),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class SvEyebrow extends StatelessWidget {
  const SvEyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: SvType.eyebrow(color ?? SvPalette.of(context).inkSoft));
}

/// Eyebrow + serif title, the standard section opener.
class SvSectionHeader extends StatelessWidget {
  const SvSectionHeader({super.key, required this.eyebrow, required this.title, this.trailing, this.lead});
  final String eyebrow;
  final String title;
  final String? lead;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SvEyebrow(eyebrow),
            const SizedBox(height: SvSpace.xs),
            Text(title, style: SvType.heading2(p.ink)),
          ]),
        ),
        ?trailing,
      ]),
      if (lead != null) ...[
        const SizedBox(height: SvSpace.xs),
        Text(lead!, style: SvType.bodySm(p.inkSoft)),
      ],
    ]);
  }
}

/// Soft-cornered content card on the canvas.
class SvCard extends StatelessWidget {
  const SvCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.onTap,
    this.elevated = false,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool elevated;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final radius = BorderRadius.circular(SvRadius.lg);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: const Color(0xFF39221E).withValues(alpha: p.isDark ? .35 : .08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: color ?? p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: borderColor ?? p.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Colour-blocked accent band (clay / forest / gold families).
class SvBand extends StatelessWidget {
  const SvBand({super.key, required this.child, this.color = SvColors.clay, this.padding = const EdgeInsets.all(24)});
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(SvRadius.lg)),
        child: child,
      );
}

/// Circular stat readout.
class SvStatBadge extends StatelessWidget {
  const SvStatBadge({super.key, required this.value, required this.label, this.size = 96, this.accent});
  final String value;
  final String label;
  final double size;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent == null ? p.inkSoft.withValues(alpha: .35) : p.accent(accent!), width: 1.5),
        ),
        child: Text(value, style: SvType.heading3(accent == null ? p.inkSoft : p.accent(accent!)).copyWith(fontSize: size * .3)),
      ),
      const SizedBox(height: SvSpace.xs),
      SizedBox(
        width: size + 24,
        child: Text(label, textAlign: TextAlign.center, style: SvType.caption(p.muted)),
      ),
    ]);
  }
}

/// Horizontal pill selector; the selected pill gets a silver 2px border.
class SvPillTabs<T> extends StatelessWidget {
  const SvPillTabs({super.key, required this.options, required this.selected, required this.onChanged, this.label});
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T)? label;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final (value, text) in options)
          Padding(
            padding: const EdgeInsets.only(right: SvSpace.xs),
            child: Material(
              color: value == selected ? p.surface : Colors.transparent,
              shape: StadiumBorder(
                side: BorderSide(
                  color: value == selected ? (p.isDark ? p.inkSoft : SvColors.silver) : p.hairline,
                  width: value == selected ? 2 : 1,
                ),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onChanged(value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(text,
                      style: SvType.ui(value == selected ? p.ink : p.inkSoft)
                          .copyWith(fontWeight: value == selected ? FontWeight.w600 : FontWeight.w500)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Small tinted pill used for statuses and data-integrity labels.
class SvTag extends StatelessWidget {
  const SvTag(this.text, {super.key, required this.color, this.icon, this.solid = false});
  final String text;
  final Color color;
  final IconData? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final fg = solid ? SvColors.canvas : (p.isDark ? Color.lerp(color, Colors.white, .45)! : color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: p.isDark ? .22 : .12),
        borderRadius: BorderRadius.circular(SvRadius.full),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 5)],
        Text(text, style: SvType.caption(fg).copyWith(fontWeight: FontWeight.w600, height: 1.1)),
      ]),
    );
  }
}

class SvHairline extends StatelessWidget {
  const SvHairline({super.key, this.vertical = SvSpace.md});
  final double vertical;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: vertical),
        child: Divider(height: 1, thickness: 1, color: SvPalette.of(context).hairline),
      );
}

/// Thin progress ring with a fraction label in the middle.
class SvProgressRing extends StatelessWidget {
  const SvProgressRing({super.key, required this.done, required this.total, this.size = 44, this.color});
  final int done;
  final int total;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    final value = total == 0 ? 0.0 : done / total;
    final c = color ?? (value >= 1 ? SvColors.forest : SvColors.gold);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: 3,
            backgroundColor: p.hairline,
            valueColor: AlwaysStoppedAnimation(p.isDark ? Color.lerp(c, Colors.white, .3)! : c),
          ),
        ),
        Text('$done/$total', style: SvType.caption(p.ink).copyWith(fontSize: size * .25, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Honest empty state.
class SvEmptyState extends StatelessWidget {
  const SvEmptyState({super.key, required this.title, required this.message, this.icon = Icons.inbox_outlined});
  final String title;
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final p = SvPalette.of(context);
    return SvCard(
      color: p.surfaceAlt,
      child: Column(children: [
        Icon(icon, size: 32, color: p.muted),
        const SizedBox(height: SvSpace.sm),
        Text(title, style: SvType.title(p.ink), textAlign: TextAlign.center),
        const SizedBox(height: SvSpace.xxs),
        Text(message, style: SvType.bodySm(p.inkSoft), textAlign: TextAlign.center),
      ]),
    );
  }
}
