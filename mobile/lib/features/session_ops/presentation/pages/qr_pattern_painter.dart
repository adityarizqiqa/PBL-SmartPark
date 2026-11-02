part of 'check_in_page.dart';

class _QrPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.spPrimary
      ..style = PaintingStyle.fill;

    final cellW = size.width / 21;
    final cellH = size.height / 21;

    void drawBox(int col, int row, int w, int h) {
      canvas.drawRect(
        Rect.fromLTWH(col * cellW, row * cellH, w * cellW, h * cellH),
        paint,
      );
    }

    // Corner Finder Patterns
    // Top-left
    drawBox(0, 0, 7, 7);
    // Top-right
    drawBox(14, 0, 7, 7);
    // Bottom-left
    drawBox(0, 14, 7, 7);

    // Inner clearings & centers
    final clearPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(1 * cellW, 1 * cellH, 5 * cellW, 5 * cellH), clearPaint);
    canvas.drawRect(Rect.fromLTWH(15 * cellW, 1 * cellH, 5 * cellW, 5 * cellH), clearPaint);
    canvas.drawRect(Rect.fromLTWH(1 * cellW, 15 * cellH, 5 * cellW, 5 * cellH), clearPaint);

    drawBox(2, 2, 3, 3);
    drawBox(16, 2, 3, 3);
    drawBox(2, 16, 3, 3);

    // Some simulated QR data points
    drawBox(8, 2, 2, 1);
    drawBox(11, 2, 1, 2);
    drawBox(9, 4, 1, 1);
    drawBox(8, 6, 1, 1);
    drawBox(10, 6, 1, 1);
    drawBox(12, 6, 1, 1);
    drawBox(6, 8, 1, 1);
    drawBox(8, 8, 3, 3);
    drawBox(12, 8, 1, 3);
    drawBox(14, 8, 2, 1);
    drawBox(17, 8, 2, 1);
    drawBox(9, 12, 1, 1);
    drawBox(10, 12, 2, 2);
    drawBox(13, 12, 1, 1);
    drawBox(8, 15, 1, 1);
    drawBox(10, 15, 2, 1);
    drawBox(14, 15, 2, 2);
    drawBox(17, 15, 1, 2);
    drawBox(15, 18, 3, 1);
    drawBox(14, 20, 2, 1);
    drawBox(17, 20, 2, 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
