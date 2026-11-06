import 'package:flutter/material.dart';

/// Game text style using the bundled rounded Arabic/Latin font.
TextStyle gs(double size, {Color? color = Colors.white, double weight = 800, double height = 1.15}) => TextStyle(
      fontFamily: 'Baloo',
      fontSize: size,
      color: color,
      height: height,
      fontWeight: FontWeight.w800,
      fontVariations: [FontVariation('wght', weight)],
    );

class StrokeText extends StatelessWidget {
  const StrokeText(
    this.text, {
    super.key,
    this.size = 24,
    this.color = Colors.white,
    this.stroke = const Color(0xFF14284A),
    this.strokeWidth = 5,
    this.align = TextAlign.center,
  });

  final String text;
  final double size;
  final Color color;
  final Color stroke;
  final double strokeWidth;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final outline = gs(size, color: null).copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..color = stroke,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text, textAlign: align, style: outline),
        Text(text, textAlign: align, style: gs(size, color: color)),
      ],
    );
  }
}

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CoinPainter());
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final p = Paint()..isAntiAlias = true;
    canvas.drawCircle(c.translate(0, r * 0.14), r * 0.92, p..color = const Color(0xFFC8890F));
    canvas.drawCircle(c, r * 0.92, p..color = const Color(0xFFFFD447));
    canvas.drawCircle(
        c,
        r * 0.58,
        p
          ..color = const Color(0xFFE9AE1E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.16);
    p.style = PaintingStyle.fill;
    canvas.drawCircle(c.translate(-r * 0.32, -r * 0.34), r * 0.16, p..color = Colors.white.withValues(alpha: 0.8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GemIcon extends StatelessWidget {
  const GemIcon({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GemPainter());
}

class _GemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final pts = [Offset(w * 0.5, h * 0.02), Offset(w * 0.95, h * 0.38), Offset(w * 0.5, h * 0.98), Offset(w * 0.05, h * 0.38)];
    final p = Paint()..isAntiAlias = true;
    canvas.drawPath(Path()..addPolygon(pts, true), p..color = const Color(0xFF55D6F5));
    canvas.drawPath(Path()..addPolygon([pts[0], pts[1], Offset(w * 0.5, h * 0.45), pts[3]], true), p..color = const Color(0xFFB5F3FF));
    canvas.drawPath(
        Path()..addPolygon(pts, true),
        p
          ..color = const Color(0xFF1B7FA3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.07
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HudPill extends StatelessWidget {
  const HudPill({super.key, required this.icon, required this.text, this.pulse = 0, this.width = 132});

  final Widget icon;
  final String text;
  final double pulse;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 1 + pulse * 0.14,
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        height: 40,
        padding: const EdgeInsets.only(left: 6, right: 10),
        decoration: BoxDecoration(
          color: const Color(0xD914284A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(text, style: gs(21)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big chunky game button.
class GameButton extends StatelessWidget {
  const GameButton({
    super.key,
    required this.child,
    required this.onTap,
    this.color = const Color(0xFFFF8A3D),
    this.shade = const Color(0xFFC85A16),
    this.padding = const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
    this.radius = 22,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color shade;
  final EdgeInsets padding;
  final double radius;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = enabled ? color : const Color(0xFF7D8597);
    final sh = enabled ? shade : const Color(0xFF555C6B);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(color: sh, borderRadius: BorderRadius.circular(radius)),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(c, Colors.white, 0.25)!, c],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
          ),
          child: child,
        ),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onTap, this.size = 46, this.badge});

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size + 8,
        height: size + 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 4,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: const Color(0xD914284A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
                ),
                child: Icon(icon, color: Colors.white, size: size * 0.55),
              ),
            ),
            if (badge != null) Positioned(right: -2, top: -2, child: badge!),
          ],
        ),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.title, required this.child, required this.onClose});

  final String title;
  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      margin: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16284A),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF6FB6FF), width: 3),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
            decoration: const BoxDecoration(
              color: Color(0xFF2B5C9E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
            ),
            child: Row(
              children: [
                Expanded(child: StrokeText(title, size: 26, align: TextAlign.start)),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                ),
              ],
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}
