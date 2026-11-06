import 'dart:ui';

/// Orthographic camera rotated 45 degrees around the vertical axis and
/// pitched 45 degrees down. World units are metres; +x goes down-right on the
/// screen, +y goes down-left and +z goes up.
const double kX = 0.70710678;
const double kY = 0.5;
const double kZ = 0.70710678;

class IsoCamera {
  double cx = 0;
  double cy = 0;
  double scale = 40;
  double dpr = 1;
  Size size = const Size(400, 800);
  double focusY = 0.5;
  Offset shake = Offset.zero;

  Offset w2s(double x, double y, [double z = 0]) {
    final dx = x - cx;
    final dy = y - cy;
    return Offset(
      size.width * 0.5 + (dx - dy) * kX * scale + shake.dx,
      size.height * focusY + ((dx + dy) * kY - z * kZ) * scale + shake.dy,
    );
  }

  Offset p(Offset w, [double z = 0]) => w2s(w.dx, w.dy, z);

  /// Converts a direction on the screen to a normalised direction on the
  /// ground plane.
  Offset screenDirToWorld(Offset d) {
    final a = d.dx / kX;
    final b = d.dy / kY;
    final w = Offset((a + b) * 0.5, (b - a) * 0.5);
    final len = w.distance;
    return len < 1e-6 ? Offset.zero : w / len;
  }

  /// Screen-space direction (not normalised) of a ground-plane direction.
  Offset worldDirToScreen(Offset d) =>
      Offset((d.dx - d.dy) * kX, (d.dx + d.dy) * kY);

  /// Inverse projection of a screen point onto the ground plane (z = 0).
  Offset s2w(Offset s) {
    final a = (s.dx - size.width * 0.5 - shake.dx) / (kX * scale);
    final b = (s.dy - size.height * focusY - shake.dy) / (kY * scale);
    return Offset(cx + (a + b) * 0.5, cy + (b - a) * 0.5);
  }
}
