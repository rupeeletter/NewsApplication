import 'package:flutter/material.dart';

/// Custom outlined info icon (lowercase "i" in circle)
class InfoIcon extends StatelessWidget {
  final Color color;
  final double size;

  const InfoIcon({
    super.key,
    this.color = const Color(0xFF5A5D72),
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _InfoIconPainter(color: color),
    );
  }
}

class _InfoIconPainter extends CustomPainter {
  final Color color;

  _InfoIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw circle
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 1,
      paint,
    );

    // Draw lowercase "i"
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'i',
        style: TextStyle(
          color: color,
          fontSize: size.width * 0.6,
          fontWeight: FontWeight.w600,
          fontFamily: 'Arial',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom outlined wallet/document icon
class WalletIcon extends StatelessWidget {
  final Color color;
  final double size;

  const WalletIcon({
    super.key,
    this.color = const Color(0xFF5A5D72),
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _WalletIconPainter(color: color),
    );
  }
}

class _WalletIconPainter extends CustomPainter {
  final Color color;

  _WalletIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Wallet/document outline
    final path = Path()
      ..moveTo(w * 0.15, h * 0.25)
      ..lineTo(w * 0.15, h * 0.85)
      ..lineTo(w * 0.85, h * 0.85)
      ..lineTo(w * 0.85, h * 0.25)
      ..lineTo(w * 0.15, h * 0.25);

    canvas.drawPath(path, paint);

    // Top flap
    final flapPath = Path()
      ..moveTo(w * 0.15, h * 0.25)
      ..lineTo(w * 0.5, h * 0.15)
      ..lineTo(w * 0.85, h * 0.25);

    canvas.drawPath(flapPath, paint);

    // Card slot
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.3, h * 0.45, w * 0.4, h * 0.25),
        const Radius.circular(4),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom outlined currency/money note icon
class CurrencyIcon extends StatelessWidget {
  final Color color;
  final double size;

  const CurrencyIcon({
    super.key,
    this.color = const Color(0xFF5A5D72),
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CurrencyIconPainter(color: color),
    );
  }
}

class _CurrencyIconPainter extends CustomPainter {
  final Color color;

  _CurrencyIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Money note rectangle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.1, h * 0.25, w * 0.8, h * 0.5),
        const Radius.circular(4),
      ),
      paint,
    );

    // Currency symbol (₹ or $)
    final textPainter = TextPainter(
      text: TextSpan(
        text: '₹',
        style: TextStyle(
          color: color,
          fontSize: size.width * 0.35,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );

    // Corner decorations (small circles)
    canvas.drawCircle(Offset(w * 0.2, h * 0.35), 2, paint..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(w * 0.8, h * 0.35), 2, paint);
    canvas.drawCircle(Offset(w * 0.2, h * 0.65), 2, paint);
    canvas.drawCircle(Offset(w * 0.8, h * 0.65), 2, paint);
    
    paint.style = PaintingStyle.stroke;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
