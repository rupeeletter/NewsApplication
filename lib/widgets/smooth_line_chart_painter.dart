import 'package:flutter/material.dart';

class SmoothLineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> chartData;

  SmoothLineChartPainter({
    required this.chartData,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty) return;

    final prices = chartData
        .map((e) => (e['value'] as num).toDouble())
        .toList();

    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);

    final range = (maxPrice - minPrice) == 0
        ? 1
        : (maxPrice - minPrice);

    final List<Offset> points = [];

    for (int i = 0; i < prices.length; i++) {
      final x = (i / (prices.length - 1)) * size.width;

      final y = size.height -
          ((prices[i] - minPrice) / range) * size.height;

      points.add(Offset(x, y));
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      final cp1 = Offset(
        p0.dx + (p1.dx - p0.dx) / 2,
        p0.dy,
      );

      final cp2 = Offset(
        p0.dx + (p1.dx - p0.dx) / 2,
        p1.dy,
      );

      path.cubicTo(
        cp1.dx,
        cp1.dy,
        cp2.dx,
        cp2.dy,
        p1.dx,
        p1.dy,
      );
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0x33007A5A),
          const Color(0x00007A5A),
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF007A5A)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant SmoothLineChartPainter oldDelegate) {
    return oldDelegate.chartData != chartData;
  }
}