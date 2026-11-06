import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'iso.dart';
import 'strings.dart';
import 'world.dart';

/// Floating joystick state shared between the input layer and the painter.
class Joy {
  static const double radius = 58;
  int? pointer;
  Offset? origin;
  Offset? pos;

  bool get active => pointer != null && origin != null && pos != null;

  void clear() {
    pointer = null;
    origin = null;
    pos = null;
  }
}

class Pal {
  static const snow = Color(0xFFEFF4FB);
  static const snowShadow = Color(0xFFD6E0F1);
  static const waterDeep = Color(0xFF1A5FAE);
  static const waterMid = Color(0xFF2C8AD6);
  static const waterLight = Color(0xFF5CC3F1);
  static const iceA = Color(0xFFD3F0FF);
  static const iceB = Color(0xFFAADCF5);
  static const bankFace = Color(0xFFB9DDF4);
  static const wood = Color(0xFFC27C47);
  static const woodDark = Color(0xFF8E522D);
  static const woodLight = Color(0xFFE3A774);
  static const plank = Color(0xFFD69660);
  static const pine = Color(0xFF2F6F62);
  static const pineDark = Color(0xFF22544A);
  static const metal = Color(0xFF454B5E);
  static const gold = Color(0xFFFFD447);
  static const ink = Color(0xFF1E2238);
  static const stoneTop = Color(0xFFBAC3D4);
  static const stoneLeft = Color(0xFF97A2B8);
  static const stoneRight = Color(0xFF7D879D);
  static const bark = Color(0xFF7A4B2C);
  static const barkLight = Color(0xFF9C6A43);
  static const ring = Color(0xFFE2B47E);
}

final Map<String, TextPainter> _textCache = {};

TextPainter _tp(String text, double size, Color color, {Color? stroke, double strokeW = 3}) {
  final key = '$text|${size.toStringAsFixed(1)}|${color.toARGB32()}|${stroke?.toARGB32()}|${strokeW.toStringAsFixed(1)}';
  final hit = _textCache[key];
  if (hit != null) return hit;
  if (_textCache.length > 500) _textCache.clear();
  final base = TextStyle(
    fontFamily: 'Baloo',
    fontSize: size,
    height: 1.0,
    fontWeight: FontWeight.w800,
    fontVariations: const [FontVariation('wght', 800)],
  );
  final style = stroke == null
      ? base.copyWith(color: color)
      : base.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeJoin = StrokeJoin.round
            ..color = stroke);
  final tp = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(text: text, style: style),
  )..layout();
  _textCache[key] = tp;
  return tp;
}

class WorldPainter extends CustomPainter {
  WorldPainter(this.w, this.joy, {required Listenable repaint}) : super(repaint: repaint);

  final GameWorld w;
  final Joy joy;

  @override
  void paint(Canvas canvas, Size size) {
    w.cam.size = size;
    _Renderer(canvas, w, joy).draw();
  }

  @override
  bool shouldRepaint(covariant WorldPainter oldDelegate) => !identical(oldDelegate.w, w);
}

class _D {
  final double d;
  final int k;
  final Object o;

  _D(this.d, this.k, this.o);
}

// draw kinds
const int _kTree = 0,
    _kPost = 1,
    _kProp = 2,
    _kGate = 3,
    _kProcA = 4,
    _kProcB = 5,
    _kCrate = 6,
    _kCounter = 7,
    _kPile = 8,
    _kCash = 9,
    _kActor = 10,
    _kCustomer = 11,
    _kCrowd = 12,
    _kCannon = 13,
    _kEnemy = 14,
    _kLandmark = 15,
    _kPlayer = 16,
    _kNode = 17;

double _easeOutBack(double t) {
  if (t >= 1) return 1;
  if (t <= 0) return 0;
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final u = t - 1;
  return 1 + c3 * u * u * u + c1 * u * u;
}

double _h1(int i) {
  final v = math.sin(i * 12.9898 + 4.1414) * 43758.5453;
  return v - v.floorToDouble();
}

double _h2(int a, int b) {
  final v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

class _Renderer {
  _Renderer(this.c, this.w, this.joy)
      : cam = w.cam,
        s = w.cam.scale,
        size = w.cam.size;

  Canvas c;
  final GameWorld w;
  final Joy joy;
  final IsoCamera cam;
  final double s;
  final Size size;
  final List<void Function()> _late = [];

  static final Paint _p = Paint()..isAntiAlias = true;
  static final Paint _ps = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  SourceKind get src => w.region.source;

  bool _vis(Offset p, double m) =>
      p.dx > -m && p.dx < size.width + m && p.dy > -m && p.dy < size.height + m;

  // =========================================================== sprite cache
  // Static scenery (trees, fence logs, boulders) and the idle crowd are
  // rendered once into textures and then drawn with a single call each frame.
  static final Map<String, ui.Image> _sprites = {};
  static final Expando<(int, ui.Image)> _personSprites = Expando();
  static double _spriteScale = -1, _spriteDpr = -1;
  static int _spriteGen = 0;
  static final Paint _imgPaint = Paint()..filterQuality = FilterQuality.low;

  void _validateSprites() {
    if (_spriteScale != s || _spriteDpr != cam.dpr) {
      for (final i in _sprites.values) {
        i.dispose();
      }
      _sprites.clear();
      _spriteGen++;
      _spriteScale = s;
      _spriteDpr = cam.dpr;
    }
  }

  ui.Image _renderSprite(double w0, double h0, double ax, double ay, void Function() draw) {
    final dpr = cam.dpr;
    final rec = ui.PictureRecorder();
    final saved = c;
    c = Canvas(rec);
    c.scale(dpr);
    c.translate(ax, ay);
    draw();
    final pic = rec.endRecording();
    c = saved;
    final img = pic.toImageSync(math.max(1, (w0 * dpr).ceil()), math.max(1, (h0 * dpr).ceil()));
    pic.dispose();
    return img;
  }

  ui.Image _sprite(String key, double w0, double h0, double ax, double ay, void Function() draw) =>
      _sprites[key] ??= _renderSprite(w0, h0, ax, ay, draw);

  void _blit(ui.Image img, Offset at, double w0, double h0, double ax, double ay) {
    c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(at.dx - ax, at.dy - ay, w0, h0), _imgPaint);
  }

  void _poly(List<Offset> pts, Color col) {
    _p.color = col;
    c.drawPath(Path()..addPolygon(pts, true), _p);
  }

  void _text(String t, Offset center, double size, Color color, {Color? stroke}) {
    if (stroke != null) {
      final sp = _tp(t, size, color, stroke: stroke, strokeW: math.max(2, size * 0.24));
      sp.paint(c, center - Offset(sp.width / 2, sp.height / 2));
    }
    final tp = _tp(t, size, color);
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  // =========================================================== primitives
  void _box(double x0, double y0, double z0, double x1, double y1, double z1, Color top, Color left, Color right) {
    final a = cam.w2s(x0, y1, z0), b = cam.w2s(x1, y1, z0), d = cam.w2s(x1, y0, z0);
    final a2 = cam.w2s(x0, y1, z1), b2 = cam.w2s(x1, y1, z1), d2 = cam.w2s(x1, y0, z1), e2 = cam.w2s(x0, y0, z1);
    _poly([a, b, b2, a2], left);
    _poly([b, d, d2, b2], right);
    _poly([e2, d2, b2, a2], top);
  }

  void _cyl(double x, double y, double z0, double z1, double r, Color side, Color top, {double r1 = -1}) {
    final rt = r1 < 0 ? r : r1;
    final b = cam.w2s(x, y, z0), t = cam.w2s(x, y, z1);
    final rx = r * s, ry = rx * 0.7071, tx = rt * s, ty = tx * 0.7071;
    final path = Path()
      ..moveTo(t.dx - tx, t.dy)
      ..lineTo(b.dx - rx, b.dy)
      ..arcToPoint(Offset(b.dx + rx, b.dy), radius: Radius.elliptical(rx, ry), clockwise: false)
      ..lineTo(t.dx + tx, t.dy)
      ..close();
    _p.color = side;
    c.drawPath(path, _p);
    _p.color = Colors.black.withValues(alpha: 0.12);
    c.drawPath(
        Path()
          ..moveTo(t.dx + tx * 0.35, t.dy)
          ..lineTo(b.dx + rx * 0.35, b.dy + ry * 0.92)
          ..arcToPoint(Offset(b.dx + rx, b.dy), radius: Radius.elliptical(rx, ry), clockwise: false)
          ..lineTo(t.dx + tx, t.dy)
          ..close(),
        _p);
    _p.color = top;
    c.drawOval(Rect.fromCenter(center: t, width: tx * 2, height: ty * 2), _p);
  }

  void _shadow(Offset g, double w0, double h0, [double a = 0.16]) {
    _p.color = Color.fromRGBO(20, 30, 60, a);
    c.drawOval(Rect.fromCenter(center: g, width: w0, height: h0), _p);
  }

  Path _roundQuad(Rect r, double z, double cut) {
    Offset p(double x, double y) => cam.w2s(x, y, z);
    final a = p(r.left + cut, r.top);
    final path = Path()..moveTo(a.dx, a.dy);
    void l(Offset o) => path.lineTo(o.dx, o.dy);
    void q(Offset ctrl, Offset end) => path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
    l(p(r.right - cut, r.top));
    q(p(r.right, r.top), p(r.right, r.top + cut));
    l(p(r.right, r.bottom - cut));
    q(p(r.right, r.bottom), p(r.right - cut, r.bottom));
    l(p(r.left + cut, r.bottom));
    q(p(r.left, r.bottom), p(r.left, r.bottom - cut));
    l(p(r.left, r.top + cut));
    q(p(r.left, r.top), a);
    path.close();
    return path;
  }

  // =========================================================== frame
  void draw() {
    _validateSprites();
    _p.shader = null;
    _p.color = Pal.snow;
    c.drawRect(Offset.zero & size, _p);
    if (w.isRiver) {
      _river();
      _nearBank();
    } else {
      _field();
    }
    _drifts();
    _campFloor();
    if (w.isRiver) _dock();
    _pads();
    _tiles();
    _levelTiles();
    _objects();
    _projectiles();
    _flights();
    _particles();
    for (final f in _late) {
      f();
    }
    _worldUi();
    _snowfall();
    _vignette();
    _hudFlies();
    _joystick();
  }

  // =========================================================== ground
  double _wrapY(double base, double period) {
    var fy = base % period;
    final start = cam.cy - period / 2;
    fy += ((start - fy) / period).ceil() * period;
    return fy;
  }

  void _river() {
    final fr = w.raid.freeze;
    final y0 = cam.cy - 45, y1 = cam.cy + 45;
    final a = cam.w2s(riverX0, y0, waterZ), b = cam.w2s(riverX1, y0, waterZ);
    final cc = cam.w2s(riverX1, y1, waterZ), d = cam.w2s(riverX0, y1, waterZ);
    final g0 = cam.w2s(riverX0, cam.cy, waterZ), g1 = cam.w2s(riverX1, cam.cy, waterZ);
    final deep = Color.lerp(Pal.waterDeep, Pal.iceB, fr)!;
    final mid = Color.lerp(Pal.waterMid, Pal.iceA, fr)!;
    final light = Color.lerp(Pal.waterLight, const Color(0xFFEAF8FF), fr)!;
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(g0, g1, [mid, deep, light], const [0.0, 0.5, 1.0]);
    c.drawPath(Path()..addPolygon([a, b, cc, d], true), paint);

    const period = 46.0;
    for (var i = 0; i < 12; i++) {
      final fx = riverX0 + 0.8 + _h1(i + 900) * (riverX1 - riverX0 - 1.6);
      final fy = _wrapY(_h1(i + 950) * period + w.time * 0.55, period);
      final ctr = cam.w2s(fx, fy, waterZ + 0.02);
      if (!_vis(ctr, 3 * s)) continue;
      final rad = 0.35 + _h1(i + 980) * 0.5;
      final pts = <Offset>[];
      for (var k = 0; k < 7; k++) {
        final ang = k / 7 * math.pi * 2;
        final rr = rad * (0.75 + _h2(i, k) * 0.45);
        pts.add(cam.w2s(fx + math.cos(ang) * rr, fy + math.sin(ang) * rr, waterZ + 0.02));
      }
      _poly(pts.map((p) => p.translate(0, 0.06 * s)).toList(), const Color(0x552B6FA8));
      _poly(pts, Color.lerp(const Color(0xFFF2FAFF), const Color(0xFFFFFFFF), fr)!);
    }

    if (fr < 0.97) {
      _ps.strokeWidth = math.max(1.2, 0.05 * s);
      _ps.color = Colors.white.withValues(alpha: 0.33 * (1 - fr));
      for (var i = 0; i < 70; i++) {
        final fx = riverX0 + 0.4 + _h1(i) * (riverX1 - riverX0 - 0.8);
        final fy = _wrapY(_h1(i + 100) * period + w.time * (0.6 + _h1(i + 200) * 0.6), period);
        final p1 = cam.w2s(fx, fy, waterZ);
        if (!_vis(p1, 30)) continue;
        final p2 = cam.w2s(fx + 0.03, fy + 0.5 + _h1(i + 300) * 0.7, waterZ);
        c.drawLine(p1, p2, _ps);
      }
      for (var i = 0; i < 26; i++) {
        final tw = math.sin(w.time * 2.6 + i * 1.7);
        if (tw < 0.55) continue;
        final fx = riverX0 + 0.5 + _h1(i + 400) * (riverX1 - riverX0 - 1.0);
        final fy = _wrapY(_h1(i + 450) * period + w.time * 0.5, period);
        final p = cam.w2s(fx, fy, waterZ);
        if (!_vis(p, 10)) continue;
        _p.color = Colors.white.withValues(alpha: (tw - 0.55) * 2.0 * (1 - fr));
        c.drawCircle(p, 0.06 * s, _p);
      }
    }
    if (fr > 0.05) {
      _ps.color = Colors.white.withValues(alpha: 0.85 * fr);
      _ps.strokeWidth = math.max(1, 0.04 * s);
      for (var i = 0; i < 26; i++) {
        final fx = riverX0 + 0.6 + _h1(i + 600) * (riverX1 - riverX0 - 1.2);
        final fy = _wrapY(_h1(i + 650) * period, period);
        var p = cam.w2s(fx, fy, waterZ);
        if (!_vis(p, 3 * s)) continue;
        final path = Path()..moveTo(p.dx, p.dy);
        var ang = _h1(i + 700) * math.pi * 2;
        for (var k = 0; k < 4; k++) {
          ang += (_h2(i, k) - 0.5) * 1.6;
          p = p + Offset(math.cos(ang), math.sin(ang) * 0.6) * (0.35 * s);
          path.lineTo(p.dx, p.dy);
        }
        c.drawPath(path, _ps);
      }
    }

    for (final f in w.fish) {
      if (f.vis <= 0.01) continue;
      final sp = cam.w2s(f.pos.dx, f.pos.dy, waterZ + 0.05);
      if (!_vis(sp, 2 * s)) continue;
      final dir = cam.worldDirToScreen(Offset(math.cos(f.phase * 0.8) * 0.18, f.speed.sign));
      final ang = math.atan2(dir.dy, dir.dx);
      _p.color = Color.fromRGBO(8, 35, 80, 0.22 * f.vis);
      c.drawOval(Rect.fromCenter(center: sp.translate(0.04 * s, 0.12 * s), width: 0.95 * s, height: 0.32 * s), _p);
      final ripple = (w.time * 0.9 + f.phase) % 1.0;
      _ps.color = Colors.white.withValues(alpha: (1 - ripple) * 0.35 * f.vis);
      _ps.strokeWidth = 1.2;
      c.drawOval(Rect.fromCenter(center: sp, width: (0.7 + ripple * 0.8) * s, height: (0.35 + ripple * 0.4) * s), _ps);
      _fishS(sp, f.kind, ang, alpha: 0.95 * f.vis, flash: f.flash);
    }

    final f0 = cam.w2s(riverX0, y0, waterZ), f1 = cam.w2s(riverX0, y1, waterZ);
    final f2 = cam.w2s(riverX0, y1, 0), f3 = cam.w2s(riverX0, y0, 0);
    _poly([f0, f1, f2, f3], Pal.bankFace);
    _ps.color = Colors.white;
    _ps.strokeWidth = 0.12 * s;
    c.drawLine(f3, f2, _ps);
  }

  void _nearBank() {
    final y0 = cam.cy - 45, y1 = cam.cy + 45;
    _poly([
      cam.w2s(riverX1 - 0.7, y0, waterZ),
      cam.w2s(riverX1 - 0.7, y1, waterZ),
      cam.w2s(riverX1, y1, waterZ),
      cam.w2s(riverX1, y0, waterZ),
    ], const Color(0x1A0A2A55));
    final m0 = cam.w2s(riverX1, y0, 0), m1 = cam.w2s(riverX1, y1, 0);
    _poly([m0, m1, cam.w2s(riverX1 + 70, y1, 0), cam.w2s(riverX1 + 70, y0, 0)], Pal.snow);
    _ps.color = const Color(0xFFCBE8F8);
    _ps.strokeWidth = 0.1 * s;
    c.drawLine(m0.translate(0, 0.07 * s), m1.translate(0, 0.07 * s), _ps);
    _ps.color = Colors.white;
    _ps.strokeWidth = 0.16 * s;
    c.drawLine(m0, m1, _ps);
  }

  /// The quarry floor or the forest clearing where resources are gathered.
  void _field() {
    final quarry = src == SourceKind.quarry;
    final fr = w.raid.freeze;
    final y0 = cam.cy - 45, y1 = cam.cy + 45;
    final base = quarry ? const Color(0xFFC9D2E2) : const Color(0xFFE3EAE4);
    final edge = quarry ? const Color(0xFFB2BDD1) : const Color(0xFFCFDACF);
    _poly([cam.w2s(riverX0 - 0.4, y0), cam.w2s(riverX1 + 0.3, y0), cam.w2s(riverX1 + 0.3, y1), cam.w2s(riverX0 - 0.4, y1)],
        Color.lerp(edge, Pal.snow, fr * 0.6)!);
    _poly([cam.w2s(riverX0, y0), cam.w2s(riverX1, y0), cam.w2s(riverX1, y1), cam.w2s(riverX0, y1)],
        Color.lerp(base, Pal.snow, fr * 0.7)!);
    const cell = 1.7;
    final iy0 = ((cam.cy - 26) / cell).floor(), iy1 = ((cam.cy + 26) / cell).ceil();
    final ix0 = (riverX0 / cell).floor(), ix1 = (riverX1 / cell).ceil();
    for (var ix = ix0; ix <= ix1; ix++) {
      for (var iy = iy0; iy <= iy1; iy++) {
        final h = _h2(ix + 400, iy - 70);
        if (h > 0.55) continue;
        final px = (ix + _h2(iy + 31, ix + 2)) * cell, py = (iy + _h2(ix - 9, iy + 13)) * cell;
        if (px < riverX0 + 0.3 || px > riverX1 - 0.3) continue;
        final sp = cam.w2s(px, py, 0);
        if (!_vis(sp, 2 * s)) continue;
        final r = (0.12 + h * 0.5) * s;
        if (quarry) {
          final pts = <Offset>[];
          for (var k = 0; k < 6; k++) {
            final a = k / 6 * math.pi * 2;
            final rr = r * (0.7 + _h2(ix * 7 + k, iy) * 0.5);
            pts.add(sp + Offset(math.cos(a) * rr, math.sin(a) * rr * 0.6));
          }
          _poly(pts, Color.lerp(const Color(0xFFAEB9CD), Pal.snow, fr * 0.7)!);
          if (h < 0.18) {
            _ps.color = const Color(0x557D879D);
            _ps.strokeWidth = math.max(1, 0.03 * s);
            c.drawLine(sp.translate(-r * 2, 0), sp.translate(r * 1.4, r * 0.8), _ps);
          }
        } else {
          _p.color = Color.lerp(h < 0.25 ? const Color(0xFFC9B79C) : const Color(0xFFC6D6C8), Pal.snow, fr * 0.7)!;
          c.drawOval(Rect.fromCenter(center: sp, width: r * 2.4, height: r * 1.1), _p);
        }
      }
    }
    // the far edge: a low ridge of rocks or a band of drifts
    _ps.color = quarry ? const Color(0xFF9AA5BA) : Colors.white;
    _ps.strokeWidth = 0.3 * s;
    c.drawLine(cam.w2s(riverX0, y0), cam.w2s(riverX0, y1), _ps);
    _ps.color = Colors.white.withValues(alpha: 0.9);
    _ps.strokeWidth = 0.12 * s;
    c.drawLine(cam.w2s(riverX0 - 0.1, y0, 0.1), cam.w2s(riverX0 - 0.1, y1, 0.1), _ps);
  }

  void _drifts() {
    final center = cam.s2w(Offset(size.width / 2, size.height / 2));
    const cell = 4.0;
    final ix0 = ((center.dx - 26) / cell).floor(), ix1 = ((center.dx + 26) / cell).ceil();
    final iy0 = ((center.dy - 26) / cell).floor(), iy1 = ((center.dy + 26) / cell).ceil();
    for (var ix = ix0; ix <= ix1; ix++) {
      for (var iy = iy0; iy <= iy1; iy++) {
        final h = _h2(ix, iy);
        if (h > 0.5) continue;
        final px = (ix + _h2(iy + 11, ix)) * cell, py = (iy + _h2(ix + 3, iy - 5)) * cell;
        if (px < riverX1 + 0.6 && px > riverX0 - 0.6) continue;
        final sp = cam.w2s(px, py, 0);
        if (!_vis(sp, 3 * s)) continue;
        final r = (0.7 + h * 2.2) * s;
        _p.color = Pal.snowShadow.withValues(alpha: 0.55);
        c.drawOval(Rect.fromCenter(center: sp, width: r * 2, height: r * 0.8), _p);
        _p.color = Colors.white.withValues(alpha: 0.8);
        c.drawOval(Rect.fromCenter(center: sp.translate(-r * 0.12, -r * 0.08), width: r * 1.6, height: r * 0.55), _p);
      }
    }
  }

  void _campFloor() {
    final r = w.zoneB ? Rect.fromLTRB(zoneARect.left, zoneARect.top, zoneARect.right, zoneBRect.bottom) : zoneARect;
    c.drawPath(_roundQuad(r.inflate(0.12), 0, 0.8), _p..color = w.region.campEdge);
    c.drawPath(_roundQuad(r.deflate(0.2), 0, 0.7), _p..color = w.region.camp);
    for (var i = 0; i < 55; i++) {
      final px = r.left + 0.5 + _h1(i + 1200) * (r.width - 1.0);
      final py = r.top + 0.5 + _h1(i + 1300) * (r.height - 1.0);
      final sp = cam.w2s(px, py, 0);
      if (!_vis(sp, 20)) continue;
      final rad = (0.05 + _h1(i + 1400) * 0.08) * s;
      _p.color = w.region.campEdge.withValues(alpha: 0.9);
      c.drawOval(Rect.fromCenter(center: sp, width: rad * 2, height: rad * 1.3), _p);
    }
    if (!w.zoneB) {
      final path = _roundQuad(zoneBRect.deflate(0.4), 0, 0.8);
      _ps.color = const Color(0x66A7B6D6);
      _ps.strokeWidth = 0.06 * s;
      c.drawPath(path, _ps);
    }
  }

  void _dock() {
    const r = dockRect;
    final legs = [Offset(r.left + 0.2, r.bottom - 0.2), Offset(r.left + 1.6, r.bottom - 0.2), Offset(r.left + 3.0, r.bottom - 0.2)];
    for (final l in legs) {
      _cyl(l.dx, l.dy, waterZ - 0.2, dockZ - 0.05, 0.14, Pal.woodDark, Pal.wood);
    }
    _box(r.left, r.top, waterZ + 0.15, r.right + 0.6, r.bottom, dockZ, Pal.plank, Pal.woodDark, Pal.wood);
    _ps.color = Pal.woodDark.withValues(alpha: 0.4);
    _ps.strokeWidth = math.max(1, 0.035 * s);
    for (var x = r.left + 0.42; x < r.right + 0.5; x += 0.42) {
      c.drawLine(cam.w2s(x, r.top, dockZ), cam.w2s(x, r.bottom, dockZ), _ps);
    }
    _ps.color = Colors.white.withValues(alpha: 0.9);
    _ps.strokeWidth = 0.1 * s;
    c.drawLine(cam.w2s(r.left + 0.05, r.top + 0.05, dockZ), cam.w2s(r.left + 0.05, r.bottom - 0.05, dockZ), _ps);
    for (final b in [Offset(r.left + 0.2, r.top + 0.2), Offset(r.left + 0.2, r.bottom - 0.2)]) {
      _cyl(b.dx, b.dy, dockZ, dockZ + 0.35, 0.15, Pal.woodDark, Pal.woodLight);
      _p.color = Colors.white;
      c.drawOval(Rect.fromCenter(center: cam.w2s(b.dx, b.dy, dockZ + 0.38), width: 0.26 * s, height: 0.17 * s), _p);
    }
  }

  void _zone(Rect r, Color tint, {bool chevrons = false, bool active = false}) {
    final z = w.groundZ(r.center) + 0.01;
    final path = _roundQuad(r, z, 0.3);
    _p.color = tint.withValues(alpha: 0.32);
    c.drawPath(path, _p);
    _ps.color = Colors.white.withValues(alpha: active ? 1 : 0.85);
    _ps.strokeWidth = (active ? 0.09 : 0.06) * s;
    c.drawPath(path, _ps);
    if (chevrons) {
      final ctr = cam.w2s(r.center.dx, r.center.dy, z);
      final bob = math.sin(w.time * 4) * 0.05 * s;
      _ps.color = Colors.white.withValues(alpha: 0.85);
      _ps.strokeWidth = 0.08 * s;
      for (var i = 0; i < 2; i++) {
        final y = ctr.dy - 0.12 * s + i * 0.17 * s + bob;
        c.drawPath(
            Path()
              ..moveTo(ctr.dx - 0.2 * s, y - 0.07 * s)
              ..lineTo(ctr.dx, y + 0.07 * s)
              ..lineTo(ctr.dx + 0.2 * s, y - 0.07 * s),
            _ps);
      }
    }
  }

  void _pads() {
    final pp = w.player.pos;
    for (final p in w.pickPiles) {
      _zone(p.zone, const Color(0xFF3F9AE0), active: p.zone.contains(pp));
    }
    for (final p in w.dropPiles) {
      _zone(p.zone, const Color(0xFFFF9A3D), chevrons: true, active: p.zone.contains(pp));
    }
    for (final cp in w.cashPiles) {
      _zone(cp.zone, const Color(0xFFFFC93C), active: cp.zone.contains(pp));
    }
  }

  void _tiles() {
    for (final t in w.tiles) {
      if (!w.tileVisible(t) || t.appear <= 0) continue;
      final a = _easeOutBack(t.appear);
      final r = Rect.fromCenter(center: t.def.pos, width: 1.6 * a, height: 1.6 * a);
      final z = w.groundZ(t.def.pos) + 0.015;
      final path = _roundQuad(r, z, 0.32 * a);
      _p.color = const Color(0xE8203A66);
      c.drawPath(path, _p);
      final f = t.paid / t.price;
      if (f > 0) {
        c.save();
        c.clipPath(path);
        final y = r.bottom - r.height * f;
        _poly([
          cam.w2s(r.left - 0.1, y, z),
          cam.w2s(r.right + 0.1, y, z),
          cam.w2s(r.right + 0.1, r.bottom + 0.1, z),
          cam.w2s(r.left - 0.1, r.bottom + 0.1, z),
        ], const Color(0xE639D98A));
        c.restore();
      }
      final pulse = 0.5 + 0.5 * math.sin(w.time * 6);
      _ps.color = Color.lerp(Colors.white, const Color(0xFFFFE066), t.glow * pulse)!;
      _ps.strokeWidth = (0.07 + 0.04 * t.glow) * s;
      c.drawPath(path, _ps);
      final ctr = cam.w2s(t.def.pos.dx, t.def.pos.dy, z);
      _tileIcon(t.def.icon, ctr.translate(0, -0.2 * s * a), 0.46 * s * a);
      _priceTag(t.price - t.paid, ctr.translate(0, 0.3 * s * a), a);
    }
  }

  void _priceTag(int amount, Offset at, double a) {
    final tp = _tp(fmtNum(amount), 0.34 * s * a, Colors.white);
    final total = tp.width + 0.3 * s * a;
    final left = at.dx - total / 2;
    _coinIcon(Offset(left + 0.12 * s * a, at.dy), 0.12 * s * a);
    tp.paint(c, Offset(left + 0.3 * s * a, at.dy - tp.height / 2));
  }

  void _levelTiles() {
    for (final t in w.levelTiles) {
      if (!w.levelTileVisible(t) || t.appear <= 0) continue;
      final a = _easeOutBack(t.appear);
      final r = Rect.fromCenter(center: t.pos, width: 1.25 * a, height: 1.25 * a);
      final z = w.groundZ(t.pos) + 0.015;
      final path = _roundQuad(r, z, 0.26 * a);
      _p.color = Color.lerp(const Color(0xE81F5A49), Colors.white, t.flash * 0.6)!;
      c.drawPath(path, _p);
      final price = w.levelPrice(t.kind);
      final f = (t.paid / price).clamp(0.0, 1.0);
      if (f > 0) {
        c.save();
        c.clipPath(path);
        final y = r.bottom - r.height * f;
        _poly([
          cam.w2s(r.left - 0.1, y, z),
          cam.w2s(r.right + 0.1, y, z),
          cam.w2s(r.right + 0.1, r.bottom + 0.1, z),
          cam.w2s(r.left - 0.1, r.bottom + 0.1, z),
        ], const Color(0xE65CF0A8));
        c.restore();
      }
      _ps.color = Color.lerp(const Color(0xFFB8FFD9), const Color(0xFFFFE066), t.glow)!;
      _ps.strokeWidth = (0.06 + 0.03 * t.glow) * s;
      c.drawPath(path, _ps);
      final ctr = cam.w2s(t.pos.dx, t.pos.dy, z);
      final bob = math.sin(w.time * 5 + t.pos.dx) * 0.04 * s;
      final ic = ctr.translate(-0.2 * s * a, -0.2 * s * a + bob);
      _p.color = const Color(0xFF5CF0A8);
      c.drawCircle(ic, 0.17 * s * a, _p);
      _p.color = const Color(0xFF14412F);
      c.drawPath(
          Path()
            ..moveTo(ic.dx, ic.dy - 0.11 * s * a)
            ..lineTo(ic.dx + 0.1 * s * a, ic.dy + 0.01 * s * a)
            ..lineTo(ic.dx + 0.04 * s * a, ic.dy + 0.01 * s * a)
            ..lineTo(ic.dx + 0.04 * s * a, ic.dy + 0.1 * s * a)
            ..lineTo(ic.dx - 0.04 * s * a, ic.dy + 0.1 * s * a)
            ..lineTo(ic.dx - 0.04 * s * a, ic.dy + 0.01 * s * a)
            ..lineTo(ic.dx - 0.1 * s * a, ic.dy + 0.01 * s * a)
            ..close(),
          _p);
      _text('${w.sl(t.kind) + 2}', ctr.translate(0.16 * s * a, -0.19 * s * a + bob), 0.3 * s * a, Colors.white);
      _priceTag(price - t.paid, ctr.translate(0, 0.25 * s * a), a * 0.9);
    }
  }

  void _tileIcon(TileIcon icon, Offset o, double sz) {
    _p.color = Colors.white;
    _ps.color = Colors.white;
    switch (icon) {
      case TileIcon.helper:
        switch (src) {
          case SourceKind.river:
            _ps.strokeWidth = sz * 0.12;
            c.drawLine(o.translate(-sz * 0.45, sz * 0.4), o.translate(sz * 0.35, -sz * 0.3), _ps);
            c.drawPath(
                Path()
                  ..moveTo(o.dx + sz * 0.5, o.dy - sz * 0.45)
                  ..lineTo(o.dx + sz * 0.18, o.dy - sz * 0.32)
                  ..lineTo(o.dx + sz * 0.38, o.dy - sz * 0.12)
                  ..close(),
                _p);
            c.drawCircle(o.translate(-sz * 0.35, -sz * 0.1), sz * 0.16, _p);
          case SourceKind.quarry:
            _ps.strokeWidth = sz * 0.12;
            c.drawLine(o.translate(-sz * 0.35, sz * 0.45), o.translate(sz * 0.2, -sz * 0.2), _ps);
            c.drawPath(
                Path()
                  ..moveTo(o.dx - sz * 0.25, o.dy - sz * 0.45)
                  ..quadraticBezierTo(o.dx + sz * 0.2, o.dy - sz * 0.45, o.dx + sz * 0.5, o.dy + sz * 0.05),
                _ps);
          case SourceKind.grove:
            _ps.strokeWidth = sz * 0.12;
            c.drawLine(o.translate(-sz * 0.35, sz * 0.45), o.translate(sz * 0.15, -sz * 0.35), _ps);
            c.drawPath(
                Path()
                  ..moveTo(o.dx + sz * 0.05, o.dy - sz * 0.5)
                  ..lineTo(o.dx + sz * 0.5, o.dy - sz * 0.3)
                  ..lineTo(o.dx + sz * 0.35, o.dy + sz * 0.05)
                  ..lineTo(o.dx + sz * 0.0, o.dy - sz * 0.2)
                  ..close(),
                _p);
        }
      case TileIcon.porter:
        c.drawCircle(o.translate(-sz * 0.12, -sz * 0.3), sz * 0.2, _p);
        c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: o.translate(-sz * 0.12, sz * 0.18), width: sz * 0.5, height: sz * 0.55),
                Radius.circular(sz * 0.2)),
            _p);
        c.drawRect(Rect.fromCenter(center: o.translate(sz * 0.32, sz * 0.05), width: sz * 0.36, height: sz * 0.36), _p);
      case TileIcon.waiter:
        c.drawPath(
            Path()
              ..moveTo(o.dx - sz * 0.45, o.dy)
              ..quadraticBezierTo(o.dx, o.dy + sz * 0.7, o.dx + sz * 0.45, o.dy)
              ..close(),
            _p);
        _ps.strokeWidth = sz * 0.08;
        for (var i = -1; i <= 1; i++) {
          final x = o.dx + i * sz * 0.2;
          c.drawPath(
              Path()
                ..moveTo(x, o.dy - sz * 0.1)
                ..quadraticBezierTo(x - sz * 0.1, o.dy - sz * 0.3, x, o.dy - sz * 0.5),
              _ps);
        }
      case TileIcon.cannon:
        c.drawCircle(o.translate(-sz * 0.1, sz * 0.2), sz * 0.25, _p);
        _ps.strokeWidth = sz * 0.3;
        c.drawLine(o.translate(-sz * 0.1, sz * 0.05), o.translate(sz * 0.4, -sz * 0.35), _ps);
      case TileIcon.key:
        _ps.strokeWidth = sz * 0.12;
        c.drawCircle(o.translate(-sz * 0.22, -sz * 0.1), sz * 0.22, _ps);
        c.drawLine(o.translate(0, -sz * 0.1), o.translate(sz * 0.5, -sz * 0.1), _ps);
        c.drawLine(o.translate(sz * 0.32, -sz * 0.1), o.translate(sz * 0.32, sz * 0.12), _ps);
        c.drawLine(o.translate(sz * 0.48, -sz * 0.1), o.translate(sz * 0.48, sz * 0.08), _ps);
      case TileIcon.landmark:
        c.drawPath(
            Path()
              ..moveTo(o.dx - sz * 0.25, o.dy + sz * 0.5)
              ..lineTo(o.dx - sz * 0.14, o.dy - sz * 0.3)
              ..lineTo(o.dx + sz * 0.14, o.dy - sz * 0.3)
              ..lineTo(o.dx + sz * 0.25, o.dy + sz * 0.5)
              ..close(),
            _p);
        c.drawCircle(o.translate(0, -sz * 0.42), sz * 0.14, _p);
        _ps.strokeWidth = sz * 0.07;
        c.drawLine(o.translate(-sz * 0.25, -sz * 0.45), o.translate(-sz * 0.55, -sz * 0.55), _ps);
        c.drawLine(o.translate(sz * 0.25, -sz * 0.45), o.translate(sz * 0.55, -sz * 0.55), _ps);
      case TileIcon.cashier:
        c.drawOval(Rect.fromCenter(center: o.translate(0, sz * 0.1), width: sz * 0.8, height: sz * 0.7), _p);
        c.drawRect(Rect.fromCenter(center: o.translate(0, -sz * 0.3), width: sz * 0.3, height: sz * 0.16), _p);
        _ps.color = const Color(0xFF203A66);
        _ps.strokeWidth = sz * 0.08;
        c.drawCircle(o.translate(0, sz * 0.1), sz * 0.16, _ps);
    }
  }

  // =========================================================== objects
  void _objects() {
    final ds = <_D>[];
    void add(Offset p, int k, Object o, [double bias = 0]) => ds.add(_D(p.dx + p.dy + bias, k, o));
    final m = 3.2 * s;
    for (final t in w.trees) {
      if (_vis(cam.w2s(t.pos.dx, t.pos.dy), m)) add(t.pos, _kTree, t);
    }
    for (final p in w.fencePosts) {
      if (_vis(cam.w2s(p.dx, p.dy), 1.5 * s)) add(p, _kPost, p);
    }
    for (final p in w.props) {
      if (_vis(cam.w2s(p.pos.dx, p.pos.dy), 2.5 * s)) add(p.pos, _kProp, p);
    }
    for (final n in w.nodes) {
      if (_vis(cam.w2s(n.pos.dx, n.pos.dy), 3 * s)) add(n.pos, _kNode, n);
    }
    if (!w.zoneB) add(const Offset(4.5, 4.0), _kGate, 0);
    add(w.procA.pos, _kProcA, w.procA);
    add(w.procA.chef.pos, _kActor, w.procA.chef);
    add(w.procA.output.at, _kPile, w.procA.output);
    add(w.rawPad.at, _kPile, w.rawPad);
    final pb = w.procB;
    if (pb != null) {
      add(pb.pos, _kProcB, pb);
      add(pb.chef.pos, _kActor, pb.chef);
      add(const Offset(3.45, 6.25), _kCrate, pb.input);
      add(pb.output.at, _kPile, pb.output);
    }
    for (final k in w.counters) {
      add(k.pos, _kCounter, k);
      add(k.cash.at, _kCash, k.cash);
      for (final cu in k.queue) {
        add(cu.pos, _kCustomer, cu);
      }
      for (final cu in k.leaving) {
        add(cu.pos, _kCustomer, cu);
      }
      for (final cu in k.crowd) {
        if (_vis(cam.w2s(cu.pos.dx, cu.pos.dy), 2 * s)) add(cu.pos, _kCrowd, cu);
      }
    }
    for (final h in w.harvesters) {
      add(h.pos, _kActor, h);
    }
    for (final cr in w.couriers) {
      add(cr.pos, _kActor, cr);
    }
    final cs = w.cashier;
    if (cs != null) add(cs.pos, _kActor, cs);
    for (final cn in w.cannons) {
      add(cn.pos, _kCannon, cn);
    }
    for (final e in w.enemies) {
      add(e.pos, _kEnemy, e);
    }
    if (w.landmark) add(landmarkPos, _kLandmark, 0);
    add(w.player.pos, _kPlayer, w.player, 0.01);
    ds.sort((a, b) => a.d.compareTo(b.d));
    for (final d in ds) {
      switch (d.k) {
        case _kTree:
          _tree(d.o as Tree);
        case _kPost:
          _post(d.o as Offset);
        case _kProp:
          _prop(d.o as Prop);
        case _kNode:
          _node(d.o as Node);
        case _kGate:
          _gate();
        case _kProcA:
          _procA(d.o as Processor);
        case _kProcB:
          _procB(d.o as Processor);
        case _kCrate:
          _crate(d.o as Pile);
        case _kCounter:
          _counter(d.o as Counter);
        case _kPile:
          _pile(d.o as Pile);
        case _kCash:
          _cash(d.o as CashPile);
        case _kActor:
          _actor(d.o as Actor);
        case _kCustomer:
          {
            final cu = d.o as Customer;
            _person(cu.pos, 0, cu.facing, cu.walk, cu.move, cu.look, hop: cu.hop);
          }
        case _kCrowd:
          _crowdMember(d.o as Customer);
        case _kCannon:
          _cannon(d.o as Cannon);
        case _kEnemy:
          _enemy(d.o as Enemy);
        case _kLandmark:
          _landmark();
        case _kPlayer:
          _playerRing();
          _actor(d.o as Actor);
      }
    }
  }

  void _crowdMember(Customer cu) {
    final g = cam.w2s(cu.pos.dx, cu.pos.dy, 0);
    _shadow(g, 0.82 * s, 0.38 * s, 0.17);
    final w0 = 1.04 * s, h0 = 2.0 * s, ax = 0.52 * s, ay = 1.92 * s;
    var rec = _personSprites[cu];
    if (rec == null || rec.$1 != _spriteGen) {
      rec = (
        _spriteGen,
        _renderSprite(w0, h0, ax, ay,
            () => _person(cu.pos, 0, cu.facing, 0, 0, cu.look, simple: true, at: Offset.zero, shadow: false)),
      );
      _personSprites[cu] = rec;
    }
    _blit(rec.$2, g.translate(0, -cu.hop * s * kZ), w0, h0, ax, ay);
  }

  void _tree(Tree t) {
    final g = cam.w2s(t.pos.dx, t.pos.dy, 0);
    final sb = ((t.size - 0.75) / 0.12).round().clamp(0, 5);
    final tb = (t.tint * 2).round().clamp(0, 2);
    final q = s * (0.75 + sb * 0.12);
    final w0 = 1.64 * q, h0 = 2.36 * q, ax = 0.7 * q, ay = 2.02 * q;
    final img = _sprite('tree$sb-$tb', w0, h0, ax, ay, () => _treeAt(Offset.zero, q, tb / 2));
    _blit(img, g, w0, h0, ax, ay);
  }

  void _treeAt(Offset g, double q, double tint, {Color? needle, Color? needleDark, bool shadow = true}) {
    if (shadow) _shadow(g.translate(0.18 * q, 0.04 * q), 1.3 * q, 0.5 * q, 0.12);
    _p.color = Pal.bark;
    c.drawRect(Rect.fromLTWH(g.dx - 0.08 * q, g.dy - 0.42 * q, 0.16 * q, 0.42 * q), _p);
    final green = needle ?? Color.lerp(Pal.pine, const Color(0xFF3D8270), tint)!;
    final dark = needleDark ?? Color.lerp(Pal.pineDark, const Color(0xFF2B6356), tint)!;
    for (var i = 0; i < 3; i++) {
      final base = g.dy - (0.3 + i * 0.44) * q;
      final apex = base - (0.95 - i * 0.12) * q;
      final hw = (0.64 - i * 0.15) * q;
      _p.color = green;
      c.drawPath(
          Path()
            ..moveTo(g.dx, apex)
            ..lineTo(g.dx + hw, base)
            ..lineTo(g.dx - hw, base)
            ..close(),
          _p);
      _p.color = dark;
      c.drawPath(
          Path()
            ..moveTo(g.dx, apex)
            ..lineTo(g.dx + hw, base)
            ..lineTo(g.dx + hw * 0.05, base)
            ..close(),
          _p);
      final cy = apex + (base - apex) * 0.58;
      final cw = hw * 0.64;
      _p.color = const Color(0xFFF7FAFF);
      c.drawPath(
          Path()
            ..moveTo(g.dx, apex - 0.03 * q)
            ..lineTo(g.dx + cw, cy)
            ..quadraticBezierTo(g.dx + cw * 0.55, cy + 0.13 * q, g.dx + cw * 0.12, cy - 0.01 * q)
            ..quadraticBezierTo(g.dx - cw * 0.35, cy + 0.15 * q, g.dx - cw, cy)
            ..close(),
          _p);
      _p.color = const Color(0xFFDCE6F6);
      c.drawPath(
          Path()
            ..moveTo(g.dx, apex - 0.03 * q)
            ..lineTo(g.dx + cw, cy)
            ..quadraticBezierTo(g.dx + cw * 0.55, cy + 0.13 * q, g.dx + cw * 0.12, cy - 0.01 * q)
            ..close(),
          _p);
    }
  }

  void _post(Offset p) {
    final g = cam.w2s(p.dx, p.dy, 0);
    final w0 = 0.36 * s, h0 = 0.98 * s, ax = 0.18 * s, ay = 0.84 * s;
    final img = _sprite('post${w.regionIndex}', w0, h0, ax, ay, () => _postAt(Offset.zero));
    _blit(img, g, w0, h0, ax, ay);
  }

  void _postAt(Offset g) {
    final r = 0.15 * s, ry = r * 0.7071, h = 0.82 * kZ * s;
    final top = g.translate(0, -h);
    final (Color side, Color shade, Color cap) = switch (src) {
      SourceKind.river => (Pal.wood, Pal.woodDark.withValues(alpha: 0.55), Pal.woodLight),
      SourceKind.quarry => (const Color(0xFFBDE4F6), const Color(0x887CB8D8), const Color(0xFFE6F7FF)),
      SourceKind.grove => (const Color(0xFF7A4A2A), const Color(0x88402410), const Color(0xFFB98454)),
    };
    _p.color = side;
    c.drawPath(
        Path()
          ..moveTo(top.dx - r, top.dy)
          ..lineTo(g.dx - r, g.dy)
          ..arcToPoint(Offset(g.dx + r, g.dy), radius: Radius.elliptical(r, ry), clockwise: false)
          ..lineTo(top.dx + r, top.dy)
          ..close(),
        _p);
    _p.color = shade;
    c.drawRect(Rect.fromLTRB(g.dx + r * 0.3, top.dy, g.dx + r, g.dy), _p);
    if (src == SourceKind.grove) {
      // sharpened palisade tip
      _p.color = side;
      c.drawPath(
          Path()
            ..moveTo(top.dx - r, top.dy)
            ..lineTo(top.dx, top.dy - 0.18 * s)
            ..lineTo(top.dx + r, top.dy)
            ..close(),
          _p);
      _p.color = cap;
      c.drawPath(
          Path()
            ..moveTo(top.dx - r * 0.4, top.dy - 0.07 * s)
            ..lineTo(top.dx, top.dy - 0.18 * s)
            ..lineTo(top.dx + r * 0.2, top.dy - 0.06 * s)
            ..close(),
          _p);
      _p.color = Colors.white;
      c.drawOval(Rect.fromCenter(center: top.translate(0, -0.13 * s), width: 1.0 * r, height: 0.8 * ry), _p);
      return;
    }
    _p.color = cap;
    c.drawOval(Rect.fromCenter(center: top, width: 2 * r, height: 2 * ry), _p);
    _p.color = Colors.white;
    c.drawOval(Rect.fromCenter(center: top.translate(0, -0.035 * s), width: 1.75 * r, height: 1.5 * ry), _p);
  }

  void _gate() {
    const y = 4.0;
    for (final x0 in [3.75, 4.53]) {
      _box(x0, y - 0.08, 0, x0 + 0.72, y + 0.08, 0.95, Pal.woodLight, Pal.wood, Pal.woodDark);
      _ps.color = Pal.woodDark;
      _ps.strokeWidth = 0.05 * s;
      c.drawLine(cam.w2s(x0, y + 0.08, 0.15), cam.w2s(x0 + 0.72, y + 0.08, 0.8), _ps);
    }
    final lockC = cam.w2s(4.51, 4.1, 0.5);
    _ps.color = const Color(0xFF9AA3B5);
    _ps.strokeWidth = 0.07 * s;
    c.drawArc(Rect.fromCenter(center: lockC.translate(0, -0.12 * s), width: 0.28 * s, height: 0.3 * s), math.pi, math.pi,
        false, _ps);
    _p.color = Pal.gold;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: lockC, width: 0.36 * s, height: 0.3 * s), Radius.circular(0.06 * s)), _p);
    _p.color = Pal.woodDark;
    c.drawCircle(lockC, 0.045 * s, _p);
  }

  void _prop(Prop p) {
    final g = cam.w2s(p.pos.dx, p.pos.dy, 0);
    final q = s * p.size;
    switch (p.kind) {
      case PropKind.lantern:
        _shadow(g, 0.4 * q, 0.18 * q);
        _p.color = const Color(0xFF4A3B33);
        c.drawRect(Rect.fromLTWH(g.dx - 0.04 * q, g.dy - 1.5 * q, 0.08 * q, 1.5 * q), _p);
        final lamp = g.translate(0, -1.62 * q);
        final glow = 0.85 + 0.15 * math.sin(w.time * 3 + p.pos.dx);
        _p.color = const Color(0xFFFFD27A).withValues(alpha: 0.22 * glow);
        c.drawCircle(lamp, 0.55 * q, _p);
        _p.color = const Color(0xFF3B3F52);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: lamp, width: 0.3 * q, height: 0.36 * q), Radius.circular(0.06 * q)), _p);
        _p.color = Color.lerp(const Color(0xFFFFB347), const Color(0xFFFFF1B8), glow)!;
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: lamp, width: 0.2 * q, height: 0.24 * q), Radius.circular(0.05 * q)), _p);
        _p.color = Colors.white;
        c.drawOval(Rect.fromCenter(center: lamp.translate(0, -0.21 * q), width: 0.34 * q, height: 0.12 * q), _p);
      case PropKind.crate:
        final h = 0.55 * p.size;
        final hw = 0.32 * p.size;
        _shadow(g.translate(0.05 * q, 0.05 * q), 1.0 * q, 0.45 * q);
        _box(p.pos.dx - hw, p.pos.dy - hw, 0, p.pos.dx + hw, p.pos.dy + hw, h, Pal.woodLight, Pal.wood, Pal.woodDark);
        _ps.color = Pal.woodDark.withValues(alpha: 0.6);
        _ps.strokeWidth = 0.04 * s;
        c.drawLine(cam.w2s(p.pos.dx - hw, p.pos.dy + hw, 0.05), cam.w2s(p.pos.dx + hw, p.pos.dy + hw, h - 0.05), _ps);
        c.drawLine(cam.w2s(p.pos.dx + hw, p.pos.dy + hw, 0.05), cam.w2s(p.pos.dx + hw, p.pos.dy - hw, h - 0.05), _ps);
        _p.color = Colors.white;
        c.drawOval(Rect.fromCenter(center: cam.w2s(p.pos.dx, p.pos.dy, h), width: 0.5 * q, height: 0.25 * q), _p);
      case PropKind.barrel:
        _shadow(g.translate(0.05 * q, 0.05 * q), 0.8 * q, 0.36 * q);
        _cyl(p.pos.dx, p.pos.dy, 0, 0.7 * p.size, 0.28 * p.size, const Color(0xFFA9653A), const Color(0xFFD69660));
        _ps.color = const Color(0xFF5B4A44);
        _ps.strokeWidth = 0.04 * s;
        for (final z in [0.18, 0.52]) {
          final b = cam.w2s(p.pos.dx, p.pos.dy, z * p.size);
          c.drawArc(Rect.fromCenter(center: b, width: 0.56 * q, height: 0.4 * q), 0, math.pi, false, _ps);
        }
        _p.color = Colors.white;
        c.drawOval(Rect.fromCenter(center: cam.w2s(p.pos.dx, p.pos.dy, 0.72 * p.size), width: 0.4 * q, height: 0.24 * q), _p);
      case PropKind.mound:
        _p.color = Pal.snowShadow;
        c.drawOval(Rect.fromCenter(center: g.translate(0.06 * q, 0), width: 1.3 * q, height: 0.62 * q), _p);
        _p.color = Colors.white;
        c.drawOval(Rect.fromCenter(center: g.translate(-0.05 * q, -0.12 * q), width: 1.15 * q, height: 0.6 * q), _p);
      case PropKind.rock:
        _rockShape(g, q, const Color(0xFF8E98AE), const Color(0xFF6F7890));
      case PropKind.boulder:
        final sb = ((p.size - 0.8) / 0.25).round().clamp(0, 4);
        final bq = s * (0.8 + sb * 0.25);
        final w0 = 1.3 * bq, h0 = 1.0 * bq, ax = 0.62 * bq, ay = 0.82 * bq;
        final img = _sprite('boulder$sb', w0, h0, ax, ay,
            () => _rockShape(Offset.zero, bq * 1.25, const Color(0xFF8F9BB3), const Color(0xFF6A7590)));
        _blit(img, g, w0, h0, ax, ay);
      case PropKind.crystals:
        _shadow(g, 0.9 * q, 0.4 * q);
        _crystalCluster(g, q, const Color(0xFF7FD3F5), const Color(0xFF3E9FD0), glow: true);
      case PropKind.cart:
        _shadow(g.translate(0.05 * q, 0.05 * q), 1.4 * q, 0.6 * q);
        for (final wx in [-0.32, 0.32]) {
          _p.color = const Color(0xFF3B3F52);
          c.drawCircle(cam.w2s(p.pos.dx + wx, p.pos.dy + 0.36, 0.14), 0.14 * q, _p);
        }
        _box(p.pos.dx - 0.5, p.pos.dy - 0.33, 0.12, p.pos.dx + 0.5, p.pos.dy + 0.33, 0.62, const Color(0xFF6C7891),
            const Color(0xFF59627A), const Color(0xFF474F63));
        for (var i = 0; i < 3; i++) {
          _itemS(Item.ore, cam.w2s(p.pos.dx - 0.25 + i * 0.25, p.pos.dy, 0.62), sc: 0.8);
        }
      case PropKind.logpile:
        _shadow(g.translate(0.05 * q, 0.05 * q), 1.5 * q, 0.6 * q);
        for (var row = 0; row < 3; row++) {
          for (var i = 0; i < 3 - row; i++) {
            final sp = cam.w2s(p.pos.dx, p.pos.dy - 0.3 + i * 0.3 + row * 0.15, row * 0.22);
            _itemS(Item.log, sp, sc: 1.0);
          }
        }
        _p.color = Colors.white;
        c.drawOval(Rect.fromCenter(center: cam.w2s(p.pos.dx, p.pos.dy, 0.68), width: 0.6 * q, height: 0.2 * q), _p);
      case PropKind.stump:
        _shadow(g, 0.9 * q, 0.4 * q);
        _cyl(p.pos.dx, p.pos.dy, 0, 0.35, 0.32 * p.size, Pal.bark, Pal.ring);
        _ps.color = const Color(0xFFB98454);
        _ps.strokeWidth = math.max(1, 0.025 * s);
        c.drawOval(Rect.fromCenter(center: cam.w2s(p.pos.dx, p.pos.dy, 0.35), width: 0.32 * q, height: 0.22 * q), _ps);
        final hp = cam.w2s(p.pos.dx, p.pos.dy, 0.35);
        _ps.color = Pal.barkLight;
        _ps.strokeWidth = 0.06 * s;
        c.drawLine(hp, hp.translate(0.35 * q, -0.4 * q), _ps);
        _p.color = const Color(0xFFB8C2D6);
        c.drawPath(
            Path()
              ..moveTo(hp.dx - 0.05 * q, hp.dy - 0.02 * q)
              ..lineTo(hp.dx + 0.2 * q, hp.dy - 0.18 * q)
              ..lineTo(hp.dx + 0.12 * q, hp.dy + 0.08 * q)
              ..close(),
            _p);
      case PropKind.sign:
        _shadow(g, 0.5 * q, 0.2 * q);
        _p.color = Pal.woodDark;
        c.drawRect(Rect.fromLTWH(g.dx - 0.05 * q, g.dy - 1.0 * q, 0.1 * q, 1.0 * q), _p);
        final board = Rect.fromCenter(center: g.translate(0, -1.1 * q), width: 1.0 * q, height: 0.5 * q);
        _p.color = Pal.wood;
        c.drawRRect(RRect.fromRectAndRadius(board, Radius.circular(0.08 * q)), _p);
        _ps.color = Pal.woodDark;
        _ps.strokeWidth = 0.04 * s;
        c.drawRRect(RRect.fromRectAndRadius(board, Radius.circular(0.08 * q)), _ps);
        _itemS(w.region.prodB, board.center.translate(0, 0.08 * q), sc: 0.7);
        _p.color = Colors.white;
        c.drawOval(Rect.fromCenter(center: board.topCenter, width: 0.9 * q, height: 0.14 * q), _p);
    }
  }

  void _rockShape(Offset g, double q, Color light, Color dark) {
    _shadow(g.translate(0.05 * q, 0.03 * q), 0.9 * q, 0.4 * q);
    _poly([
      g.translate(-0.4 * q, 0),
      g.translate(-0.3 * q, -0.35 * q),
      g.translate(0.05 * q, -0.48 * q),
      g.translate(0.38 * q, -0.25 * q),
      g.translate(0.42 * q, 0.02 * q),
    ], light);
    _poly([g.translate(0.05 * q, -0.48 * q), g.translate(0.38 * q, -0.25 * q), g.translate(0.42 * q, 0.02 * q), g.translate(0.1 * q, -0.1 * q)],
        dark);
    _p.color = Colors.white;
    c.drawOval(Rect.fromCenter(center: g.translate(-0.08 * q, -0.4 * q), width: 0.5 * q, height: 0.16 * q), _p);
  }

  void _prism(Offset base, double ang, double len, double wid, Color light, Color dark) {
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(ang);
    _p.color = light;
    c.drawPath(
        Path()
          ..moveTo(-wid, 0)
          ..lineTo(-wid, -len)
          ..lineTo(0, -len - wid * 1.3)
          ..lineTo(0, 0)
          ..close(),
        _p);
    _p.color = dark;
    c.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(0, -len - wid * 1.3)
          ..lineTo(wid, -len)
          ..lineTo(wid, 0)
          ..close(),
        _p);
    _p.color = Colors.white.withValues(alpha: 0.55);
    c.drawRect(Rect.fromLTWH(-wid * 0.7, -len * 0.9, wid * 0.25, len * 0.6), _p);
    c.restore();
  }

  void _crystalCluster(Offset g, double q, Color light, Color dark, {bool glow = false}) {
    if (glow) {
      _p.color = light.withValues(alpha: 0.18 + 0.08 * math.sin(w.time * 3 + g.dx));
      c.drawCircle(g.translate(0, -0.4 * q), 0.7 * q, _p);
    }
    _prism(g.translate(-0.18 * q, 0), -0.45, 0.45 * q, 0.1 * q, light, dark);
    _prism(g.translate(0.18 * q, 0), 0.5, 0.4 * q, 0.1 * q, light, dark);
    _prism(g, 0.05, 0.7 * q, 0.13 * q, light, dark);
  }

  // ----------------------------------------------------------- resource nodes
  void _node(Node n) {
    if (src == SourceKind.quarry) {
      _rockNode(n);
    } else {
      _treeNode(n);
    }
  }

  void _rockNode(Node n) {
    final g = cam.w2s(n.pos.dx, n.pos.dy, 0);
    final fr = w.raid.freeze;
    if (!n.alive) {
      _shadow(g, 0.9 * s, 0.4 * s, 0.1);
      for (var i = 0; i < 4; i++) {
        final o = Offset((_h1(i + (n.seed * 100).round()) - 0.5) * 0.7 * s, (_h1(i + 50) - 0.5) * 0.25 * s);
        _p.color = i.isEven ? const Color(0xFF8E98AE) : const Color(0xFF7FD3F5);
        c.drawOval(Rect.fromCenter(center: g + o, width: 0.22 * s, height: 0.14 * s), _p);
      }
      return;
    }
    final big = isBig(n.kind), rare = isRare(n.kind);
    final q = s * _easeOutBack(n.grow) * (big ? 1.3 : 1.0);
    if (q <= 0.5) return;
    final o = g.translate(math.sin(w.time * 70) * n.shake * 0.05 * s, 0);
    final rock = Color.lerp(const Color(0xFF8E98AE), Colors.white, fr * 0.4)!;
    final rockDark = Color.lerp(const Color(0xFF6A7590), Colors.white, fr * 0.4)!;
    _rockShape(o, q * 1.05, rock, rockDark);
    final (Color cl, Color cd) = rare
        ? (const Color(0xFF7CF7C2), const Color(0xFF2FBF86))
        : (big ? (const Color(0xFF6FA8F2), const Color(0xFF2F64B8)) : (const Color(0xFF9BE3FA), const Color(0xFF45A8D8)));
    if (rare) {
      _p.color = const Color(0xFF7CF7C2).withValues(alpha: 0.22 + 0.1 * math.sin(w.time * 4 + n.seed * 9));
      c.drawCircle(o.translate(0, -0.45 * q), 0.75 * q, _p);
    }
    _prism(o.translate(-0.2 * q, -0.15 * q), -0.5, 0.42 * q, 0.1 * q, cl, cd);
    _prism(o.translate(0.17 * q, -0.12 * q), 0.45, 0.38 * q, 0.1 * q, cl, cd);
    _prism(o.translate(0, -0.2 * q), 0.05, 0.62 * q, 0.13 * q, cl, cd);
    final dmg = 1 - n.hp / n.maxHp;
    if (dmg > 0.01) {
      _ps.color = const Color(0xCC2B3550);
      _ps.strokeWidth = math.max(1, 0.03 * s);
      final cracks = (dmg * 3).ceil();
      for (var i = 0; i < cracks; i++) {
        final a = o.translate((i - 1) * 0.15 * q, -0.15 * q);
        c.drawPath(
            Path()
              ..moveTo(a.dx, a.dy)
              ..lineTo(a.dx + 0.06 * q, a.dy - 0.12 * q)
              ..lineTo(a.dx - 0.02 * q, a.dy - 0.22 * q),
            _ps);
      }
    }
  }

  void _treeNode(Node n) {
    final g = cam.w2s(n.pos.dx, n.pos.dy, 0);
    final big = isBig(n.kind), rare = isRare(n.kind);
    final size = big ? 1.35 : 1.12;
    final q = s * size;
    final variant = rare ? 1 : (big ? 2 : 0);
    final w0 = 1.64 * q, h0 = 2.36 * q, ax = 0.7 * q, ay = 2.02 * q;
    final img = _sprite('ntree$variant', w0, h0, ax, ay, () {
      _treeAt(Offset.zero, q, 0.3,
          needle: rare ? const Color(0xFFE0B23A) : (big ? const Color(0xFF285E52) : null),
          needleDark: rare ? const Color(0xFFB0841E) : (big ? const Color(0xFF1C463D) : null),
          shadow: false);
      // ribbon mark showing that the tree can be chopped
      _p.color = const Color(0xFFFF8A3D);
      c.drawRect(Rect.fromLTWH(-0.1 * q, -0.32 * q, 0.2 * q, 0.07 * q), _p);
    });
    if (!n.alive) {
      // stump left behind while the tree falls and regrows
      _shadow(g, 0.6 * s, 0.28 * s, 0.12);
      _cyl(n.pos.dx, n.pos.dy, 0, 0.22, 0.17 * size, Pal.bark, Pal.ring);
      if (n.fall < 1) {
        final a = 1 - n.fall;
        c.save();
        c.translate(g.dx, g.dy - 0.15 * s);
        c.rotate(n.fall * n.fall * math.pi * 0.5 * n.fallDir);
        _imgPaint.color = Color.fromRGBO(255, 255, 255, a);
        _blit(img, Offset.zero, w0, h0, ax, ay);
        _imgPaint.color = const Color(0xFFFFFFFF);
        c.restore();
      }
      return;
    }
    _shadow(g.translate(0.2 * q, 0.04 * q), 1.3 * q, 0.5 * q, 0.13);
    final gs = _easeOutBack(n.grow);
    if (gs <= 0.02) return;
    final sway = math.sin(w.time * 50) * n.shake * 0.07;
    c.save();
    c.translate(g.dx, g.dy);
    c.rotate(sway);
    c.scale(gs);
    _blit(img, Offset.zero, w0, h0, ax, ay);
    c.restore();
    if (rare) {
      for (var i = 0; i < 3; i++) {
        final tw = math.sin(w.time * 4 + i * 2.1 + n.seed * 7);
        if (tw < 0.3) continue;
        final p = g.translate((_h1(i + 77) - 0.5) * 1.0 * q, -(0.6 + _h1(i + 88) * 1.2) * q);
        _p.color = const Color(0xFFFFF3A0).withValues(alpha: (tw - 0.3) * 1.4);
        c.drawCircle(p, 0.05 * s, _p);
      }
    }
  }

  // ----------------------------------------------------------- stations
  void _workTable(bool stone) {
    _shadow(cam.w2s(4.05, -1.55, 0), 2.6 * s, 1.5 * s, 0.12);
    if (stone) {
      _box(3.5, -2.6, 0, 4.5, -0.6, 0.78, Pal.stoneTop, Pal.stoneLeft, Pal.stoneRight);
    } else {
      _box(3.5, -2.6, 0, 4.5, -0.6, 0.78, Pal.woodLight, Pal.wood, Pal.woodDark);
      _ps.color = Pal.woodDark.withValues(alpha: 0.5);
      _ps.strokeWidth = 0.04 * s;
      c.drawLine(cam.w2s(3.5, -0.6, 0.6), cam.w2s(4.5, -0.6, 0.6), _ps);
      c.drawLine(cam.w2s(4.5, -0.6, 0.6), cam.w2s(4.5, -2.6, 0.6), _ps);
    }
    _box(3.62, -2.5, 0.78, 4.38, -1.72, 0.81, const Color(0xFFF2DDBB), const Color(0xFFCDB089), const Color(0xFFB89B74));
  }

  void _procA(Processor pr) {
    final wk = pr.working;
    final busy = wk != null;
    switch (src) {
      case SourceKind.river:
        _workTable(false);
        final hot = busy ? 1.0 : 0.0;
        _box(3.6, -1.6, 0.78, 4.4, -0.68, 0.86, Color.lerp(Pal.metal, const Color(0xFF5E4A44), hot * 0.4)!,
            const Color(0xFF2E3242), const Color(0xFF262A38));
        if (busy) {
          final pulse = 0.5 + 0.5 * math.sin(w.time * 10);
          _ps.color = const Color(0xFFFF7A2E).withValues(alpha: 0.5 + 0.3 * pulse);
          _ps.strokeWidth = 0.05 * s;
          c.drawLine(cam.w2s(3.6, -0.68, 0.82), cam.w2s(4.4, -0.68, 0.82), _ps);
          c.drawLine(cam.w2s(4.4, -0.68, 0.82), cam.w2s(4.4, -1.6, 0.82), _ps);
        }
      case SourceKind.quarry:
        _workTable(true);
        // grinding wheel standing on the table
        final hub = cam.w2s(4.0, -1.15, 1.32);
        _box(3.9, -1.55, 0.78, 4.1, -1.45, 1.35, const Color(0xFF59627A), const Color(0xFF474F63), const Color(0xFF3B4254));
        _box(3.9, -0.85, 0.78, 4.1, -0.75, 1.35, const Color(0xFF59627A), const Color(0xFF474F63), const Color(0xFF3B4254));
        _p.color = const Color(0xFF8E98AE);
        c.drawOval(Rect.fromCenter(center: hub, width: 0.95 * s, height: 0.95 * s), _p);
        _p.color = const Color(0xFFB9C2D3);
        c.drawOval(Rect.fromCenter(center: hub.translate(-0.03 * s, -0.03 * s), width: 0.8 * s, height: 0.8 * s), _p);
        _ps.color = const Color(0xFF6A7590);
        _ps.strokeWidth = math.max(1, 0.035 * s);
        final rot = pr.anim * 14;
        for (var i = 0; i < 4; i++) {
          final a = rot + i * math.pi / 4;
          c.drawLine(hub - Offset(math.cos(a), math.sin(a)) * 0.36 * s, hub + Offset(math.cos(a), math.sin(a)) * 0.36 * s, _ps);
        }
        _p.color = const Color(0xFF454B5E);
        c.drawCircle(hub, 0.08 * s, _p);
      case SourceKind.grove:
        _workTable(false);
        _cyl(4.0, -1.15, 0.78, 1.02, 0.34, Pal.bark, Pal.ring);
        _ps.color = const Color(0xFFB98454);
        _ps.strokeWidth = math.max(1, 0.025 * s);
        c.drawOval(Rect.fromCenter(center: cam.w2s(4.0, -1.15, 1.02), width: 0.36 * s, height: 0.25 * s), _ps);
        if (!busy) {
          final hp = cam.w2s(4.05, -1.1, 1.02);
          _ps.color = Pal.barkLight;
          _ps.strokeWidth = 0.06 * s;
          c.drawLine(hp, hp.translate(0.3 * s, -0.42 * s), _ps);
          _p.color = const Color(0xFFB8C2D6);
          c.drawPath(
              Path()
                ..moveTo(hp.dx - 0.06 * s, hp.dy - 0.03 * s)
                ..lineTo(hp.dx + 0.18 * s, hp.dy - 0.2 * s)
                ..lineTo(hp.dx + 0.12 * s, hp.dy + 0.08 * s)
                ..close(),
              _p);
        }
    }
    _pileItems(pr.input);
    if (wk != null) {
      final z = src == SourceKind.quarry ? 1.0 : (src == SourceKind.grove ? 1.04 : pr.workZ);
      final sp = cam.w2s(pr.workAt.dx, pr.workAt.dy, z);
      if (pr.t < 0.55) {
        final wob = math.sin(pr.anim * 30) * 0.02 * s;
        if (catOf(wk) == Cat.raw && src == SourceKind.river) {
          _fishS(sp.translate(wob, -0.06 * s), wk, -0.15, cook: pr.t / 0.55 * 0.7, sc: 0.85);
        } else {
          _itemS(wk, sp.translate(wob, 0), sc: 0.8);
        }
      } else {
        final k = ((pr.t - 0.55) / 0.45).clamp(0.0, 1.0);
        for (var i = 0; i < 3; i++) {
          _itemS(pr.product, sp.translate((i - 1) * 0.3 * s, (i == 1 ? 0.05 : -0.02) * s), sc: 0.4 + 0.45 * k);
        }
      }
      final ring = cam.w2s(pr.pos.dx, pr.pos.dy, 2.7);
      _late.add(() => _progressRing(ring, pr.t, pr.product));
    }
  }

  void _procB(Processor pr) {
    switch (src) {
      case SourceKind.river:
        _pot(pr);
      case SourceKind.quarry:
        _forge(pr);
      case SourceKind.grove:
        _workbench(pr);
    }
    if (pr.working != null) {
      final ring = cam.w2s(pr.pos.dx, pr.pos.dy, 3.0);
      _late.add(() => _progressRing(ring, pr.t, pr.product));
    }
  }

  void _stoneRing(Offset p, bool front) {
    for (var i = 0; i < 11; i++) {
      final a = i / 11 * math.pi * 2 + 0.3;
      final isFront = math.sin(a) + math.cos(a) > 0;
      if (isFront != front) continue;
      final sp = cam.w2s(p.dx + math.cos(a) * 0.95, p.dy + math.sin(a) * 0.95, 0);
      _p.color = front ? const Color(0xFF9EA8BE) : const Color(0xFF8E98AE);
      c.drawOval(Rect.fromCenter(center: sp, width: 0.38 * s, height: 0.26 * s), _p);
      if (front) {
        _p.color = Colors.white.withValues(alpha: 0.85);
        c.drawOval(Rect.fromCenter(center: sp.translate(0, -0.06 * s), width: 0.24 * s, height: 0.1 * s), _p);
      }
    }
  }

  void _flames(Offset base, int n, double spread, double height) {
    for (var i = 0; i < n; i++) {
      final fx = (i - (n - 1) / 2) * spread;
      final fl = (height + height * 0.35 * math.sin(w.time * 14 + i * 2.1)) * s;
      final fb = base.translate(fx, 0);
      _p.color = const Color(0xFFFF7A2E);
      c.drawPath(
          Path()
            ..moveTo(fb.dx - 0.12 * s, fb.dy)
            ..quadraticBezierTo(fb.dx - 0.1 * s, fb.dy - fl * 0.6, fb.dx, fb.dy - fl)
            ..quadraticBezierTo(fb.dx + 0.1 * s, fb.dy - fl * 0.6, fb.dx + 0.12 * s, fb.dy)
            ..close(),
          _p);
      _p.color = const Color(0xFFFFD447);
      c.drawPath(
          Path()
            ..moveTo(fb.dx - 0.06 * s, fb.dy)
            ..quadraticBezierTo(fb.dx - 0.05 * s, fb.dy - fl * 0.35, fb.dx, fb.dy - fl * 0.6)
            ..quadraticBezierTo(fb.dx + 0.05 * s, fb.dy - fl * 0.35, fb.dx + 0.06 * s, fb.dy)
            ..close(),
          _p);
    }
  }

  void _pot(Processor pr) {
    final p = pr.pos;
    _shadow(cam.w2s(p.dx, p.dy, 0), 2.4 * s, 1.3 * s, 0.14);
    _stoneRing(p, false);
    final fireOn = pr.working != null;
    final base = cam.w2s(p.dx, p.dy, 0.05);
    _ps.color = const Color(0xFF6B3F22);
    _ps.strokeWidth = 0.16 * s;
    c.drawLine(base.translate(-0.5 * s, 0.05 * s), base.translate(0.5 * s, -0.08 * s), _ps);
    c.drawLine(base.translate(-0.45 * s, -0.1 * s), base.translate(0.45 * s, 0.08 * s), _ps);
    _cyl(p.dx, p.dy, 0.32, 1.02, 0.72, const Color(0xFF3E4456), const Color(0xFF5B6276), r1: 0.78);
    final top = cam.w2s(p.dx, p.dy, 1.02);
    _p.color = const Color(0xFF2B2F3D);
    c.drawOval(Rect.fromCenter(center: top, width: 1.38 * s, height: 0.97 * s), _p);
    _p.color = Color.lerp(const Color(0xFFE9D3A6), const Color(0xFFF7E3B5), fireOn ? 1 : 0)!;
    c.drawOval(Rect.fromCenter(center: top.translate(0, 0.03 * s), width: 1.22 * s, height: 0.84 * s), _p);
    if (fireOn) {
      for (var i = 0; i < 4; i++) {
        final ph = (w.time * 1.8 + i * 0.37) % 1.0;
        final bp = top.translate((_h1(i + 70) - 0.5) * 0.8 * s, (_h1(i + 80) - 0.5) * 0.4 * s);
        _ps.color = Colors.white.withValues(alpha: 0.6 * (1 - ph));
        _ps.strokeWidth = 1.5;
        c.drawCircle(bp, (0.04 + ph * 0.08) * s, _ps);
      }
      _p.color = const Color(0xFFFF8A3D);
      c.drawCircle(top.translate(-0.2 * s, 0.08 * s), 0.07 * s, _p);
      _p.color = const Color(0xFF43A047);
      c.drawCircle(top.translate(0.22 * s, -0.04 * s), 0.06 * s, _p);
      _flames(base.translate(0, 0.2 * s), 4, 0.28 * s, 0.32);
    }
    _stoneRing(p, true);
  }

  void _forge(Processor pr) {
    final p = pr.pos;
    final busy = pr.working != null;
    _shadow(cam.w2s(p.dx, p.dy, 0), 2.6 * s, 1.4 * s, 0.14);
    _box(p.dx - 0.7, p.dy - 0.7, 0, p.dx + 0.7, p.dy + 0.7, 1.25, const Color(0xFF8E98AE), const Color(0xFF6F7890),
        const Color(0xFF5B6377));
    // bricks
    _ps.color = const Color(0x55394055);
    _ps.strokeWidth = math.max(1, 0.025 * s);
    for (var z = 0.3; z < 1.2; z += 0.3) {
      c.drawLine(cam.w2s(p.dx - 0.7, p.dy + 0.7, z), cam.w2s(p.dx + 0.7, p.dy + 0.7, z), _ps);
      c.drawLine(cam.w2s(p.dx + 0.7, p.dy + 0.7, z), cam.w2s(p.dx + 0.7, p.dy - 0.7, z), _ps);
    }
    // glowing mouth on the front faces
    final glow = busy ? 0.75 + 0.25 * math.sin(w.time * 9) : 0.25;
    final mouth = [
      cam.w2s(p.dx - 0.35, p.dy + 0.7, 0.15),
      cam.w2s(p.dx + 0.35, p.dy + 0.7, 0.15),
      cam.w2s(p.dx + 0.35, p.dy + 0.7, 0.7),
      cam.w2s(p.dx, p.dy + 0.7, 0.85),
      cam.w2s(p.dx - 0.35, p.dy + 0.7, 0.7),
    ];
    _poly(mouth, const Color(0xFF2B2F3D));
    var cx = 0.0, cy = 0.0;
    for (final o in mouth) {
      cx += o.dx / mouth.length;
      cy += o.dy / mouth.length;
    }
    final mc = Offset(cx, cy);
    _poly(mouth.map((o) => mc + (o - mc) * 0.72).toList(),
        Color.lerp(const Color(0xFF7A2E10), const Color(0xFFFFB347), glow)!.withValues(alpha: 0.95));
    if (busy) {
      final m = cam.w2s(p.dx, p.dy + 0.7, 0.3);
      _flames(m, 3, 0.18 * s, 0.25);
      _p.color = const Color(0xFFFFB347).withValues(alpha: 0.18);
      c.drawCircle(m, 0.9 * s, _p);
    }
    _cyl(p.dx + 0.35, p.dy - 0.35, 1.25, 2.3, 0.2, const Color(0xFF59627A), const Color(0xFF2B2F3D));
    _p.color = Colors.white;
    c.drawOval(Rect.fromCenter(center: cam.w2s(p.dx - 0.2, p.dy + 0.1, 1.25), width: 0.9 * s, height: 0.4 * s), _p);
    // finished lamps glowing on top
    _itemS(Item.lamp, cam.w2s(p.dx - 0.3, p.dy + 0.25, 1.25), sc: 0.7);
  }

  void _workbench(Processor pr) {
    final p = pr.pos;
    final busy = pr.working != null;
    _shadow(cam.w2s(p.dx, p.dy, 0), 2.6 * s, 1.4 * s, 0.14);
    for (final o in const [Offset(-0.55, -0.55), Offset(0.55, -0.55), Offset(-0.55, 0.55), Offset(0.55, 0.55)]) {
      _box(p.dx + o.dx - 0.07, p.dy + o.dy - 0.07, 0, p.dx + o.dx + 0.07, p.dy + o.dy + 0.07, 0.8, Pal.woodLight, Pal.wood,
          Pal.woodDark);
    }
    _box(p.dx - 0.7, p.dy - 0.7, 0.72, p.dx + 0.7, p.dy + 0.7, 0.9, Pal.woodLight, Pal.wood, Pal.woodDark);
    _ps.color = Pal.woodDark.withValues(alpha: 0.5);
    _ps.strokeWidth = math.max(1, 0.03 * s);
    for (var x = -0.4; x <= 0.45; x += 0.4) {
      c.drawLine(cam.w2s(p.dx + x, p.dy - 0.7, 0.9), cam.w2s(p.dx + x, p.dy + 0.7, 0.9), _ps);
    }
    // a sled being built
    final k = busy ? (0.4 + 0.6 * pr.t) : 0.35;
    _sledS(cam.w2s(p.dx + 0.1, p.dy + 0.1, 0.92), sc: 1.4 * k + 0.2);
    // saw
    final sp = cam.w2s(p.dx - 0.45, p.dy - 0.3, 0.92);
    _p.color = const Color(0xFFB8C2D6);
    c.drawPath(
        Path()
          ..moveTo(sp.dx, sp.dy)
          ..lineTo(sp.dx + 0.55 * s, sp.dy - 0.1 * s)
          ..lineTo(sp.dx + 0.5 * s, sp.dy + 0.08 * s)
          ..lineTo(sp.dx, sp.dy + 0.12 * s)
          ..close(),
        _p);
    _p.color = const Color(0xFFE5484D);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(sp.dx - 0.2 * s, sp.dy - 0.04 * s, 0.22 * s, 0.18 * s), Radius.circular(0.04 * s)), _p);
  }

  void _crate(Pile pile) {
    _shadow(cam.w2s(3.47, 6.27, 0), 1.2 * s, 0.6 * s);
    _box(3.05, 5.85, 0, 3.85, 6.65, 0.45, Pal.woodLight, Pal.wood, Pal.woodDark);
    _ps.color = Pal.woodDark.withValues(alpha: 0.6);
    _ps.strokeWidth = 0.04 * s;
    c.drawLine(cam.w2s(3.05, 6.65, 0.22), cam.w2s(3.85, 6.65, 0.22), _ps);
    c.drawLine(cam.w2s(3.85, 6.65, 0.22), cam.w2s(3.85, 5.85, 0.22), _ps);
    _pileItems(pile);
  }

  void _counter(Counter k) {
    final x0 = k.pos.dx - k.hx, x1 = k.pos.dx + k.hx, y0 = k.pos.dy - k.hy, y1 = k.pos.dy + k.hy;
    final alongX = k.hx > k.hy;
    final pA = alongX ? Offset(x0 + 0.08, y0 + 0.06) : Offset(x0 + 0.06, y0 + 0.08);
    final pB = alongX ? Offset(x1 - 0.08, y0 + 0.06) : Offset(x0 + 0.06, y1 - 0.08);
    for (final p in [pA, pB]) {
      _cyl(p.dx, p.dy, 0, 2.35, 0.06, Pal.woodDark, Pal.wood);
    }
    const stripes = 7;
    final out = alongX ? const Offset(0, 0.75) : const Offset(0.75, 0);
    for (var i = 0; i < stripes; i++) {
      final t0 = i / stripes, t1 = (i + 1) / stripes;
      final a = Offset.lerp(pA, pB, t0)!, b = Offset.lerp(pA, pB, t1)!;
      _poly([
        cam.w2s(a.dx, a.dy, 2.4),
        cam.w2s(b.dx, b.dy, 2.4),
        cam.w2s(b.dx + out.dx, b.dy + out.dy, 2.05),
        cam.w2s(a.dx + out.dx, a.dy + out.dy, 2.05),
      ], i.isEven ? k.canopy : Colors.white);
    }
    for (var i = 0; i < stripes; i++) {
      final t = (i + 0.5) / stripes;
      final m = Offset.lerp(pA, pB, t)! + out;
      _p.color = i.isEven ? k.canopy : Colors.white;
      c.drawCircle(cam.w2s(m.dx, m.dy, 2.05).translate(0, 0.02 * s), 0.11 * s, _p);
    }
    _shadow(cam.w2s(k.pos.dx + 0.1, k.pos.dy + 0.1, 0), (k.hx + k.hy) * 2.0 * s, (k.hx + k.hy) * 1.0 * s, 0.12);
    _box(x0, y0, 0, x1, y1, 0.9, Pal.woodLight, Pal.wood, Pal.woodDark);
    if (alongX) {
      _poly([cam.w2s(x0 + 0.1, y1, 0.15), cam.w2s(x1 - 0.1, y1, 0.15), cam.w2s(x1 - 0.1, y1, 0.75), cam.w2s(x0 + 0.1, y1, 0.75)],
          darken(k.canopy, 0.1));
      _poly([cam.w2s(x0 + 0.1, y1, 0.42), cam.w2s(x1 - 0.1, y1, 0.42), cam.w2s(x1 - 0.1, y1, 0.52), cam.w2s(x0 + 0.1, y1, 0.52)],
          Colors.white.withValues(alpha: 0.9));
    } else {
      _poly([cam.w2s(x1, y0 + 0.1, 0.15), cam.w2s(x1, y1 - 0.1, 0.15), cam.w2s(x1, y1 - 0.1, 0.75), cam.w2s(x1, y0 + 0.1, 0.75)],
          darken(k.canopy, 0.15));
      _poly([cam.w2s(x1, y0 + 0.1, 0.42), cam.w2s(x1, y1 - 0.1, 0.42), cam.w2s(x1, y1 - 0.1, 0.52), cam.w2s(x1, y0 + 0.1, 0.52)],
          Colors.white.withValues(alpha: 0.9));
    }
    _pileItems(k.stock);
    if (k.stock.isFull) {
      final top = cam.w2s(k.stock.at.dx, k.stock.at.dy, k.stock.slotZ(k.stock.items.length) + 0.5);
      _late.add(() => _maxBadge(top));
    }
  }

  void _pile(Pile p) {
    _pileItems(p);
    if (p.items.isNotEmpty && (p.isFull || p.warn > 0.3)) {
      final top = cam.w2s(p.at.dx, p.at.dy, p.slotZ(p.items.length) + 0.6);
      _late.add(() => _maxBadge(top));
    }
  }

  void _pileItems(Pile p) {
    final n = p.items.length;
    if (n == 0) return;
    final order = p.cols == 4 ? const [0, 1, 2, 3] : (p.cols == 2 ? const [0, 1] : const [0]);
    final topRow = (n - 1) ~/ p.cols;
    for (final col in order) {
      for (var i = col; i < n; i += p.cols) {
        final xy = p.slotXY(i);
        var sp = cam.w2s(xy.dx, xy.dy, p.slotZ(i));
        if (i ~/ p.cols == topRow) sp = sp.translate(0, -p.bounce * 0.06 * s);
        final it = p.items[i];
        _itemS(it, sp, ang: catOf(it) == Cat.raw ? (_h1(i + 31) - 0.5) * 0.25 : 0);
      }
    }
  }

  void _cash(CashPile cp) {
    final n = math.min(48, (cp.amount / (4 * w.mul)).ceil());
    if (n <= 0) return;
    const g = 0.27;
    final b = cp.bounce;
    for (var col = 0; col < 9; col++) {
      final ox = (col % 3 - 1) * g, oy = (col ~/ 3 - 1) * g;
      for (var i = col; i < n; i += 9) {
        final z = 0.03 + (i ~/ 9) * 0.07;
        _coinS(cam.w2s(cp.at.dx + ox, cp.at.dy + oy, z).translate(0, -b * 0.05 * s));
      }
    }
  }

  void _cannon(Cannon cn) {
    final sc = _easeOutBack(cn.pop);
    if (sc <= 0.01) return;
    final p = cn.pos;
    _shadow(cam.w2s(p.dx, p.dy, 0), 1.6 * s * sc, 0.8 * s * sc);
    _cyl(p.dx, p.dy, 0, 0.3 * sc, 0.62 * sc, const Color(0xFF9AA3B5), const Color(0xFFC6CDDA));
    final h = 0.38 * sc;
    _box(p.dx - h, p.dy - h, 0.3 * sc, p.dx + h, p.dy + h, 1.3 * sc, Pal.woodLight, Pal.wood, Pal.woodDark);
    _p.color = Colors.white;
    c.drawOval(Rect.fromCenter(center: cam.w2s(p.dx, p.dy, 1.3 * sc), width: 0.9 * s * sc, height: 0.5 * s * sc), _p);
    final ammo = cam.w2s(p.dx + 0.18, p.dy + 0.2, 1.32 * sc);
    _p.color = const Color(0xFFEAF4FF);
    for (final o in const [Offset(-0.1, 0), Offset(0.1, 0.02), Offset(0, -0.1)]) {
      c.drawCircle(ammo + o * s * sc, 0.09 * s * sc, _p);
    }
    final base = cam.w2s(p.dx, p.dy, 1.6 * sc);
    final dir = cam.worldDirToScreen(Offset(math.cos(cn.aim), math.sin(cn.aim)));
    final dn = dir / math.max(1e-6, dir.distance);
    final len = (0.9 - cn.recoil * 0.25) * s * sc;
    final tip = base + dn * len + Offset(0, -0.15 * s * sc);
    _ps.color = const Color(0xFF3A4152);
    _ps.strokeWidth = 0.34 * s * sc;
    c.drawLine(base, tip, _ps);
    _ps.color = const Color(0xFF59627A);
    _ps.strokeWidth = 0.12 * s * sc;
    c.drawLine(base.translate(-0.04 * s, -0.08 * s), tip.translate(-0.04 * s, -0.08 * s), _ps);
    _p.color = const Color(0xFF242836);
    c.drawCircle(tip, 0.19 * s * sc, _p);
    _p.color = const Color(0xFF6B7591);
    c.drawCircle(base, 0.25 * s * sc, _p);
    _p.color = const Color(0xFF8F9AB5);
    c.drawCircle(base.translate(-0.06 * s, -0.07 * s), 0.1 * s * sc, _p);
  }

  // ----------------------------------------------------------- landmarks
  void _landmark() {
    switch (src) {
      case SourceKind.river:
        _lighthouse();
      case SourceKind.quarry:
        _spire();
      case SourceKind.grove:
        _hearth();
    }
  }

  void _lighthouse() {
    const p = landmarkPos;
    _shadow(cam.w2s(p.dx + 0.4, p.dy + 0.4, 0), 2.4 * s, 1.0 * s, 0.14);
    _cyl(p.dx, p.dy, 0, 0.45, 0.9, const Color(0xFF8E98AE), const Color(0xFFC6CDDA));
    const bands = 7;
    for (var i = 0; i < bands; i++) {
      final z0 = 0.45 + i * 0.55, z1 = z0 + 0.55;
      final r0 = 0.72 - i * 0.04, r1 = 0.72 - (i + 1) * 0.04;
      _cyl(p.dx, p.dy, z0, z1, r0, i.isEven ? const Color(0xFFE5484D) : const Color(0xFFF7F7FA),
          i.isEven ? const Color(0xFFF07075) : Colors.white,
          r1: r1);
    }
    const lz = 0.45 + bands * 0.55;
    _cyl(p.dx, p.dy, lz, lz + 0.1, 0.62, const Color(0xFF3B3F52), const Color(0xFF59627A));
    final glow = 0.8 + 0.2 * math.sin(w.landmarkT * 4);
    final lamp = cam.w2s(p.dx, p.dy, lz + 0.42);
    _p.color = const Color(0xFFFFE28A).withValues(alpha: 0.3 * glow);
    c.drawCircle(lamp, 1.1 * s, _p);
    _cyl(p.dx, p.dy, lz + 0.1, lz + 0.75, 0.42, Color.lerp(const Color(0xFFFFD447), Colors.white, 0.3 * glow)!,
        const Color(0xFFFFF3C4));
    final roofB = cam.w2s(p.dx, p.dy, lz + 0.75), roofT = cam.w2s(p.dx, p.dy, lz + 1.45);
    _poly([roofB.translate(-0.55 * s, 0), roofT, roofB.translate(0.55 * s, 0)], const Color(0xFFC9373C));
    _p.color = const Color(0xFFE5484D);
    c.drawOval(Rect.fromCenter(center: roofB, width: 1.1 * s, height: 0.4 * s), _p);
    _p.color = Pal.gold;
    c.drawCircle(roofT, 0.08 * s, _p);
    _late.add(() => _beams(lamp, 1, const Color(0x66FFF2B0)));
  }

  void _beams(Offset from, int n, Color color) {
    for (var i = 0; i < n; i++) {
      final ang = w.landmarkT * 0.9 + i * math.pi * 2 / n;
      final dir = Offset(math.cos(ang), math.sin(ang) * 0.55);
      final perp = Offset(-dir.dy, dir.dx);
      final far = from + dir * 7 * s;
      final paint = Paint()..shader = ui.Gradient.linear(from, far, [color, color.withValues(alpha: 0)]);
      c.drawPath(
          Path()
            ..moveTo(from.dx, from.dy)
            ..lineTo(far.dx + perp.dx * 1.4 * s, far.dy + perp.dy * 1.4 * s)
            ..lineTo(far.dx - perp.dx * 1.4 * s, far.dy - perp.dy * 1.4 * s)
            ..close(),
          paint);
    }
  }

  void _spire() {
    const p = landmarkPos;
    final t = w.landmarkT;
    _shadow(cam.w2s(p.dx + 0.4, p.dy + 0.4, 0), 2.4 * s, 1.0 * s, 0.14);
    _cyl(p.dx, p.dy, 0, 0.5, 0.95, const Color(0xFF8E98AE), const Color(0xFFC6CDDA));
    final base = cam.w2s(p.dx, p.dy, 0.5);
    final glow = 0.75 + 0.25 * math.sin(t * 3);
    _p.color = const Color(0xFF7FE7FF).withValues(alpha: 0.22 * glow);
    c.drawCircle(base.translate(0, -2.2 * s), 2.0 * s, _p);
    final h = 4.6 * s, wd = 0.62 * s;
    final tip = base.translate(0, -h);
    _poly([base.translate(-wd, 0), base.translate(-wd * 0.6, -h * 0.82), tip, base.translate(0, 0.12 * s)], const Color(0xFFB8F0FF));
    _poly([base.translate(0, 0.12 * s), tip, base.translate(wd * 0.6, -h * 0.82), base.translate(wd, 0)], const Color(0xFF55BDE8));
    _poly([base.translate(-wd * 0.25, -0.2 * s), base.translate(-wd * 0.15, -h * 0.7), tip, base.translate(0, -0.2 * s)],
        Colors.white.withValues(alpha: 0.45));
    _crystalCluster(base.translate(-0.55 * s, 0.1 * s), s * 0.9, const Color(0xFF9BE3FA), const Color(0xFF45A8D8));
    _crystalCluster(base.translate(0.6 * s, 0.15 * s), s * 0.8, const Color(0xFF7CF7C2), const Color(0xFF2FBF86));
    for (var i = 0; i < 5; i++) {
      final a = t * 0.8 + i * math.pi * 2 / 5;
      final o = Offset(math.cos(a) * 1.1 * s, math.sin(a) * 0.45 * s - (2.6 + math.sin(t * 2 + i) * 0.3) * s);
      final sp = base + o;
      _poly([sp.translate(0, -0.18 * s), sp.translate(0.1 * s, 0), sp.translate(0, 0.18 * s), sp.translate(-0.1 * s, 0)],
          i.isEven ? const Color(0xFFB8F0FF) : const Color(0xFF7CF7C2));
    }
    _late.add(() => _beams(tip.translate(0, 0.3 * s), 3, const Color(0x5590E8FF)));
  }

  void _hearth() {
    const p = landmarkPos;
    final t = w.landmarkT;
    _shadow(cam.w2s(p.dx, p.dy, 0), 2.6 * s, 1.3 * s, 0.14);
    final base = cam.w2s(p.dx, p.dy, 0.1);
    _p.color = const Color(0xFFFFB347).withValues(alpha: 0.2 + 0.06 * math.sin(t * 5));
    c.drawCircle(base.translate(0, -1.2 * s), 2.4 * s, _p);
    _stoneRing(p, false);
    for (var i = 0; i < 6; i++) {
      final a = i / 6 * math.pi;
      final d = Offset(math.cos(a), math.sin(a) * 0.5) * 0.75 * s;
      _ps.color = i.isEven ? Pal.bark : Pal.barkLight;
      _ps.strokeWidth = 0.22 * s;
      c.drawLine(base - d, base + d - Offset(0, 0.5 * s), _ps);
    }
    _flames(base.translate(0, -0.1 * s), 5, 0.26 * s, 1.0);
    _flames(base.translate(0, -0.2 * s), 3, 0.22 * s, 1.5);
    for (var i = 0; i < 10; i++) {
      final ph = (t * 0.6 + _h1(i + 600)) % 1.0;
      final ep = base.translate((_h1(i + 610) - 0.5) * 1.2 * s + math.sin(t * 2 + i) * 0.15 * s, -(0.8 + ph * 3.0) * s);
      _p.color = const Color(0xFFFFB347).withValues(alpha: 1 - ph);
      c.drawCircle(ep, 0.05 * s * (1 - ph * 0.5), _p);
    }
    _stoneRing(p, true);
  }

  // ----------------------------------------------------------- characters
  void _playerRing() {
    final p = w.player;
    final g = cam.w2s(p.pos.dx, p.pos.dy, w.groundZ(p.pos) + 0.01);
    _ps.color = Colors.white.withValues(alpha: 0.7);
    _ps.strokeWidth = 0.05 * s;
    c.drawOval(Rect.fromCenter(center: g, width: 1.3 * s, height: 0.92 * s), _ps);
    final tgt = w.guideTarget();
    if (tgt != null && (tgt - p.pos).distance > 2.2) {
      final d = cam.worldDirToScreen(tgt - p.pos);
      final dn = d / math.max(1e-6, d.distance);
      final tip = g + Offset(dn.dx * 0.95 * s, dn.dy * 0.75 * s);
      final perp = Offset(-dn.dy, dn.dx);
      _p.color = const Color(0xFFFFD447);
      c.drawPath(
          Path()
            ..moveTo(tip.dx + dn.dx * 0.22 * s, tip.dy + dn.dy * 0.22 * s)
            ..lineTo(tip.dx + perp.dx * 0.17 * s, tip.dy + perp.dy * 0.17 * s)
            ..lineTo(tip.dx - perp.dx * 0.17 * s, tip.dy - perp.dy * 0.17 * s)
            ..close(),
          _p);
    }
  }

  void _actor(Actor a) {
    final sc = _easeOutBack(a.pop);
    final z = w.groundZ(a.pos);
    final stackFirst = a.carry.isNotEmpty && (a.stackPos.dx + a.stackPos.dy) < (a.pos.dx + a.pos.dy);
    if (stackFirst) _stack(a, z);
    var action = a.action;
    var tool = a.look.tool;
    if (identical(a, w.player) && !w.isRiver && a.action > 0) {
      tool = src == SourceKind.quarry ? 3 : 4;
    }
    for (final pr in w.processors) {
      if (identical(pr.chef, a)) {
        action = pr.working != null ? (math.sin(pr.anim * 14) * 0.5 + 0.5) : 0;
      }
    }
    _person(a.pos, z, a.facing, a.walk, a.move, a.look,
        sc: sc, action: action, carrying: a.carry.isNotEmpty || a.inbound.isNotEmpty, tool: tool);
    if (!stackFirst) _stack(a, z);
  }

  void _stack(Actor a, double z) {
    if (a.carry.isEmpty) return;
    final base = a.stackPos;
    final sv = cam.worldDirToScreen(a.vel);
    var zz = z + 0.55;
    for (var i = 0; i < a.carry.length; i++) {
      final sp = cam.w2s(base.dx, base.dy, zz);
      zz += itemH(a.carry[i]);
      final lag = i * i * 0.0011;
      _itemS(a.carry[i], sp.translate(-sv.dx * lag * s * 0.12, 0),
          ang: catOf(a.carry[i]) == Cat.raw ? (_h1(i + 7) - 0.5) * 0.2 : 0);
    }
  }

  void _person(Offset pos, double z, double facing, double walk, double move, Look lk,
      {double sc = 1,
      double hop = 0,
      double action = 0,
      bool carrying = false,
      bool simple = false,
      int tool = 0,
      Offset? at,
      bool shadow = true}) {
    if (sc <= 0.01) return;
    final q = s * sc;
    final g = at ?? cam.w2s(pos.dx, pos.dy, z);
    if (at == null && !_vis(g, 2 * q)) return;
    final f = g.translate(0, -hop * s * kZ);
    if (shadow) _shadow(g, 0.82 * q, 0.38 * q, 0.17);
    final fd = cam.worldDirToScreen(Offset(math.cos(facing), math.sin(facing)));
    final fl = math.max(1e-6, fd.distance);
    final fx = fd.dx / fl, fy = fd.dy / fl;
    final front = fy > -0.3;
    final sw = math.sin(walk) * move;
    if (!simple) {
      _p.color = lk.pants;
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: f.translate(-0.15 * q, -0.16 * q - sw * 0.06 * q), width: 0.21 * q, height: 0.32 * q),
              Radius.circular(0.1 * q)),
          _p);
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: f.translate(0.15 * q, -0.16 * q + sw * 0.06 * q), width: 0.21 * q, height: 0.32 * q),
              Radius.circular(0.1 * q)),
          _p);
    }
    if (!front && tool > 0) _tool(tool, f, q, fx, action);
    final bc = f.translate(0, -0.64 * q);
    _p.color = lk.coatDark;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: bc, width: 0.84 * q, height: 0.86 * q), Radius.circular(0.38 * q)), _p);
    _p.color = lk.coat;
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: bc.translate(-0.05 * q, -0.04 * q), width: 0.7 * q, height: 0.76 * q),
            Radius.circular(0.33 * q)),
        _p);
    _p.color = lk.trim;
    c.drawOval(Rect.fromCenter(center: f.translate(0, -0.27 * q), width: 0.86 * q, height: 0.2 * q), _p);
    if (!simple && front) {
      _p.color = darken(lk.coat, 0.3).withValues(alpha: 0.55);
      c.drawRect(Rect.fromCenter(center: bc.translate(fx * 0.1 * q, 0.02 * q), width: 0.04 * q, height: 0.5 * q), _p);
    }
    if (!simple) {
      _p.color = lk.coatDark;
      if (carrying) {
        final ax = fx * 0.14 * q;
        c.drawOval(Rect.fromCenter(center: f.translate(-0.3 * q + ax, -0.74 * q), width: 0.22 * q, height: 0.3 * q), _p);
        c.drawOval(Rect.fromCenter(center: f.translate(0.3 * q + ax, -0.74 * q), width: 0.22 * q, height: 0.3 * q), _p);
      } else {
        final up = action * 0.3 * q;
        c.drawOval(Rect.fromCenter(center: f.translate(-0.44 * q, -0.6 * q + sw * 0.07 * q), width: 0.21 * q, height: 0.42 * q), _p);
        c.drawOval(
            Rect.fromCenter(center: f.translate(0.44 * q + fx * 0.05 * q, -0.62 * q - sw * 0.07 * q - up), width: 0.21 * q, height: 0.42 * q),
            _p);
      }
    }
    if (lk.scarf != null && !simple) {
      _p.color = lk.scarf!;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: f.translate(0, -0.99 * q), width: 0.68 * q, height: 0.18 * q), Radius.circular(0.09 * q)),
          _p);
      final tx = -fx * 0.22 * q + 0.12 * q;
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: f.translate(tx, -0.82 * q + math.sin(walk * 1.3) * 0.03 * q), width: 0.15 * q, height: 0.32 * q),
              Radius.circular(0.07 * q)),
          _p);
    }
    final hc = f.translate(0, -1.2 * q);
    if (lk.hatKind == 3) {
      _p.color = lk.coat;
      c.drawCircle(hc, 0.44 * q, _p);
      if (front) {
        _p.color = lk.trim;
        c.drawCircle(hc.translate(fx * 0.04 * q, 0.03 * q), 0.35 * q, _p);
      } else {
        _p.color = lk.coatDark.withValues(alpha: 0.55);
        c.drawOval(Rect.fromCenter(center: hc.translate(0.08 * q, 0.1 * q), width: 0.62 * q, height: 0.6 * q), _p);
        _ps.color = lk.coatDark;
        _ps.strokeWidth = 0.04 * q;
        c.drawLine(hc.translate(0, -0.42 * q), hc.translate(0, 0.3 * q), _ps);
        _p.color = lk.trim;
        c.drawOval(Rect.fromCenter(center: hc.translate(0, 0.38 * q), width: 0.62 * q, height: 0.14 * q), _p);
      }
    } else {
      _p.color = lk.trim;
      c.drawCircle(hc.translate(0, 0.06 * q), 0.36 * q, _p);
    }
    if (front) {
      final fc = hc.translate(fx * 0.07 * q, 0.04 * q);
      _p.color = lk.skin;
      c.drawCircle(fc, 0.27 * q, _p);
      _p.color = Pal.ink;
      final ex = fx * 0.06 * q;
      c.drawOval(Rect.fromCenter(center: fc.translate(-0.095 * q + ex, -0.01 * q), width: 0.065 * q, height: 0.095 * q), _p);
      c.drawOval(Rect.fromCenter(center: fc.translate(0.095 * q + ex, -0.01 * q), width: 0.065 * q, height: 0.095 * q), _p);
      if (!simple) {
        _p.color = const Color(0x66FF6F86);
        c.drawCircle(fc.translate(-0.16 * q + ex, 0.08 * q), 0.045 * q, _p);
        c.drawCircle(fc.translate(0.16 * q + ex, 0.08 * q), 0.045 * q, _p);
      }
    } else if (lk.hatKind != 3) {
      _p.color = darken(lk.trim, 0.12);
      c.drawCircle(hc.translate(0, 0.02 * q), 0.27 * q, _p);
    }
    switch (lk.hatKind) {
      case 0:
        final top = hc.translate(0, -0.12 * q);
        _p.color = lk.hat;
        c.drawArc(Rect.fromCenter(center: top, width: 0.66 * q, height: 0.6 * q), math.pi, math.pi, true, _p);
        _p.color = lighten(lk.hat, 0.35);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: top, width: 0.72 * q, height: 0.15 * q), Radius.circular(0.07 * q)), _p);
        _p.color = Colors.white;
        c.drawCircle(top.translate(0, -0.33 * q), 0.1 * q, _p);
      case 1:
        _p.color = Colors.white;
        c.drawRect(Rect.fromLTWH(hc.dx - 0.2 * q, hc.dy - 0.62 * q, 0.4 * q, 0.38 * q), _p);
        c.drawCircle(hc.translate(-0.15 * q, -0.62 * q), 0.16 * q, _p);
        c.drawCircle(hc.translate(0.15 * q, -0.62 * q), 0.16 * q, _p);
        c.drawCircle(hc.translate(0, -0.72 * q), 0.18 * q, _p);
        _p.color = const Color(0xFFDDE3EC);
        c.drawRect(Rect.fromLTWH(hc.dx - 0.21 * q, hc.dy - 0.31 * q, 0.42 * q, 0.07 * q), _p);
      case 2:
        _p.color = lk.hat;
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: hc.translate(0, -0.27 * q), width: 0.74 * q, height: 0.34 * q), Radius.circular(0.16 * q)),
            _p);
        _p.color = lighten(lk.hat, 0.25);
        c.drawOval(Rect.fromCenter(center: hc.translate(0, -0.41 * q), width: 0.6 * q, height: 0.18 * q), _p);
      case 4:
        final top = hc.translate(0, -0.1 * q);
        _p.color = lk.hat;
        c.drawArc(Rect.fromCenter(center: top, width: 0.74 * q, height: 0.66 * q), math.pi, math.pi, true, _p);
        _p.color = darken(lk.hat, 0.2);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: top, width: 0.86 * q, height: 0.12 * q), Radius.circular(0.06 * q)), _p);
        if (front) {
          final lamp = top.translate(fx * 0.12 * q, -0.18 * q);
          _p.color = const Color(0xFFFFF3B0).withValues(alpha: 0.35);
          c.drawCircle(lamp, 0.18 * q, _p);
          _p.color = const Color(0xFFFFF3B0);
          c.drawCircle(lamp, 0.08 * q, _p);
        }
      default:
        break;
    }
    if (front && tool > 0) _tool(tool, f, q, fx, action);
  }

  /// Hand tools: 1 harpoon, 2 ladle, 3 pickaxe, 4 axe, 5 hammer, 6 coin bag.
  void _tool(int tool, Offset f, double q, double fx, double action) {
    final side = fx >= 0 ? 1.0 : -1.0;
    switch (tool) {
      case 1:
        final b = f.translate(side * 0.5 * q, -0.35 * q);
        final t = f.translate(side * (0.5 + action * 0.25) * q, -(1.75 + action * 0.1) * q);
        _ps.color = const Color(0xFF8A5A3B);
        _ps.strokeWidth = 0.07 * q;
        c.drawLine(b, t, _ps);
        _p.color = const Color(0xFFC9D3E3);
        c.drawPath(
            Path()
              ..moveTo(t.dx, t.dy - 0.22 * q)
              ..lineTo(t.dx - 0.08 * q, t.dy + 0.02 * q)
              ..lineTo(t.dx + 0.08 * q, t.dy + 0.02 * q)
              ..close(),
            _p);
      case 2:
        final hand = f.translate(0.32 * q + fx * 0.1 * q, -0.7 * q - action * 0.18 * q);
        _ps.color = const Color(0xFF8D99AE);
        _ps.strokeWidth = 0.07 * q;
        c.drawLine(hand, hand.translate(0.25 * q, 0.12 * q + action * 0.1 * q), _ps);
        _p.color = const Color(0xFFB8C2D6);
        c.drawOval(Rect.fromCenter(center: hand.translate(0.3 * q, 0.15 * q + action * 0.1 * q), width: 0.2 * q, height: 0.1 * q), _p);
      case 3 || 4 || 5:
        final pivot = f.translate(side * 0.42 * q, -0.72 * q);
        final ang = side * (-0.35 - 1.6 * action + 0.9 * (1 - action));
        final dir = Offset(math.sin(ang), -math.cos(ang));
        final top = pivot + dir * 0.78 * q;
        _ps.color = const Color(0xFF8A5A3B);
        _ps.strokeWidth = 0.08 * q;
        c.drawLine(pivot - dir * 0.08 * q, top, _ps);
        final perp = Offset(-dir.dy, dir.dx);
        _p.color = const Color(0xFFB8C2D6);
        if (tool == 3) {
          _ps.color = const Color(0xFF9AA5BA);
          _ps.strokeWidth = 0.09 * q;
          c.drawPath(
              Path()
                ..moveTo(top.dx - perp.dx * 0.32 * q + dir.dx * -0.05 * q, top.dy - perp.dy * 0.32 * q + dir.dy * -0.05 * q)
                ..quadraticBezierTo(top.dx + dir.dx * 0.1 * q, top.dy + dir.dy * 0.1 * q, top.dx + perp.dx * 0.32 * q - dir.dx * 0.05 * q,
                    top.dy + perp.dy * 0.32 * q - dir.dy * 0.05 * q),
              _ps);
        } else if (tool == 4) {
          c.drawPath(
              Path()
                ..moveTo(top.dx - dir.dx * 0.05 * q, top.dy - dir.dy * 0.05 * q)
                ..lineTo(top.dx + perp.dx * side * 0.26 * q + dir.dx * 0.08 * q, top.dy + perp.dy * side * 0.26 * q + dir.dy * 0.08 * q)
                ..lineTo(top.dx + perp.dx * side * 0.26 * q - dir.dx * 0.22 * q, top.dy + perp.dy * side * 0.26 * q - dir.dy * 0.22 * q)
                ..lineTo(top.dx - dir.dx * 0.22 * q, top.dy - dir.dy * 0.22 * q)
                ..close(),
              _p);
        } else {
          _p.color = const Color(0xFF6B7591);
          c.drawPath(
              Path()
                ..moveTo(top.dx - perp.dx * 0.16 * q, top.dy - perp.dy * 0.16 * q)
                ..lineTo(top.dx + perp.dx * 0.16 * q, top.dy + perp.dy * 0.16 * q)
                ..lineTo(top.dx + perp.dx * 0.16 * q - dir.dx * 0.16 * q, top.dy + perp.dy * 0.16 * q - dir.dy * 0.16 * q)
                ..lineTo(top.dx - perp.dx * 0.16 * q - dir.dx * 0.16 * q, top.dy - perp.dy * 0.16 * q - dir.dy * 0.16 * q)
                ..close(),
              _p);
        }
      case 6:
        final bag = f.translate(side * 0.5 * q, -0.45 * q - action * 0.1 * q);
        _p.color = const Color(0xFF8A5A3B);
        c.drawOval(Rect.fromCenter(center: bag, width: 0.42 * q, height: 0.46 * q), _p);
        _p.color = const Color(0xFF6B4226);
        c.drawRect(Rect.fromCenter(center: bag.translate(0, -0.22 * q), width: 0.16 * q, height: 0.08 * q), _p);
        _coinIcon(bag.translate(0, 0.03 * q), 0.1 * q);
    }
  }

  void _enemy(Enemy e) {
    switch (w.region.enemy) {
      case EnemyKind.wolf:
        _wolf(e);
      case EnemyKind.golem:
        _golem(e);
      case EnemyKind.yeti:
        _yeti(e);
    }
    final big = e.boss ? 1.9 : 1.0;
    final g = cam.w2s(e.pos.dx, e.pos.dy, 0);
    final st = e.stolen;
    if (st.isNotEmpty) _itemS(st.first, g.translate(0, -1.0 * s * big), sc: 0.8);
    final hb = g.translate(0, -(e.boss ? 2.9 : 1.55) * s);
    final frac = (e.hp / e.maxHp).clamp(0.0, 1.0);
    final boss = e.boss;
    _late.add(() => _hpBar(hb, frac, wide: boss));
  }

  void _crown(Offset head, double q) {
    _p.color = Pal.gold;
    c.drawPath(
        Path()
          ..moveTo(head.dx - 0.22 * q, head.dy)
          ..lineTo(head.dx - 0.22 * q, head.dy - 0.2 * q)
          ..lineTo(head.dx - 0.11 * q, head.dy - 0.08 * q)
          ..lineTo(head.dx, head.dy - 0.26 * q)
          ..lineTo(head.dx + 0.11 * q, head.dy - 0.08 * q)
          ..lineTo(head.dx + 0.22 * q, head.dy - 0.2 * q)
          ..lineTo(head.dx + 0.22 * q, head.dy)
          ..close(),
        _p);
    _p.color = const Color(0xFFE5484D);
    c.drawCircle(head.translate(0, -0.06 * q), 0.04 * q, _p);
  }

  void _wolf(Enemy wf) {
    final q = s * (wf.boss ? 1.9 : 1.0);
    final g = cam.w2s(wf.pos.dx, wf.pos.dy, 0);
    if (!_vis(g, 2 * q)) return;
    _shadow(g, 1.3 * q, 0.45 * q, 0.2);
    final dir = cam.worldDirToScreen(Offset(math.cos(wf.facing), math.sin(wf.facing)));
    final flip = dir.dx < 0 ? -1.0 : 1.0;
    final body = wf.boss ? const Color(0xFF7F95C2) : const Color(0xFFB9CBEA);
    final shade = wf.boss ? const Color(0xFF4F6491) : const Color(0xFF7489B5);
    const outline = Color(0xFF34436B);
    c.save();
    c.translate(g.dx, g.dy);
    c.scale(flip, 1);
    final run = math.sin(wf.phase);
    _ps.color = shade;
    _ps.strokeWidth = 0.13 * q;
    for (var i = 0; i < 4; i++) {
      final lx = (i < 2 ? -0.32 : 0.3) * q + (i.isOdd ? 0.1 * q : 0);
      final sw = (i.isEven ? run : -run) * 0.14 * q;
      c.drawLine(Offset(lx, -0.45 * q), Offset(lx + sw, -0.06 * q), _ps);
    }
    _p.color = shade;
    c.save();
    c.translate(-0.52 * q, -0.62 * q);
    c.rotate(-0.6 + run * 0.15);
    c.drawOval(Rect.fromCenter(center: Offset(-0.22 * q, 0), width: 0.55 * q, height: 0.22 * q), _p);
    c.restore();
    final hc = Offset(0.52 * q, -0.84 * q + run * 0.03 * q);
    _p.color = outline;
    c.drawOval(Rect.fromCenter(center: Offset(0, -0.58 * q + run * 0.02 * q), width: 1.2 * q, height: 0.58 * q), _p);
    c.drawCircle(hc, 0.29 * q, _p);
    c.drawOval(Rect.fromCenter(center: hc.translate(0.24 * q, 0.06 * q), width: 0.4 * q, height: 0.28 * q), _p);
    _p.color = body;
    c.drawOval(Rect.fromCenter(center: Offset(0, -0.58 * q + run * 0.02 * q), width: 1.12 * q, height: 0.5 * q), _p);
    _p.color = shade.withValues(alpha: 0.6);
    c.drawOval(Rect.fromCenter(center: Offset(-0.05 * q, -0.48 * q), width: 0.85 * q, height: 0.2 * q), _p);
    _p.color = body;
    c.drawCircle(hc, 0.25 * q, _p);
    c.drawOval(Rect.fromCenter(center: hc.translate(0.24 * q, 0.06 * q), width: 0.32 * q, height: 0.2 * q), _p);
    _p.color = shade;
    for (final ex in [-0.1, 0.08]) {
      c.drawPath(
          Path()
            ..moveTo(hc.dx + ex * q - 0.07 * q, hc.dy - 0.16 * q)
            ..lineTo(hc.dx + ex * q, hc.dy - 0.42 * q)
            ..lineTo(hc.dx + ex * q + 0.08 * q, hc.dy - 0.15 * q)
            ..close(),
          _p);
    }
    _p.color = Pal.ink;
    c.drawCircle(hc.translate(0.39 * q, 0.04 * q), 0.045 * q, _p);
    _p.color = const Color(0xFF6FF0FF);
    c.drawCircle(hc.translate(0.08 * q, -0.04 * q), 0.055 * q, _p);
    _p.color = const Color(0x556FF0FF);
    c.drawCircle(hc.translate(0.08 * q, -0.04 * q), 0.11 * q, _p);
    if (wf.boss) _crown(hc.translate(-0.02 * q, -0.32 * q), q);
    if (wf.flash > 0) {
      _p.color = Colors.white.withValues(alpha: wf.flash * 0.85);
      c.drawOval(Rect.fromCenter(center: Offset(0.1 * q, -0.62 * q), width: 1.5 * q, height: 0.75 * q), _p);
    }
    c.restore();
  }

  void _golem(Enemy e) {
    final q = s * (e.boss ? 1.7 : 1.0);
    final g = cam.w2s(e.pos.dx, e.pos.dy, 0);
    if (!_vis(g, 3 * q)) return;
    _shadow(g, 1.3 * q, 0.55 * q, 0.22);
    final step = math.sin(e.phase);
    final bob = step.abs() * 0.06 * q;
    final body = e.boss ? const Color(0xFF6FA8F2) : const Color(0xFFA9DDF7);
    final mid = e.boss ? const Color(0xFF4B86D6) : const Color(0xFF7CC3EA);
    final dark = e.boss ? const Color(0xFF2F64B8) : const Color(0xFF4FA3D6);
    const outline = Color(0xFF26406E);
    void block(Rect r) {
      _p.color = outline;
      c.drawRRect(RRect.fromRectAndRadius(r.inflate(0.04 * q), Radius.circular(0.1 * q)), _p);
      _p.color = mid;
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(0.08 * q)), _p);
      _p.color = body;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left, r.top, r.width * 0.62, r.height * 0.9), Radius.circular(0.08 * q)), _p);
      _p.color = dark.withValues(alpha: 0.5);
      c.drawRect(Rect.fromLTWH(r.right - r.width * 0.18, r.top + r.height * 0.1, r.width * 0.12, r.height * 0.8), _p);
    }

    final f = g.translate(0, -bob);
    block(Rect.fromCenter(center: f.translate(-0.22 * q, -0.2 * q + step * 0.04 * q), width: 0.3 * q, height: 0.4 * q));
    block(Rect.fromCenter(center: f.translate(0.22 * q, -0.2 * q - step * 0.04 * q), width: 0.3 * q, height: 0.4 * q));
    block(Rect.fromCenter(center: f.translate(0, -0.85 * q), width: 1.05 * q, height: 0.85 * q));
    block(Rect.fromCenter(center: f.translate(-0.68 * q, -0.75 * q + step * 0.1 * q), width: 0.32 * q, height: 0.7 * q));
    block(Rect.fromCenter(center: f.translate(0.68 * q, -0.75 * q - step * 0.1 * q), width: 0.32 * q, height: 0.7 * q));
    final head = f.translate(0, -1.55 * q);
    block(Rect.fromCenter(center: head, width: 0.62 * q, height: 0.52 * q));
    _p.color = const Color(0xFF6FF0FF);
    c.drawCircle(head.translate(-0.13 * q, 0), 0.06 * q, _p);
    c.drawCircle(head.translate(0.13 * q, 0), 0.06 * q, _p);
    _p.color = const Color(0x446FF0FF);
    c.drawCircle(head.translate(-0.13 * q, 0), 0.13 * q, _p);
    c.drawCircle(head.translate(0.13 * q, 0), 0.13 * q, _p);
    _prism(f.translate(-0.25 * q, -1.22 * q), -0.4, 0.3 * q, 0.07 * q, const Color(0xFFDDF6FF), const Color(0xFF8FD3F0));
    _prism(f.translate(0.3 * q, -1.2 * q), 0.45, 0.26 * q, 0.07 * q, const Color(0xFFDDF6FF), const Color(0xFF8FD3F0));
    if (e.boss) _crown(head.translate(0, -0.27 * q), q);
    if (e.flash > 0) {
      _p.color = Colors.white.withValues(alpha: e.flash * 0.8);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: f.translate(0, -0.9 * q), width: 1.6 * q, height: 1.7 * q), Radius.circular(0.2 * q)),
          _p);
    }
  }

  void _yeti(Enemy e) {
    final q = s * (e.boss ? 1.75 : 1.0);
    final g = cam.w2s(e.pos.dx, e.pos.dy, 0);
    if (!_vis(g, 3 * q)) return;
    _shadow(g, 1.25 * q, 0.5 * q, 0.22);
    final dir = cam.worldDirToScreen(Offset(math.cos(e.facing), math.sin(e.facing)));
    final fx = dir.dx / math.max(1e-6, dir.distance);
    final step = math.sin(e.phase);
    final fur = e.boss ? const Color(0xFFC9CED9) : const Color(0xFFF4F6FA);
    final furDark = e.boss ? const Color(0xFF8E96A8) : const Color(0xFFC9D1E0);
    const outline = Color(0xFF4A5470);
    final f = g.translate(0, -step.abs() * 0.05 * q);
    _p.color = outline;
    c.drawOval(Rect.fromCenter(center: f.translate(-0.2 * q, -0.15 * q + step * 0.05 * q), width: 0.36 * q, height: 0.32 * q), _p);
    c.drawOval(Rect.fromCenter(center: f.translate(0.2 * q, -0.15 * q - step * 0.05 * q), width: 0.36 * q, height: 0.32 * q), _p);
    _p.color = furDark;
    c.drawOval(Rect.fromCenter(center: f.translate(-0.2 * q, -0.17 * q + step * 0.05 * q), width: 0.3 * q, height: 0.26 * q), _p);
    c.drawOval(Rect.fromCenter(center: f.translate(0.2 * q, -0.17 * q - step * 0.05 * q), width: 0.3 * q, height: 0.26 * q), _p);
    final body = Rect.fromCenter(center: f.translate(0, -0.9 * q), width: 1.05 * q, height: 1.3 * q);
    _p.color = outline;
    c.drawOval(body.inflate(0.05 * q), _p);
    _p.color = furDark;
    c.drawOval(body, _p);
    _p.color = fur;
    c.drawOval(Rect.fromLTWH(body.left, body.top, body.width * 0.85, body.height * 0.92), _p);
    for (final sd in [-1.0, 1.0]) {
      final sh = f.translate(sd * 0.45 * q, -1.15 * q);
      final hand = sh.translate(sd * 0.2 * q, (0.75 + sd * step * 0.15) * q);
      _ps.color = outline;
      _ps.strokeWidth = 0.32 * q;
      c.drawLine(sh, hand, _ps);
      _ps.color = furDark;
      _ps.strokeWidth = 0.24 * q;
      c.drawLine(sh, hand, _ps);
      _p.color = const Color(0xFF6E7FA6);
      c.drawCircle(hand, 0.11 * q, _p);
    }
    final face = f.translate(fx * 0.12 * q, -1.15 * q);
    _p.color = const Color(0xFF8DA3D1);
    c.drawOval(Rect.fromCenter(center: face, width: 0.52 * q, height: 0.42 * q), _p);
    _p.color = Pal.ink;
    c.drawCircle(face.translate(-0.11 * q, -0.04 * q), 0.045 * q, _p);
    c.drawCircle(face.translate(0.11 * q, -0.04 * q), 0.045 * q, _p);
    _p.color = const Color(0xFF34436B);
    c.drawOval(Rect.fromCenter(center: face.translate(0, 0.1 * q), width: 0.2 * q, height: 0.08 * q), _p);
    _p.color = Colors.white;
    c.drawRect(Rect.fromLTWH(face.dx - 0.06 * q, face.dy + 0.07 * q, 0.04 * q, 0.04 * q), _p);
    c.drawRect(Rect.fromLTWH(face.dx + 0.02 * q, face.dy + 0.07 * q, 0.04 * q, 0.04 * q), _p);
    _p.color = const Color(0xFFDDE3EC);
    for (final sd in [-1.0, 1.0]) {
      c.drawPath(
          Path()
            ..moveTo(f.dx + sd * 0.2 * q, f.dy - 1.5 * q)
            ..quadraticBezierTo(f.dx + sd * 0.42 * q, f.dy - 1.62 * q, f.dx + sd * 0.38 * q, f.dy - 1.85 * q)
            ..lineTo(f.dx + sd * 0.28 * q, f.dy - 1.55 * q)
            ..close(),
          _p);
    }
    if (e.boss) _crown(f.translate(0, -1.6 * q), q);
    if (e.flash > 0) {
      _p.color = Colors.white.withValues(alpha: e.flash * 0.8);
      c.drawOval(body.inflate(0.1 * q), _p);
    }
  }

  // =========================================================== items
  void _itemS(Item it, Offset p, {double ang = 0, double sc = 1}) {
    switch (it) {
      case Item.fish || Item.goldFish || Item.bigFish:
        _fishS(p.translate(0, -0.07 * s * sc), it, ang, sc: sc);
      case Item.cake:
        _cakeS(p, sc: sc);
      case Item.chowder:
        _bowlS(p, sc: sc);
      case Item.ore || Item.auroraOre || Item.bigOre:
        _oreS(p, it, sc: sc);
      case Item.ingot:
        _ingotS(p, sc: sc);
      case Item.lamp:
        _lampS(p, sc: sc);
      case Item.log || Item.goldLog || Item.bigLog:
        _logS(p, it, ang: ang, sc: sc);
      case Item.firewood:
        _firewoodS(p, sc: sc);
      case Item.sled:
        _sledS(p, sc: sc);
    }
  }

  void _fishS(Offset p, Item kind, double ang, {double sc = 1, double alpha = 1, double flash = 0, double cook = 0}) {
    final len = s *
        sc *
        switch (kind) {
          Item.bigFish => 1.3,
          Item.goldFish => 0.82,
          _ => 0.92,
        };
    var body = switch (kind) {
      Item.goldFish => const Color(0xFFF2B705),
      Item.bigFish => const Color(0xFF34557F),
      _ => const Color(0xFF5B7FAA),
    };
    var belly = switch (kind) {
      Item.goldFish => const Color(0xFFFFE89A),
      Item.bigFish => const Color(0xFFC6D5E8),
      _ => const Color(0xFFE2ECF7),
    };
    if (cook > 0) {
      body = Color.lerp(body, const Color(0xFFB0662C), cook)!;
      belly = Color.lerp(belly, const Color(0xFFE6A15A), cook)!;
    }
    final fin = darken(body, 0.22);
    final h = len * 0.36;
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(ang);
    _p.color = fin.withValues(alpha: alpha);
    c.drawPath(
        Path()
          ..moveTo(-len * 0.36, 0)
          ..lineTo(-len * 0.62, -h * 0.66)
          ..quadraticBezierTo(-len * 0.5, 0, -len * 0.62, h * 0.66)
          ..close(),
        _p);
    c.drawPath(
        Path()
          ..moveTo(-len * 0.14, -h * 0.4)
          ..quadraticBezierTo(-len * 0.02, -h * 1.0, len * 0.12, -h * 0.42)
          ..close(),
        _p);
    _p.color = body.withValues(alpha: alpha);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: len * 0.92, height: h), _p);
    _p.color = belly.withValues(alpha: alpha);
    c.drawOval(Rect.fromCenter(center: Offset(len * 0.04, h * 0.17), width: len * 0.72, height: h * 0.5), _p);
    if (kind == Item.bigFish) {
      _p.color = const Color(0xFF8FB3DE).withValues(alpha: alpha * 0.7);
      for (var i = 0; i < 3; i++) {
        c.drawCircle(Offset(-len * 0.12 + i * len * 0.12, -h * 0.18), len * 0.03, _p);
      }
    }
    _p.color = Colors.white.withValues(alpha: alpha);
    c.drawCircle(Offset(len * 0.3, -h * 0.08), len * 0.06, _p);
    _p.color = Pal.ink.withValues(alpha: alpha);
    c.drawCircle(Offset(len * 0.315, -h * 0.08), len * 0.033, _p);
    if (kind == Item.goldFish) {
      _ps.color = const Color(0xFFFFF59D).withValues(alpha: (0.6 + 0.3 * math.sin(w.time * 8)) * alpha);
      _ps.strokeWidth = len * 0.05;
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: len * 1.05, height: h * 1.35), _ps);
    }
    if (flash > 0) {
      _p.color = Colors.white.withValues(alpha: flash * 0.8 * alpha);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: len * 0.95, height: h * 1.05), _p);
    }
    c.restore();
  }

  void _discSide(Offset p, Offset top, double rx, double ry, Color col) {
    _p.color = col;
    c.drawPath(
        Path()
          ..moveTo(top.dx - rx, top.dy)
          ..lineTo(p.dx - rx, p.dy)
          ..arcToPoint(Offset(p.dx + rx, p.dy), radius: Radius.elliptical(rx, ry), clockwise: false)
          ..lineTo(top.dx + rx, top.dy)
          ..close(),
        _p);
  }

  void _cakeS(Offset p, {double sc = 1}) {
    final rx = 0.27 * s * sc, ry = rx * 0.7071, hh = 0.09 * s * sc;
    final top = p.translate(0, -hh);
    _discSide(p, top, rx, ry, const Color(0xFFAE5E28));
    _p.color = const Color(0xFFE59A45);
    c.drawOval(Rect.fromCenter(center: top, width: rx * 2, height: ry * 2), _p);
    _p.color = const Color(0xFFF6C46C);
    c.drawOval(Rect.fromCenter(center: top.translate(-rx * 0.12, -ry * 0.1), width: rx * 1.25, height: ry * 1.1), _p);
    _p.color = const Color(0xFF4CAF50);
    c.drawCircle(top.translate(rx * 0.28, ry * 0.12), rx * 0.13, _p);
  }

  void _bowlS(Offset p, {double sc = 1}) {
    final rx = 0.29 * s * sc, ry = rx * 0.7071, hh = 0.16 * s * sc;
    final top = p.translate(0, -hh);
    _p.color = const Color(0xFF8A4F27);
    c.drawPath(
        Path()
          ..moveTo(top.dx - rx, top.dy)
          ..quadraticBezierTo(p.dx - rx * 0.85, p.dy + ry * 0.3, p.dx, p.dy + ry * 0.55)
          ..quadraticBezierTo(p.dx + rx * 0.85, p.dy + ry * 0.3, top.dx + rx, top.dy)
          ..close(),
        _p);
    _p.color = const Color(0xFFC9874F);
    c.drawOval(Rect.fromCenter(center: top, width: rx * 2, height: ry * 2), _p);
    _p.color = const Color(0xFFF7E4B8);
    c.drawOval(Rect.fromCenter(center: top.translate(0, ry * 0.08), width: rx * 1.62, height: ry * 1.5), _p);
    _p.color = const Color(0xFFFF8A3D);
    c.drawCircle(top.translate(-rx * 0.25, ry * 0.15), rx * 0.14, _p);
    _p.color = const Color(0xFF43A047);
    c.drawCircle(top.translate(rx * 0.22, -ry * 0.05), rx * 0.1, _p);
  }

  void _oreS(Offset p, Item kind, {double sc = 1}) {
    final q = s * sc * (kind == Item.bigOre ? 1.25 : 1.0);
    final (Color l, Color m, Color d) = switch (kind) {
      Item.auroraOre => (const Color(0xFFB8FFE1), const Color(0xFF5CF0A8), const Color(0xFF26A774)),
      Item.bigOre => (const Color(0xFFA9CCFF), const Color(0xFF5B8FE0), const Color(0xFF2F5CA8)),
      _ => (const Color(0xFFD6F4FF), const Color(0xFF8FD8F5), const Color(0xFF4FA9D6)),
    };
    final o = p.translate(0, -0.1 * q);
    if (kind == Item.auroraOre) {
      _p.color = m.withValues(alpha: 0.3 + 0.15 * math.sin(w.time * 5));
      c.drawCircle(o, 0.36 * q, _p);
    }
    final pts = [
      o.translate(-0.3 * q, 0.06 * q),
      o.translate(-0.18 * q, -0.14 * q),
      o.translate(0.06 * q, -0.2 * q),
      o.translate(0.3 * q, -0.04 * q),
      o.translate(0.22 * q, 0.12 * q),
      o.translate(-0.08 * q, 0.15 * q),
    ];
    _poly(pts, m);
    _poly([pts[1], pts[2], o.translate(0.04 * q, -0.02 * q), o.translate(-0.14 * q, 0.0)], l);
    _poly([pts[3], pts[4], pts[5], o.translate(0.04 * q, -0.02 * q)], d);
  }

  void _ingotS(Offset p, {double sc = 1}) {
    final q = s * sc;
    final top = [p.translate(-0.24 * q, -0.12 * q), p.translate(0.08 * q, -0.2 * q), p.translate(0.28 * q, -0.12 * q), p.translate(-0.04 * q, -0.04 * q)];
    final bottom = [p.translate(-0.3 * q, 0), p.translate(-0.04 * q, 0.07 * q), p.translate(0.32 * q, -0.02 * q)];
    _poly([top[0], top[3], bottom[1], bottom[0]], const Color(0xFF7FCDEB));
    _poly([top[3], top[2], bottom[2], bottom[1]], const Color(0xFF4FA9D6));
    _poly(top, const Color(0xFFC7F1FF));
    _ps.color = Colors.white.withValues(alpha: 0.8);
    _ps.strokeWidth = math.max(1, 0.03 * q);
    c.drawLine(top[0].translate(0.08 * q, -0.01 * q), top[1].translate(-0.04 * q, 0.03 * q), _ps);
  }

  void _lampS(Offset p, {double sc = 1}) {
    final q = s * sc;
    final glow = 0.75 + 0.25 * math.sin(w.time * 4 + p.dx * 0.05);
    _p.color = const Color(0xFF7FE7FF).withValues(alpha: 0.18 * glow);
    c.drawCircle(p.translate(0, -0.2 * q), 0.34 * q, _p);
    _p.color = const Color(0xFF3B3F52);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: p.translate(0, -0.03 * q), width: 0.36 * q, height: 0.08 * q), Radius.circular(0.03 * q)), _p);
    _p.color = Color.lerp(const Color(0xFF7FE7FF), Colors.white, 0.4 * glow)!;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: p.translate(0, -0.18 * q), width: 0.26 * q, height: 0.24 * q), Radius.circular(0.06 * q)), _p);
    _ps.color = const Color(0xFF3B3F52);
    _ps.strokeWidth = math.max(1, 0.035 * q);
    c.drawLine(p.translate(-0.13 * q, -0.06 * q), p.translate(-0.13 * q, -0.3 * q), _ps);
    c.drawLine(p.translate(0.13 * q, -0.06 * q), p.translate(0.13 * q, -0.3 * q), _ps);
    _p.color = const Color(0xFF3B3F52);
    c.drawPath(
        Path()
          ..moveTo(p.dx - 0.18 * q, p.dy - 0.3 * q)
          ..lineTo(p.dx, p.dy - 0.42 * q)
          ..lineTo(p.dx + 0.18 * q, p.dy - 0.3 * q)
          ..close(),
        _p);
    c.drawArc(Rect.fromCenter(center: p.translate(0, -0.45 * q), width: 0.14 * q, height: 0.12 * q), math.pi, math.pi, false, _ps);
  }

  void _logS(Offset p, Item kind, {double ang = 0, double sc = 1}) {
    final q = s * sc * (kind == Item.bigLog ? 1.2 : 1.0);
    final bark = kind == Item.goldLog ? const Color(0xFFD4A017) : (kind == Item.bigLog ? const Color(0xFF6B3F22) : Pal.barkLight);
    final barkDark = kind == Item.goldLog ? const Color(0xFFA67C00) : (kind == Item.bigLog ? const Color(0xFF4A2A14) : Pal.bark);
    c.save();
    c.translate(p.dx, p.dy - 0.1 * q);
    c.rotate(ang * 0.5);
    final r = Rect.fromCenter(center: Offset.zero, width: 0.78 * q, height: 0.24 * q);
    _p.color = barkDark;
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(0.12 * q)), _p);
    _p.color = bark;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.6), Radius.circular(0.1 * q)), _p);
    _p.color = Pal.ring;
    c.drawOval(Rect.fromCenter(center: Offset(r.right - 0.06 * q, 0), width: 0.16 * q, height: 0.24 * q), _p);
    _ps.color = const Color(0xFFB98454);
    _ps.strokeWidth = math.max(1, 0.02 * q);
    c.drawOval(Rect.fromCenter(center: Offset(r.right - 0.06 * q, 0), width: 0.08 * q, height: 0.13 * q), _ps);
    if (kind == Item.goldLog) {
      _ps.color = const Color(0xFFFFF59D).withValues(alpha: 0.6 + 0.3 * math.sin(w.time * 8));
      _ps.strokeWidth = 0.035 * q;
      c.drawRRect(RRect.fromRectAndRadius(r.inflate(0.04 * q), Radius.circular(0.15 * q)), _ps);
    }
    c.restore();
  }

  void _firewoodS(Offset p, {double sc = 1}) {
    final q = sc * 0.55;
    _logS(p.translate(-0.11 * s * sc, 0.02 * s * sc), Item.log, sc: q);
    _logS(p.translate(0.11 * s * sc, 0.0), Item.log, sc: q);
    _logS(p.translate(0, -0.1 * s * sc), Item.log, sc: q);
    _p.color = const Color(0xFFE5484D);
    c.drawRect(Rect.fromCenter(center: p.translate(-0.02 * s * sc, -0.1 * s * sc), width: 0.05 * s * sc, height: 0.24 * s * sc), _p);
  }

  void _sledS(Offset p, {double sc = 1}) {
    final q = s * sc;
    _ps.color = const Color(0xFF8E2A20);
    _ps.strokeWidth = math.max(1.2, 0.05 * q);
    for (final dy in [-0.02, 0.06]) {
      final b = p.translate(0, dy * q);
      c.drawPath(
          Path()
            ..moveTo(b.dx - 0.32 * q, b.dy)
            ..lineTo(b.dx + 0.26 * q, b.dy)
            ..quadraticBezierTo(b.dx + 0.38 * q, b.dy, b.dx + 0.36 * q, b.dy - 0.12 * q),
          _ps);
    }
    _p.color = Pal.woodLight;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(p.dx - 0.3 * q, p.dy - 0.15 * q, 0.56 * q, 0.1 * q), Radius.circular(0.03 * q)), _p);
    _p.color = Pal.wood;
    c.drawRect(Rect.fromLTWH(p.dx - 0.3 * q, p.dy - 0.08 * q, 0.56 * q, 0.03 * q), _p);
    _ps.color = Pal.woodDark;
    _ps.strokeWidth = math.max(1, 0.025 * q);
    for (var i = 0; i < 4; i++) {
      final x = p.dx - 0.22 * q + i * 0.14 * q;
      c.drawLine(Offset(x, p.dy - 0.15 * q), Offset(x, p.dy - 0.05 * q), _ps);
    }
  }

  void _coinS(Offset p, {double sc = 1}) {
    final rx = 0.2 * s * sc, ry = rx * 0.7071, hh = 0.055 * s * sc;
    final top = p.translate(0, -hh);
    _discSide(p, top, rx, ry, const Color(0xFFC8890F));
    _p.color = const Color(0xFFFFD447);
    c.drawOval(Rect.fromCenter(center: top, width: rx * 2, height: ry * 2), _p);
    _ps.color = const Color(0xFFE9AE1E);
    _ps.strokeWidth = math.max(1, rx * 0.16);
    c.drawOval(Rect.fromCenter(center: top, width: rx * 1.25, height: ry * 1.25), _ps);
  }

  void _coinIcon(Offset o, double r) {
    _p.color = const Color(0xFFC8890F);
    c.drawCircle(o.translate(0, r * 0.18), r, _p);
    _p.color = const Color(0xFFFFD447);
    c.drawCircle(o, r, _p);
    _ps.color = const Color(0xFFE9AE1E);
    _ps.strokeWidth = math.max(1, r * 0.2);
    c.drawCircle(o, r * 0.6, _ps);
  }

  void _gemIcon(Offset o, double r) {
    final pts = [o.translate(0, -r * 1.2), o.translate(r, -r * 0.2), o.translate(0, r * 1.1), o.translate(-r, -r * 0.2)];
    _poly(pts, const Color(0xFF55D6F5));
    _poly([pts[0], pts[1], o.translate(0, -r * 0.1), pts[3]], const Color(0xFFB5F3FF));
    _ps.color = const Color(0xFF1B7FA3);
    _ps.strokeWidth = math.max(1, r * 0.15);
    c.drawPath(Path()..addPolygon(pts, true), _ps);
  }

  // =========================================================== fx
  void _projectiles() {
    for (final p in w.projs) {
      final sp = cam.w2s(p.pos.dx, p.pos.dy, p.z);
      if (!_vis(sp, 40)) continue;
      final g = cam.w2s(p.pos.dx, p.pos.dy, p.target is Fish ? waterZ : 0);
      switch (p.kind) {
        case ProjKind.harpoon:
          final d = cam.worldDirToScreen(p.dir) - Offset(0, p.dz * kZ);
          final dn = d / math.max(1e-6, d.distance);
          _ps.color = const Color(0x33000000);
          _ps.strokeWidth = 0.06 * s;
          c.drawLine(g - dn * 0.4 * s, g + dn * 0.4 * s, _ps);
          final tail = sp - dn * 0.5 * s, tip = sp + dn * 0.42 * s;
          _ps.color = const Color(0xFF8A5A3B);
          _ps.strokeWidth = 0.075 * s;
          c.drawLine(tail, tip, _ps);
          final perp = Offset(-dn.dy, dn.dx);
          _p.color = const Color(0xFFD5DEEB);
          c.drawPath(
              Path()
                ..moveTo(tip.dx + dn.dx * 0.24 * s, tip.dy + dn.dy * 0.24 * s)
                ..lineTo(tip.dx + perp.dx * 0.09 * s, tip.dy + perp.dy * 0.09 * s)
                ..lineTo(tip.dx - perp.dx * 0.09 * s, tip.dy - perp.dy * 0.09 * s)
                ..close(),
              _p);
          _p.color = const Color(0xFFFF6B6B);
          c.drawCircle(tail, 0.06 * s, _p);
        case ProjKind.snowball:
          _shadow(g, 0.3 * s, 0.14 * s, 0.15);
          _p.color = const Color(0xFFCFE3F7);
          c.drawCircle(sp.translate(0.02 * s, 0.02 * s), 0.14 * s, _p);
          _p.color = Colors.white;
          c.drawCircle(sp, 0.12 * s, _p);
        case ProjKind.cannonball:
          _shadow(g, 0.5 * s, 0.24 * s, 0.18);
          _p.color = const Color(0x5599DDFF);
          c.drawCircle(sp, 0.32 * s, _p);
          _p.color = const Color(0xFFBFDDF5);
          c.drawCircle(sp.translate(0.03 * s, 0.03 * s), 0.23 * s, _p);
          _p.color = Colors.white;
          c.drawCircle(sp, 0.2 * s, _p);
      }
    }
  }

  void _flights() {
    for (final f in w.flights) {
      final sp = cam.w2s(f.pos.dx, f.pos.dy, f.z);
      if (!_vis(sp, 40)) continue;
      final it = f.item;
      if (it == null) {
        _coinS(sp, sc: 0.9);
      } else {
        _itemS(it, sp, ang: f.spin * f.t * 9);
      }
    }
  }

  void _particles() {
    for (final p in w.parts) {
      final sp = cam.w2s(p.x, p.y, p.z);
      if (!_vis(sp, 40)) continue;
      final u = (p.life / p.max).clamp(0.0, 1.0);
      switch (p.kind) {
        case PK.puff:
          _p.color = p.color.withValues(alpha: 0.9 * (1 - u));
          c.drawCircle(sp, p.size * s * (0.6 + u * 0.9), _p);
        case PK.spark || PK.splash || PK.ember:
          _p.color = p.color.withValues(alpha: 1 - u * 0.7);
          c.drawCircle(sp, p.size * s * (1 - u * 0.5), _p);
        case PK.chip:
          c.save();
          c.translate(sp.dx, sp.dy);
          c.rotate(p.rot);
          _p.color = p.color.withValues(alpha: 1 - u * 0.6);
          c.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size * s * 1.6, height: p.size * s), _p);
          c.restore();
        case PK.confetti:
          c.save();
          c.translate(sp.dx, sp.dy);
          c.rotate(p.rot);
          _p.color = p.color.withValues(alpha: 1 - math.max(0, u - 0.7) * 3);
          c.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size * s * 1.4, height: p.size * s * 0.8), _p);
          c.restore();
        case PK.steam:
          _p.color = (w.region.source == SourceKind.quarry ? const Color(0xFFB9C2D3) : Colors.white)
              .withValues(alpha: 0.45 * (1 - u));
          c.drawCircle(sp, p.size * s * (0.6 + u * 1.2), _p);
        case PK.ring:
          _ps.color = Colors.white.withValues(alpha: 1 - u);
          _ps.strokeWidth = 0.12 * s * (1 - u) + 1;
          final r = (0.6 + u * 2.6) * s;
          c.drawOval(Rect.fromCenter(center: sp, width: r * 2, height: r * 1.414), _ps);
        case PK.heart:
          final r = p.size * s * 0.5;
          final o = sp.translate(0, -u * 0.6 * s);
          _p.color = p.color.withValues(alpha: 1 - u);
          c.drawCircle(o.translate(-r * 0.5, 0), r * 0.55, _p);
          c.drawCircle(o.translate(r * 0.5, 0), r * 0.55, _p);
          c.drawPath(
              Path()
                ..moveTo(o.dx - r * 1.02, o.dy + r * 0.12)
                ..lineTo(o.dx, o.dy + r * 1.15)
                ..lineTo(o.dx + r * 1.02, o.dy + r * 0.12)
                ..close(),
              _p);
      }
    }
  }

  // =========================================================== world ui
  void _hpBar(Offset p, double f, {bool wide = false}) {
    final wd = (wide ? 1.8 : 0.9) * s, h = (wide ? 0.18 : 0.13) * s;
    final r = Rect.fromCenter(center: p, width: wd, height: h);
    _p.color = const Color(0xB31A1F33);
    c.drawRRect(RRect.fromRectAndRadius(r.inflate(2), Radius.circular(h)), _p);
    _p.color = Color.lerp(const Color(0xFFFF4D4D), const Color(0xFF5BE37D), f)!;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left, r.top, r.width * f, r.height), Radius.circular(h)), _p);
  }

  void _progressRing(Offset ctr, double f, Item product) {
    final r = 0.36 * s;
    _p.color = const Color(0xD91A1F33);
    c.drawCircle(ctr, r + 0.08 * s, _p);
    _ps.color = const Color(0xFF39D98A);
    _ps.strokeWidth = 0.1 * s;
    c.drawArc(Rect.fromCircle(center: ctr, radius: r - 0.02 * s), -math.pi / 2, math.pi * 2 * f.clamp(0.0, 1.0), false, _ps);
    _itemS(product, ctr.translate(0, 0.1 * s), sc: 0.62);
  }

  void _maxBadge(Offset p) {
    final bob = math.sin(w.time * 6) * 0.05 * s;
    final tp = _tp(Tr.t('max'), 0.3 * s, Colors.white);
    final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: p.translate(0, bob), width: tp.width + 0.36 * s, height: tp.height + 0.18 * s), Radius.circular(0.2 * s));
    _p.color = const Color(0xFFE5383B);
    c.drawRRect(r, _p);
    _ps.color = Colors.white;
    _ps.strokeWidth = 0.05 * s;
    c.drawRRect(r, _ps);
    tp.paint(c, r.center - Offset(tp.width / 2, tp.height / 2));
  }

  void _bubble(Offset anchor, Item product, int count) {
    final wd = 1.15 * s, ht = 0.62 * s;
    final ctr = anchor.translate(0, -ht / 2 - 0.12 * s);
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: ctr, width: wd, height: ht), Radius.circular(0.24 * s));
    _p.color = const Color(0x33000000);
    c.drawRRect(r.shift(Offset(0, 0.05 * s)), _p);
    _p.color = Colors.white;
    c.drawRRect(r, _p);
    c.drawPath(
        Path()
          ..moveTo(ctr.dx - 0.12 * s, r.bottom - 1)
          ..lineTo(ctr.dx, r.bottom + 0.16 * s)
          ..lineTo(ctr.dx + 0.12 * s, r.bottom - 1)
          ..close(),
        _p);
    _itemS(product, ctr.translate(-0.24 * s, 0.12 * s), sc: 0.75);
    _text('×$count', ctr.translate(0.25 * s, 0.02 * s), 0.34 * s, Pal.ink);
  }

  void _worldUi() {
    for (final k in w.counters) {
      if (k.queue.isEmpty) continue;
      final cu = k.queue.first;
      if ((cu.pos - k.slots.first).distanceSquared < 0.05 && cu.got < cu.want) {
        final head = cam.w2s(cu.pos.dx, cu.pos.dy, 2.25 + cu.hop);
        _bubble(head, k.product, cu.want - cu.got);
      }
      final slot = (w.time / 3).floor();
      for (var i = 0; i < k.crowd.length; i++) {
        if ((i * 7 + slot) % 11 != 0) continue;
        final cu2 = k.crowd[i];
        final head = cam.w2s(cu2.pos.dx, cu2.pos.dy, 2.2 + cu2.hop);
        if (!_vis(head, 40)) continue;
        _p.color = Colors.white.withValues(alpha: 0.92);
        c.drawCircle(head, 0.3 * s, _p);
        _itemS(k.product, head.translate(0, 0.08 * s), sc: 0.55);
      }
    }
    for (final t in w.tiles) {
      if (!w.tileVisible(t) || t.appear < 1) continue;
      if ((t.def.pos - w.player.pos).distance > 2.8) continue;
      final p = cam.w2s(t.def.pos.dx, t.def.pos.dy, w.groundZ(t.def.pos) + 1.25);
      _text(Tr.t(t.def.name), p, 0.4 * s, Colors.white, stroke: const Color(0xFF203A66));
    }
    for (final t in w.levelTiles) {
      if (!w.levelTileVisible(t) || t.appear < 1) continue;
      if ((t.pos - w.player.pos).distance > 2.2) continue;
      final p = cam.w2s(t.pos.dx, t.pos.dy, 1.1);
      _text('${Tr.station(t.kind, w.region)} • ${Tr.t('level')} ${w.sl(t.kind) + 1}→${w.sl(t.kind) + 2}', p, 0.34 * s,
          Colors.white,
          stroke: const Color(0xFF14412F));
    }
    for (final t in w.texts) {
      final u = t.life / t.max;
      final p = cam.w2s(t.pos.dx, t.pos.dy, t.z + u * 1.2);
      final a = (1 - u * u).clamp(0.0, 1.0);
      _text(t.text, p, t.size * (s / 40) * (1 + (1 - u) * 0.15), t.color.withValues(alpha: a),
          stroke: Pal.ink.withValues(alpha: a * 0.8));
    }
    final g = w.guideTarget();
    if (g != null) {
      final bob = math.sin(w.time * 5) * 0.14 * s;
      final tip = cam.w2s(g.dx, g.dy, w.groundZ(g) + 1.9).translate(0, bob);
      final aw = 0.42 * s, ah = 0.7 * s;
      final path = Path()
        ..moveTo(tip.dx, tip.dy + ah * 0.5)
        ..lineTo(tip.dx - aw, tip.dy - ah * 0.08)
        ..lineTo(tip.dx - aw * 0.42, tip.dy - ah * 0.08)
        ..lineTo(tip.dx - aw * 0.42, tip.dy - ah * 0.72)
        ..lineTo(tip.dx + aw * 0.42, tip.dy - ah * 0.72)
        ..lineTo(tip.dx + aw * 0.42, tip.dy - ah * 0.08)
        ..lineTo(tip.dx + aw, tip.dy - ah * 0.08)
        ..close();
      _p.color = const Color(0x40000000);
      c.drawPath(path.shift(Offset(0, 0.06 * s)), _p);
      _p.color = const Color(0xFFFFD447);
      c.drawPath(path, _p);
      _ps.color = const Color(0xFF7A4B00);
      _ps.strokeWidth = 0.05 * s;
      c.drawPath(path, _ps);
    }
  }

  void _snowfall() {
    final storm = w.raid.freeze;
    final n = 55 + (storm * 150).round();
    final wind = 22 + storm * 140;
    final off = cam.w2s(0, 0, 0);
    _p.color = Colors.white.withValues(alpha: 0.85);
    final wdt = size.width + 40, hgt = size.height + 40;
    for (var i = 0; i < n; i++) {
      final speed = 22 + _h1(i + 5000) * 40;
      var x = _h1(i + 5100) * wdt + w.time * wind * (0.5 + _h1(i + 5200)) + math.sin(w.time * 1.3 + i) * 12 + off.dx * 0.35;
      var y = _h1(i + 5300) * hgt + w.time * speed * (1 + storm) + off.dy * 0.35;
      x = x % wdt - 20;
      y = y % hgt - 20;
      final r = 1.1 + _h1(i + 5400) * 2.4;
      c.drawCircle(Offset(x, y), r, _p);
    }
  }

  void _vignette() {
    final f = w.raid.freeze;
    if (f <= 0.01) return;
    final rect = Offset.zero & size;
    final tint = w.raid.boss ? const Color(0xFFFFD6D6) : const Color(0xFFD9EEFF);
    final paint = Paint()
      ..shader = ui.Gradient.radial(rect.center, size.longestSide * 0.65, [const Color(0x00FFFFFF), tint.withValues(alpha: 0.6 * f)],
          const [0.5, 1.0]);
    c.drawRect(rect, paint);
  }

  void _hudFlies() {
    for (final h in w.hudFlies) {
      if (h.t < 0) continue;
      final u = (h.t / h.dur).clamp(0.0, 1.0);
      final e = u * u * (3 - 2 * u);
      final target = h.gem ? w.hudGem : w.hudCoin;
      final ctrl = Offset((h.from.dx + target.dx) / 2 + 40, math.min(h.from.dy, target.dy) - 60);
      final a = Offset.lerp(h.from, ctrl, e)!, b = Offset.lerp(ctrl, target, e)!;
      final p = Offset.lerp(a, b, e)!;
      final sc = 1.15 - 0.45 * u;
      if (h.gem) {
        _gemIcon(p, 10 * sc);
      } else {
        _coinIcon(p, 10 * sc);
      }
    }
  }

  void _joystick() {
    if (!joy.active) return;
    final o = joy.origin!, p = joy.pos!;
    var d = p - o;
    if (d.distance > Joy.radius) d = d / d.distance * Joy.radius;
    _p.color = const Color(0x30FFFFFF);
    c.drawCircle(o, Joy.radius, _p);
    _ps.color = const Color(0x99FFFFFF);
    _ps.strokeWidth = 3;
    c.drawCircle(o, Joy.radius, _ps);
    _p.color = const Color(0x40203A66);
    c.drawCircle(o + d + const Offset(0, 3), 25, _p);
    _p.color = const Color(0xE6FFFFFF);
    c.drawCircle(o + d, 25, _p);
  }
}
