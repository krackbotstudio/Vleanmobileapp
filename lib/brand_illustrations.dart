import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'appearance.dart';

/// Flat, rounded spot illustrations drawn in the brand palette: white and
/// lavender shapes, sparkles and a soft halo, made to sit on purple.
enum BrandArt { pickup, dryClean, steamIron }

class BrandIllustration extends StatelessWidget {
  final BrandArt art;
  const BrandIllustration(this.art, {super.key});

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: CustomPaint(painter: _BrandArtPainter(art)),
  );
}

class _BrandArtPainter extends CustomPainter {
  final BrandArt art;
  const _BrandArtPainter(this.art);

  static const _white = Colors.white;
  static const _lavender = BrandColors.purpleSoft;
  static final _ink = BrandColors.purple.withValues(alpha: .55);

  Paint fill(Color color) => Paint()
    ..color = color
    ..isAntiAlias = true;

  Paint stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw in a 100 × 100 space.
    final scale = math.min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate(
      (size.width - 100 * scale) / 2,
      (size.height - 100 * scale) / 2,
    );
    canvas.scale(scale);

    canvas.drawCircle(
      const Offset(50, 52),
      46,
      fill(_white.withValues(alpha: .12)),
    );
    canvas.drawCircle(
      const Offset(50, 52),
      36,
      fill(_white.withValues(alpha: .10)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 90), width: 62, height: 7),
      fill(Colors.black.withValues(alpha: .14)),
    );

    switch (art) {
      case BrandArt.pickup:
        pickup(canvas);
      case BrandArt.dryClean:
        dryClean(canvas);
      case BrandArt.steamIron:
        steamIron(canvas);
    }
    canvas.restore();
  }

  void sparkle(Canvas canvas, Offset c, double s, {double alpha = .95}) {
    final path = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
      ..close();
    canvas.drawPath(path, fill(_white.withValues(alpha: alpha)));
  }

  /// Basket of folded laundry with a location pin and speed lines.
  void pickup(Canvas canvas) {
    // Folded clothes peeking out of the basket.
    canvas.drawRRect(
      RRect.fromLTRBR(30, 24, 66, 40, const Radius.circular(6)),
      fill(_white),
    );
    canvas.drawLine(
      const Offset(36, 32),
      const Offset(60, 32),
      stroke(_lavender, 2),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(24, 36, 62, 52, const Radius.circular(6)),
      fill(_lavender),
    );

    // Basket body with weave.
    final body = Path()
      ..moveTo(18, 52)
      ..lineTo(82, 52)
      ..lineTo(74, 86)
      ..quadraticBezierTo(73, 88, 70, 88)
      ..lineTo(30, 88)
      ..quadraticBezierTo(27, 88, 26, 86)
      ..close();
    canvas.drawPath(body, fill(_white));
    final weave = stroke(_ink.withValues(alpha: .28), 2.2);
    canvas.drawLine(const Offset(22, 66), const Offset(78, 66), weave);
    canvas.drawLine(const Offset(25, 77), const Offset(75, 77), weave);
    for (final x in [38.0, 50.0, 62.0]) {
      canvas.drawLine(Offset(x, 56), Offset(x + (x - 50) * .12, 85), weave);
    }
    canvas.drawRRect(
      RRect.fromLTRBR(14, 47, 86, 56, const Radius.circular(4.5)),
      fill(_lavender),
    );

    // Location pin.
    final pin = Path()
      ..addOval(Rect.fromCircle(center: const Offset(80, 22), radius: 10))
      ..moveTo(71.5, 27)
      ..lineTo(88.5, 27)
      ..lineTo(80, 40)
      ..close();
    canvas.drawPath(pin, fill(_white));
    canvas.drawCircle(const Offset(80, 22), 4, fill(BrandColors.purple));

    // Speed lines.
    final speed = stroke(_white.withValues(alpha: .7), 3);
    canvas.drawLine(const Offset(4, 62), const Offset(11, 62), speed);
    canvas.drawLine(const Offset(1, 71), const Offset(12, 71), speed);
    canvas.drawLine(const Offset(5, 80), const Offset(13, 80), speed);

    sparkle(canvas, const Offset(16, 26), 5);
    sparkle(canvas, const Offset(92, 56), 3.5, alpha: .8);
  }

  /// Shirt on a hanger with sparkles.
  void dryClean(Canvas canvas) {
    final wire = stroke(_white, 3);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(50, 13), radius: 4.5),
      math.pi / 2,
      -1.4 * math.pi,
      false,
      wire,
    );
    canvas.drawLine(const Offset(50, 17.5), const Offset(50, 24), wire);
    canvas.drawPath(
      Path()
        ..moveTo(50, 24)
        ..lineTo(23, 36)
        ..moveTo(50, 24)
        ..lineTo(77, 36),
      wire,
    );

    final shirt = Path()
      ..moveTo(40, 31)
      ..lineTo(26, 35)
      ..lineTo(13, 52)
      ..lineTo(23, 59)
      ..lineTo(29, 52)
      ..lineTo(29, 85)
      ..quadraticBezierTo(29, 88, 32, 88)
      ..lineTo(68, 88)
      ..quadraticBezierTo(71, 88, 71, 85)
      ..lineTo(71, 52)
      ..lineTo(77, 59)
      ..lineTo(87, 52)
      ..lineTo(74, 35)
      ..lineTo(60, 31)
      ..quadraticBezierTo(50, 40, 40, 31)
      ..close();
    canvas.drawPath(shirt, fill(_white));

    // Cuffs, collar, placket, buttons and pocket.
    final cuff = stroke(_lavender, 3);
    canvas.drawLine(const Offset(14.5, 50.5), const Offset(22.5, 56), cuff);
    canvas.drawLine(const Offset(85.5, 50.5), const Offset(77.5, 56), cuff);
    final collar = fill(_lavender);
    canvas.drawPath(
      Path()
        ..moveTo(40, 31)
        ..lineTo(50, 41)
        ..lineTo(41, 44)
        ..close(),
      collar,
    );
    canvas.drawPath(
      Path()
        ..moveTo(60, 31)
        ..lineTo(50, 41)
        ..lineTo(59, 44)
        ..close(),
      collar,
    );
    canvas.drawLine(
      const Offset(50, 42),
      const Offset(50, 87),
      stroke(_lavender, 2),
    );
    for (final y in [52.0, 63.0, 74.0]) {
      canvas.drawCircle(Offset(50, y), 1.8, fill(_ink));
    }
    canvas.drawRRect(
      RRect.fromLTRBR(57, 50, 66, 59, const Radius.circular(2)),
      fill(_lavender),
    );

    sparkle(canvas, const Offset(15, 26), 6);
    sparkle(canvas, const Offset(86, 22), 4.5, alpha: .85);
    sparkle(canvas, const Offset(90, 74), 3.5, alpha: .7);
  }

  /// Steam iron with rising steam.
  void steamIron(Canvas canvas) {
    // Steam curls rising from the nose.
    final steam = stroke(_white.withValues(alpha: .8), 3);
    for (final x in [18.0, 28.0, 38.0]) {
      final top = x == 28 ? 14.0 : 20.0;
      canvas.drawPath(
        Path()
          ..moveTo(x, 46)
          ..cubicTo(x - 6, 40, x + 6, 33, x, top + 5)
          ..quadraticBezierTo(x - 2, top + 1, x, top),
        steam,
      );
    }

    // Open loop handle, clearly separate from the body.
    canvas.drawPath(
      Path()
        ..moveTo(50, 55)
        ..lineTo(54, 39)
        ..quadraticBezierTo(55.5, 34, 61, 34)
        ..lineTo(78, 34)
        ..quadraticBezierTo(84, 34, 84, 40)
        ..lineTo(84, 55),
      stroke(_white, 6),
    );

    // Body with a pointed nose, and the soleplate.
    final body = Path()
      ..moveTo(8, 76)
      ..quadraticBezierTo(16, 57, 44, 54)
      ..lineTo(81, 54)
      ..quadraticBezierTo(90, 54, 90, 63)
      ..lineTo(90, 76)
      ..close();
    canvas.drawPath(body, fill(_white));
    canvas.drawRRect(
      RRect.fromLTRBR(6, 73, 92, 82, const Radius.circular(4.5)),
      fill(_lavender),
    );
    for (final x in [30.0, 44.0, 58.0, 72.0]) {
      canvas.drawCircle(Offset(x, 77.5), 1.6, fill(_ink));
    }

    // Temperature dial.
    canvas.drawCircle(const Offset(72, 64), 5.5, fill(_lavender));
    canvas.drawLine(
      const Offset(72, 64),
      const Offset(75, 61),
      stroke(BrandColors.purple, 2),
    );

    sparkle(canvas, const Offset(64, 18), 5.5);
    sparkle(canvas, const Offset(93, 46), 3.5, alpha: .75);
  }

  @override
  bool shouldRepaint(_BrandArtPainter old) => old.art != art;
}
