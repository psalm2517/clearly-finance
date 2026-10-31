import 'package:flutter/material.dart';

/// The Clearly mark: a lavender C with a mint shape inside it. Drawn from the
/// same geometry as the website's SVG, so it stays sharp at any size.
class ClearlyMark extends StatelessWidget {
  const ClearlyMark({super.key, this.height = 28});

  /// The mark is taller than it is wide (512 x 564).
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: height * 512 / 564,
      height: height,
      child: CustomPaint(
        painter: _MarkPainter(
          c: dark ? const Color(0xFFD3DEFE) : const Color(0xFF7287FD),
          mint: dark ? const Color(0xFF92E3D9) : const Color(0xFF179299),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.c, required this.mint});
  final Color c;
  final Color mint;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 512, size.height / 564);
    const outer = Radius.circular(240.02);
    const inner = Radius.circular(154.17);
    final shape = Path()
      ..moveTo(470.10, 135.32)
      ..arcToPoint(
        const Offset(470.10, 431.12),
        radius: outer,
        largeArc: true,
        clockwise: false,
      )
      ..lineTo(404.18, 379.05)
      ..arcToPoint(
        const Offset(404.18, 187.39),
        radius: inner,
        largeArc: true,
        clockwise: true,
      )
      ..close();
    canvas.drawPath(
      shape,
      Paint()
        ..color = c
        ..isAntiAlias = true,
    );

    const r = Radius.circular(9);
    final piece = Path()
      ..moveTo(252.49, 224.67)
      ..lineTo(347.79, 184.30)
      ..arcToPoint(const Offset(360.30, 192.59), radius: r, clockwise: true)
      ..lineTo(360.30, 378.06)
      ..arcToPoint(const Offset(347.81, 386.35), radius: r, clockwise: true)
      ..lineTo(252.51, 346.32)
      ..arcToPoint(const Offset(247.00, 338.02), radius: r, clockwise: true)
      ..lineTo(247.00, 232.96)
      ..arcToPoint(const Offset(252.49, 224.67), radius: r, clockwise: true)
      ..close();
    canvas.drawPath(
      piece,
      Paint()
        ..color = mint
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.c != c || old.mint != mint;
}
