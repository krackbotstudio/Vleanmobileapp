import 'dart:ui';

import 'package:flutter/material.dart';

/// VClean badge purple, sampled from the brand mark.
abstract final class BrandColors {
  static const purple = Color(0xFF5C2786);
  static const purpleDeep = Color(0xFF3D1468);
  static const purpleBright = Color(0xFF7A45B0);
  static const purpleSoft = Color(0xFFE7D4F6);
  static const mist = Color(0xFFF6F1FB);
  static const ink = Color(0xFF1A1024);
  static const sheetLight = Color(0xFFF4F1FA);
  static const sheetDark = Color(0xFF140A1C);
  static const muted = Color(0xFF6B6880);
  static const mutedDark = Color(0xFFA9A3BC);
  static const danger = Color(0xFFD64550);
  static const logo = 'assets/vclean-logo.png';
  static const logoOnPurple = 'assets/vclean-badge-purple.png';
}

/// Neumorphic palette: every raised surface shares the page colour and is
/// shaped only by a light shadow top-left and a dark shadow bottom-right.
abstract final class Neu {
  static const light = Color(0xFFEDEDF6);
  static const dark = Color(0xFF1C1229);
  static const _lightShade = Color(0xFFC4C5DC);
  static const _darkHighlight = Color(0xFF2C1F40);

  static Color base(bool dark) => dark ? Neu.dark : Neu.light;

  static List<BoxShadow> raised(bool dark, {double depth = 6}) => [
    BoxShadow(
      color: dark ? _darkHighlight : Colors.white,
      offset: Offset(-depth, -depth),
      blurRadius: depth * 2.4,
    ),
    BoxShadow(
      color: dark ? Colors.black.withValues(alpha: .6) : _lightShade,
      offset: Offset(depth, depth),
      blurRadius: depth * 2.4,
    ),
  ];
}

BoxDecoration neuRaised(
  bool dark, {
  double radius = 20,
  BoxShape shape = BoxShape.rectangle,
  double depth = 6,
}) => BoxDecoration(
  color: Neu.base(dark),
  shape: shape,
  borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
  boxShadow: Neu.raised(dark, depth: depth),
);

/// Pressed-in look for fields, approximated with a shaded fill and rim.
BoxDecoration neuPressed(bool dark, {double radius = 16}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? const [Color(0xFF140C1F), Color(0xFF241835)]
        : const [Color(0xFFDDDEEC), Color(0xFFF6F6FB)],
  ),
  border: Border.all(
    color: dark ? Colors.white.withValues(alpha: .05) : Colors.white,
  ),
);

/// Soft diagonal wash used behind sign-in and every signed-in page.
BoxDecoration pageBackdrop(bool dark) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? const [Color(0xFF261841), Neu.dark, Color(0xFF160D21)]
        : const [Color(0xFFF4F2FC), Neu.light, Color(0xFFE8E5F6)],
  ),
);

const brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF8B5CF6), BrandColors.purple],
);

/// Purple gradient surface with the glow used by the sign-in CTA.
BoxDecoration brandRaised({
  double radius = 18,
  BoxShape shape = BoxShape.rectangle,
}) => BoxDecoration(
  gradient: brandGradient,
  shape: shape,
  borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
  boxShadow: [
    BoxShadow(
      color: BrandColors.purple.withValues(alpha: .36),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ],
);

/// Borderless input decoration for fields placed inside [NeuField].
const neuBareField = InputDecoration(
  filled: false,
  isDense: true,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  contentPadding: EdgeInsets.symmetric(vertical: 18),
);

Color mutedText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? BrandColors.mutedDark
    : BrandColors.muted;

Widget _gradientButtonLayer(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) {
  final disabled = states.contains(WidgetState.disabled);
  final pressed = states.contains(WidgetState.pressed);
  final dark = Theme.of(context).brightness == Brightness.dark;
  return AnimatedOpacity(
    opacity: disabled ? .55 : 1,
    duration: const Duration(milliseconds: 200),
    child: DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        gradient: brandGradient,
        shadows: [
          BoxShadow(
            color: BrandColors.purple.withValues(alpha: pressed ? .26 : .38),
            blurRadius: pressed ? 10 : 20,
            offset: Offset(0, pressed ? 4 : 9),
          ),
          if (!dark)
            const BoxShadow(
              color: Colors.white,
              blurRadius: 10,
              offset: Offset(-4, -4),
            ),
        ],
      ),
      child: child,
    ),
  );
}

Widget _raisedButtonLayer(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) {
  final disabled = states.contains(WidgetState.disabled);
  final pressed = states.contains(WidgetState.pressed);
  final dark = Theme.of(context).brightness == Brightness.dark;
  return AnimatedOpacity(
    opacity: disabled ? .55 : 1,
    duration: const Duration(milliseconds: 200),
    child: DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: Neu.base(dark),
        shadows: Neu.raised(dark, depth: pressed ? 2 : 5),
      ),
      child: child,
    ),
  );
}

ThemeData customerTheme(bool dark) {
  final foreground = dark ? Colors.white : BrandColors.ink;
  final muted = dark ? BrandColors.mutedDark : BrandColors.muted;
  final canvas = Neu.base(dark);
  final surface = Neu.base(dark);
  final primary = dark ? const Color(0xFFC9A6E8) : BrandColors.purple;
  final onPrimary = dark ? const Color(0xFF1A0B28) : Colors.white;
  final border = dark
      ? Colors.white.withValues(alpha: .08)
      : const Color(0xFFDCDDEA);
  final field = dark ? const Color(0xFF170E22) : const Color(0xFFE6E6F1);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: BrandColors.purple,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: primary,
        onPrimary: onPrimary,
        surface: surface,
        onSurface: foreground,
        outline: border,
        error: dark ? const Color(0xFFFF8A93) : BrandColors.danger,
      );
  return ThemeData(
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    fontFamily: 'Roboto',
    textTheme: TextTheme(
      headlineSmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -.4,
        color: foreground,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -.3,
        color: foreground,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: foreground),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: muted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
      titleTextStyle: TextStyle(
        color: foreground,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -.3,
      ),
    ),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) => Container(
        width: 40,
        height: 40,
        decoration: neuRaised(dark, shape: BoxShape.circle, depth: 4),
        child: Icon(Icons.arrow_back_rounded, size: 20, color: foreground),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: field,
      hintStyle: TextStyle(color: muted.withValues(alpha: .8), fontSize: 14),
      labelStyle: TextStyle(color: muted, fontSize: 14),
      floatingLabelStyle: TextStyle(
        color: primary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: dark ? Colors.white.withValues(alpha: .05) : Colors.white,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      // Same glowing gradient pill as the sign-in "Send OTP" button.
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        backgroundBuilder: _gradientButtonLayer,
      ),
    ),
    // Raised neumorphic pill, like "Continue as guest" on sign-in.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        foregroundColor: primary,
        disabledForegroundColor: primary,
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        elevation: 0,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        backgroundBuilder: _raisedButtonLayer,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF2C1F40) : BrandColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : (dark ? const Color(0xFF6B6080) : Colors.white),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? BrandColors.purpleBright
            : (dark ? const Color(0xFF170E22) : const Color(0xFFDDDEEC)),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      elevation: 3,
      pressElevation: 1,
      shadowColor: dark ? Colors.black : const Color(0xFFB8BAD4),
      side: BorderSide(
        color: dark ? Colors.white.withValues(alpha: .06) : Colors.white,
      ),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    dividerColor: border,
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? primary
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(onPrimary),
    ),
  );
}

/// Purple wash used behind splash, welcome, and sign-in.
class BrandBackdrop extends StatelessWidget {
  final Widget? child;
  const BrandBackdrop({super.key, this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF4A1B78),
          Color(0xFF6A35A8),
          Color(0xFFC9A6E4),
          BrandColors.mist,
        ],
        stops: [0, .38, .72, 1],
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const Positioned(
          top: -70,
          right: -30,
          child: _GlowOrb(240, Color(0x55FFFFFF)),
        ),
        const Positioned(
          top: 220,
          left: -80,
          child: _GlowOrb(200, Color(0x33FFFFFF)),
        ),
        const Positioned(
          bottom: 80,
          right: -40,
          child: _GlowOrb(160, Color(0x44E7D4F6)),
        ),
        ?child,
      ],
    ),
  );
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowOrb(this.size, this.color);

  @override
  Widget build(BuildContext context) => ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    ),
  );
}

/// Frosted surface. Sits on [BrandBackdrop] or the app gradient.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color =
        tint ?? (dark ? const Color(0xCC241433) : const Color(0xD9FFFFFF));
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: dark ? .16 : .72),
            ),
            boxShadow: [
              BoxShadow(
                color: BrandColors.purple.withValues(alpha: dark ? .28 : .12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class PageHeading extends StatelessWidget {
  final String title, subtitle;
  const PageHeading(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      Text(
        subtitle,
        style: TextStyle(fontSize: 14, height: 1.4, color: mutedText(context)),
      ),
      const SizedBox(height: 20),
    ],
  );
}

/// Title row for a tab or pushed page: login-style heading, muted subtitle
/// and optional round actions on the right.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const ScreenHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.actions = const [],
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            for (final action in actions) ...[
              const SizedBox(width: 10),
              action,
            ],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: mutedText(context),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Pressed-in round well holding an icon, as on the sign-in fields.
class IconChip extends StatelessWidget {
  final Widget child;
  final double size;
  const IconChip(this.child, {super.key, this.size = 38});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: neuPressed(
      Theme.of(context).brightness == Brightness.dark,
      radius: size / 2,
    ),
    child: child,
  );
}

/// Raised input shell matching the sign-in phone field. Pair the field
/// inside with [neuBareField] so it draws no border of its own.
class NeuField extends StatelessWidget {
  final Widget child;
  final Widget? leading;
  final EdgeInsetsGeometry margin;
  const NeuField({
    super.key,
    required this.child,
    this.leading,
    this.margin = EdgeInsets.zero,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: Container(
      padding: EdgeInsets.fromLTRB(leading == null ? 18 : 10, 0, 16, 0),
      decoration: neuRaised(
        Theme.of(context).brightness == Brightness.dark,
        radius: 20,
        depth: 5,
      ),
      child: leading == null
          ? child
          : Row(
              children: [
                leading!,
                const SizedBox(width: 12),
                Expanded(child: child),
              ],
            ),
    ),
  );
}

/// Round raised icon button; [accent] gives it the brand gradient.
class NeuIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool accent;
  final double size;
  const NeuIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accent = false,
    this.size = 44,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedOpacity(
      opacity: onPressed == null ? .55 : 1,
      duration: const Duration(milliseconds: 200),
      child: DecoratedBox(
        decoration: accent
            ? brandRaised(shape: BoxShape.circle)
            : neuRaised(dark, shape: BoxShape.circle, depth: 4),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 21),
          style: IconButton.styleFrom(
            foregroundColor: accent
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
            disabledForegroundColor: Theme.of(context).colorScheme.onSurface,
            fixedSize: Size(size, size),
          ),
        ),
      ),
    );
  }
}

/// Selectable tile: raised when idle, brand gradient when chosen.
class NeuOption extends StatelessWidget {
  final bool selected;
  final VoidCallback? onTap;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  const NeuOption({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.radius = 18,
    this.padding = const EdgeInsets.all(14),
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = selected
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedOpacity(
        opacity: onTap == null ? .55 : 1,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: selected
              ? brandRaised(radius: radius)
              : neuRaised(dark, radius: radius, depth: 4),
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: padding,
                child: IconTheme.merge(
                  data: IconThemeData(color: ink),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: ink),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scaffold for pushed pages, painted with the sign-in backdrop.
class NeuPage extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget body;
  const NeuPage({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: pageBackdrop(Theme.of(context).brightness == Brightness.dark),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title),
        titleSpacing: 4,
        actions: [...actions, const SizedBox(width: 12)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: body,
        ),
      ),
    ),
  );
}

class PreviewNote extends StatelessWidget {
  final String text;
  const PreviewNote({
    super.key,
    this.text =
        'Preview only · sample prices and slots. No pickup will be scheduled.',
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
    ),
  );
}

String serviceAsset(String id) =>
    'assets/service-icons/${switch (id) {
      'daily' => 'wash-and-fold',
      'pressed' => 'wash-and-iron',
      'delicate' => 'dry-cleaning',
      'shoes' => 'shoe-cleaning',
      'iron' => 'steam-iron',
      _ => 'home-linen',
    }}.png';

class ServiceArt extends StatelessWidget {
  final String id;
  final double size;
  const ServiceArt(this.id, {super.key, this.size = 96});
  @override
  Widget build(BuildContext context) => Image.asset(
    serviceAsset(id),
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

void showDocument(BuildContext context, String title, String body) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  body.isEmpty
                      ? 'This document is temporarily unavailable. Please try again after the connection is restored.'
                      : body,
                  style: const TextStyle(height: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ),
  );
}
