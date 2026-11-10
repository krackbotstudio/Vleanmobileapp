import 'package:flutter/material.dart';

ThemeData customerTheme(bool dark) {
  final foreground = dark ? Colors.white : const Color(0xFF0B0B0B);
  final canvas = dark ? const Color(0xFF07070A) : const Color(0xFFF0F1F5);
  final surface = dark ? const Color(0xFF1A1C2A) : Colors.white;
  final border = foreground.withValues(alpha: dark ? .12 : .10);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: foreground,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: foreground,
        onPrimary: dark ? const Color(0xFF0B0B0B) : Colors.white,
        surface: surface,
        onSurface: foreground,
        outline: border,
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
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: foreground),
      bodySmall: TextStyle(
        fontSize: 12,
        color: foreground.withValues(alpha: dark ? .58 : .50),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: foreground.withValues(alpha: dark ? .08 : .03),
      hintStyle: TextStyle(
        color: foreground.withValues(alpha: .55),
        fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: foreground),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        backgroundColor: foreground,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        foregroundColor: foreground,
        side: BorderSide(color: foreground.withValues(alpha: .28)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: foreground),
    ),
    dividerColor: border,
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? foreground
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(scheme.onPrimary),
    ),
  );
}

class PageHeading extends StatelessWidget {
  final String title, subtitle;
  const PageHeading(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .65),
        ),
      ),
      const SizedBox(height: 16),
    ],
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
