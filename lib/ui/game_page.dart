import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/audio.dart';
import '../game/render.dart';
import '../game/save.dart';
import '../game/strings.dart';
import '../game/world.dart';
import 'hud.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _Banner {
  _Banner(this.title, this.sub, this.color, this.dur);

  final String title;
  final String? sub;
  final Color color;
  final double dur;
  double t = 0;
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  GameWorld world = GameWorld();
  final AudioManager audio = AudioManager();
  final Joy joy = Joy();
  final ValueNotifier<int> frame = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  SaveStore? _store;
  bool _title = true;
  bool _shop = false;
  bool _settings = false;
  bool _confirmReset = false;
  bool _vibration = true;
  bool _hasSave = false;
  double _saveTimer = 0;
  double _shownMoney = 0;
  double _moneyPulse = 0;
  double _gemPulse = 0;
  double _hapticCd = 0;
  int _lastMoney = 0;
  int _lastGems = 0;
  final List<_Banner> _banners = [];
  final Set<LogicalKeyboardKey> _keys = {};
  final FocusNode _focus = FocusNode();
  EdgeInsets _pad = EdgeInsets.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    Tr.lang = code == 'ar' ? 'ar' : 'en';
    _ticker = createTicker(_onTick)..start();
    _init();
  }

  Future<void> _init() async {
    final store = await SaveStore.open();
    _store = store;
    if (store != null) {
      final data = store.load();
      if (data != null) {
        world.loadJson(data);
        _hasSave = world.progress > 0 || world.money > 0;
      }
      final l = store.lang;
      if (l != null) Tr.lang = l;
      audio.soundOn = store.sound;
      audio.musicOn = store.music;
      _vibration = store.vibration;
    }
    if (kIsWeb) _applyWebParams();
    _shownMoney = world.money.toDouble();
    _lastMoney = world.money;
    _lastGems = world.crystals;
    if (mounted) setState(() {});
    await audio.init();
  }

  /// Query parameters used for automated testing of the web build.
  void _applyWebParams() {
    final q = Uri.base.queryParameters;
    final l = q['lang'];
    if (l == 'ar' || l == 'en') Tr.lang = l!;
    final demo = q['demo'];
    if (demo != null) world.applyDemo(demo);
    if (q['raid'] == '1') world.triggerRaidSoon();
    final x = double.tryParse(q['x'] ?? ''), y = double.tryParse(q['y'] ?? '');
    if (x != null && y != null) {
      world.player.pos = Offset(x, y);
      world.cam.cx = x;
      world.cam.cy = y;
    }
    if (q['autostart'] == '1') {
      _title = false;
      world.started = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _focus.dispose();
    frame.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.inactive) {
      _save();
      audio.pauseMusic();
    } else if (state == AppLifecycleState.resumed) {
      if (!_title) audio.startMusic();
    }
  }

  void _save() {
    final s = _store;
    if (s == null) return;
    world.dirty = false;
    unawaited(s.save(world.toJson()));
  }

  // ------------------------------------------------------------------ loop
  void _onTick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05;
    final paused = _shop || _settings;
    if (!paused) {
      world.input = _title ? Offset.zero : _inputVector();
      world.update(dt);
    }
    _hapticCd -= dt;
    for (final s in world.sfx) {
      audio.play(s);
      if (s == Sfx.pop && _hapticCd <= 0) {
        _haptic();
        _hapticCd = 0.15;
      }
    }
    world.sfx.clear();
    for (final e in world.events) {
      _onEvent(e);
    }
    world.events.clear();
    if (world.money != _lastMoney) {
      if (world.money > _lastMoney) _moneyPulse = 1;
      _lastMoney = world.money;
    }
    if (world.crystals != _lastGems) {
      if (world.crystals > _lastGems) _gemPulse = 1;
      _lastGems = world.crystals;
    }
    _moneyPulse = math.max(0, _moneyPulse - dt * 4);
    _gemPulse = math.max(0, _gemPulse - dt * 4);
    _shownMoney += (world.money - _shownMoney) * math.min(1, dt * 12);
    if ((world.money - _shownMoney).abs() < 0.6) _shownMoney = world.money.toDouble();
    if (_banners.isNotEmpty) {
      _banners.first.t += dt;
      if (_banners.first.t >= _banners.first.dur) _banners.removeAt(0);
    }
    _saveTimer += dt;
    if (_saveTimer > 5) {
      _saveTimer = 0;
      if (world.dirty && world.started) _save();
    }
    frame.value++;
  }

  void _onEvent(String e) {
    if (e.startsWith('unlock:')) {
      _pushBanner(Tr.t(e.substring(7)), Tr.t('unlocked'), const Color(0xFF5CF0A8), 1.8);
      _haptic(heavy: true);
      _save();
    } else if (e == 'zoneB') {
      _pushBanner(Tr.t('chowderHouse'), Tr.t('newArea'), const Color(0xFF5CF0A8), 2.6);
      _haptic(heavy: true);
      _save();
    } else if (e == 'raid_start') {
      _pushBanner(Tr.t('raidNow'), Tr.t('raidSub'), const Color(0xFFFF6B6B), 2.8);
      _haptic(heavy: true);
    } else if (e.startsWith('raid_end:')) {
      _pushBanner(Tr.t('victory'), '+${e.substring(9)} ${Tr.t('crystals')}', const Color(0xFFFFD447), 2.4);
      _save();
    } else if (e == 'lighthouse') {
      _pushBanner(Tr.t('lighthouse'), Tr.t('lighthouseDone'), const Color(0xFFFFD447), 3.4);
      _haptic(heavy: true);
      _save();
    }
  }

  void _pushBanner(String title, String? sub, Color color, double dur) {
    _banners.add(_Banner(title, sub, color, dur));
    if (_banners.length > 3) _banners.removeAt(1);
  }

  void _haptic({bool heavy = false}) {
    if (!_vibration || kIsWeb) return;
    if (heavy) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  // ------------------------------------------------------------------ input
  Offset _inputVector() {
    var v = Offset.zero;
    if (joy.active) {
      final d = joy.pos! - joy.origin!;
      final dist = d.distance;
      if (dist > 6) {
        final m = ((dist - 6) / (Joy.radius * 0.55)).clamp(0.35, 1.0);
        v = world.cam.screenDirToWorld(d) * m;
      }
    }
    final k = _keyDir();
    if (k != Offset.zero) v = world.cam.screenDirToWorld(k);
    return v;
  }

  Offset _keyDir() {
    var x = 0.0, y = 0.0;
    bool any(List<LogicalKeyboardKey> ks) => ks.any(_keys.contains);
    if (any([LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA])) x -= 1;
    if (any([LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD])) x += 1;
    if (any([LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW])) y -= 1;
    if (any([LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS])) y += 1;
    return Offset(x, y);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyDownEvent) {
      _keys.add(e.logicalKey);
      if (_title && (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.space)) _start();
    } else if (e is KeyUpEvent) {
      _keys.remove(e.logicalKey);
    }
    return KeyEventResult.handled;
  }

  void _down(PointerDownEvent e) {
    if (_title || _shop || _settings || joy.pointer != null) return;
    joy.pointer = e.pointer;
    joy.origin = e.localPosition;
    joy.pos = e.localPosition;
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != joy.pointer) return;
    joy.pos = e.localPosition;
    final d = joy.pos! - joy.origin!;
    const maxD = Joy.radius * 1.2;
    if (d.distance > maxD) joy.origin = joy.pos! - d / d.distance * maxD;
  }

  void _up(PointerEvent e) {
    if (e.pointer == joy.pointer) joy.clear();
  }

  // ------------------------------------------------------------------ actions
  void _start() {
    if (!_title) return;
    setState(() {
      _title = false;
      world.started = true;
    });
    audio.startMusic();
    _focus.requestFocus();
  }

  void _openShop() => setState(() {
        _shop = true;
        joy.clear();
      });

  void _openSettings() => setState(() {
        _settings = true;
        _confirmReset = false;
        joy.clear();
      });

  void _closePanels() => setState(() {
        _shop = false;
        _settings = false;
        _confirmReset = false;
        _focus.requestFocus();
      });

  Future<void> _reset() async {
    await _store?.clear();
    setState(() {
      world = GameWorld()..started = true;
      _confirmReset = false;
      _settings = false;
      _hasSave = false;
      _shownMoney = 0;
      _lastMoney = 0;
      _lastGems = 0;
      _banners.clear();
    });
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    _pad = mq.padding;
    world.hudCoin = Offset(_pad.left + 12 + 23, _pad.top + 10 + 20);
    world.hudGem = Offset(_pad.left + 12 + 23, _pad.top + 56 + 20);
    return PopScope(
      canPop: !(_shop || _settings),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closePanels();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEFF4FB),
        body: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: LayoutBuilder(builder: (context, cons) {
            final size = cons.biggest;
            world.cam.size = size;
            world.cam.scale = (size.shortestSide / 12.0).clamp(24.0, 58.0);
            return Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _down,
                    onPointerMove: _move,
                    onPointerUp: _up,
                    onPointerCancel: _up,
                    child: CustomPaint(painter: WorldPainter(world, joy, repaint: frame), size: Size.infinite),
                  ),
                ),
                Positioned.fill(
                  child: Directionality(
                    textDirection: Tr.rtl ? TextDirection.rtl : TextDirection.ltr,
                    child: AnimatedBuilder(animation: frame, builder: (context, _) => _hud()),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _hud() {
    return Stack(
      children: [
        if (!_title) ...[
          Positioned(
            left: _pad.left + 12,
            top: _pad.top + 10,
            child: HudPill(icon: const CoinIcon(), text: _fmtMoney(_shownMoney.round()), pulse: _moneyPulse),
          ),
          Positioned(
            left: _pad.left + 12,
            top: _pad.top + 56,
            child: HudPill(icon: const GemIcon(), text: '${world.crystals}', pulse: _gemPulse, width: 96),
          ),
          Positioned(
            right: _pad.right + 70,
            top: _pad.top + 12,
            child: _harborBar(),
          ),
          Positioned(
            right: _pad.right + 10,
            top: _pad.top + 6,
            child: RoundIconButton(icon: Icons.settings_rounded, onTap: _openSettings),
          ),
          Positioned(
            top: _pad.top + 104,
            left: 0,
            right: 0,
            child: Center(child: _raidChip()),
          ),
          Positioned(
            right: _pad.right + 14,
            bottom: _pad.bottom + 18,
            child: _workshopButton(),
          ),
          if (_banners.isNotEmpty) Positioned.fill(child: IgnorePointer(child: _bannerView(_banners.first))),
        ],
        if (_title) Positioned.fill(child: _titleView()),
        if (_shop) Positioned.fill(child: _shopView()),
        if (_settings) Positioned.fill(child: _settingsView()),
      ],
    );
  }

  String _fmtMoney(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 100000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }

  String _mmss(double t) {
    final s = t.ceil().clamp(0, 5999);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _harborBar() {
    final f = world.progress / world.progressMax;
    return Container(
      width: 118,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 7),
      decoration: BoxDecoration(
        color: const Color(0xD914284A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${Tr.t('harbor')} ${world.progress}/${world.progressMax}', style: gs(13)),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: f,
                backgroundColor: Colors.white24,
                color: const Color(0xFF39D98A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _raidChip() {
    final r = world.raid;
    if (!r.enabled) return const SizedBox.shrink();
    final active = r.active;
    final urgent = !active && r.timer < 10;
    final pulse = 0.5 + 0.5 * math.sin(world.time * 8);
    final color = active
        ? const Color(0xF2E5383B)
        : (urgent ? Color.lerp(const Color(0xD914284A), const Color(0xF2E5383B), pulse)! : const Color(0xD914284A));
    final txt = active ? '${Tr.t('raidNow')}  ${world.wolvesLeft}' : '${Tr.t('raidIn')} ${_mmss(r.timer)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.pets : Icons.ac_unit_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(txt, style: gs(15)),
        ],
      ),
    );
  }

  Widget _workshopButton() {
    final can = Upg.values.any((u) {
      final c = world.upgCost(u);
      return c >= 0 && world.crystals >= c;
    });
    final bob = can ? math.sin(world.time * 5) * 3 : 0.0;
    return GestureDetector(
      onTap: _openShop,
      child: Transform.translate(
        offset: Offset(0, bob),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFB067), Color(0xFFF27A2A)],
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 4))],
                  ),
                  child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 34),
                ),
                if (can)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5383B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text('!', style: gs(15, height: 1.0)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            StrokeText(Tr.t('workshop'), size: 14, strokeWidth: 4),
          ],
        ),
      ),
    );
  }

  Widget _bannerView(_Banner b) {
    final appear = (b.t / 0.45).clamp(0.0, 1.0);
    final u = b.t / b.dur;
    final fade = u > 0.82 ? (1 - (u - 0.82) / 0.18) : 1.0;
    final sc = 0.5 + 0.5 * Curves.elasticOut.transform(appear);
    return Align(
      alignment: const Alignment(0, -0.42),
      child: Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: sc,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StrokeText(b.title, size: 42, color: b.color, strokeWidth: 9),
              if (b.sub != null)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  constraints: const BoxConstraints(maxWidth: 330),
                  decoration: BoxDecoration(color: const Color(0xD914284A), borderRadius: BorderRadius.circular(14)),
                  child: Text(b.sub!, textAlign: TextAlign.center, style: gs(16)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ overlays
  Widget _titleView() {
    final t = world.time;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE60B2447), Color(0x700B2447), Color(0x260B2447), Color(0xF00B2447)],
          stops: [0, 0.38, 0.6, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Transform.translate(offset: Offset(0, math.sin(t * 1.6) * 6), child: _logo()),
            const Spacer(flex: 3),
            Transform.scale(
              scale: 1 + 0.05 * math.sin(t * 4),
              child: GameButton(
                onTap: _start,
                padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 10),
                child: Text(_hasSave ? Tr.t('continue') : Tr.t('play'), style: gs(30)),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(Tr.t('howto'), textAlign: TextAlign.center, style: gs(14.5, weight: 600, height: 1.45)),
            ),
            const SizedBox(height: 14),
            _langToggle(),
            const SizedBox(height: 10),
            Text(Tr.t('credits'), textAlign: TextAlign.center, style: gs(11.5, color: Colors.white60, weight: 500)),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _logo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.ac_unit_rounded, size: 54, color: Color(0xFFBDEBFF)),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFA5DFFF)],
          ).createShader(r),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: StrokeText('WHITE WAR', size: 60, strokeWidth: 11, stroke: Color(0xFF0E2A55)),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -6),
          child: const StrokeText('الحرب البيضاء', size: 32, color: Color(0xFFFFD447), strokeWidth: 8, stroke: Color(0xFF0E2A55)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFF8A3D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text('FROST HARBOR • ميناء الصقيع', style: gs(14)),
        ),
      ],
    );
  }

  Widget _langToggle() {
    Widget chip(String label, String code) {
      final sel = Tr.lang == code;
      return GestureDetector(
        onTap: () {
          setState(() => Tr.lang = code);
          _store?.lang = code;
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFFFF8A3D) : const Color(0x6614284A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: sel ? 1 : 0.5), width: 2),
          ),
          child: Text(label, style: gs(15)),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [chip('العربية', 'ar'), chip('English', 'en')],
    );
  }

  Widget _dimmed({required Widget child, Alignment align = Alignment.center}) {
    return GestureDetector(
      onTap: _closePanels,
      child: Container(
        color: const Color(0x99000000),
        alignment: align,
        child: SafeArea(child: GestureDetector(onTap: () {}, child: child)),
      ),
    );
  }

  Widget _shopView() {
    return _dimmed(
      align: Alignment.bottomCenter,
      child: Panel(
        title: Tr.t('workshop'),
        onClose: _closePanels,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const GemIcon(size: 24),
                  const SizedBox(width: 6),
                  Text('${world.crystals}', style: gs(24)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(Tr.t('gemsHint'), style: gs(12, weight: 500, color: Colors.white70, height: 1.3))),
                ],
              ),
              const SizedBox(height: 12),
              for (final u in Upg.values) _upgRow(u),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upgRow(Upg u) {
    final lv = world.lv(u);
    final cost = world.upgCost(u);
    final can = cost >= 0 && world.crystals >= cost;
    final icon = switch (u) {
      Upg.power => Icons.bolt_rounded,
      Upg.rate => Icons.speed_rounded,
      Upg.capacity => Icons.inventory_2_rounded,
      Upg.speed => Icons.directions_run_rounded,
      Upg.kitchen => Icons.soup_kitchen_rounded,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF213B66), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: const Color(0xFF2E5C9E), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Tr.t('upg_${u.name}'), style: gs(17)),
                Text(Tr.t('upgd_${u.name}'), style: gs(11.5, weight: 500, color: Colors.white70)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    for (var i = 0; i < upgMax; i++)
                      Container(
                        width: 13,
                        height: 6,
                        margin: const EdgeInsetsDirectional.only(end: 3),
                        decoration: BoxDecoration(
                          color: i < lv ? const Color(0xFF39D98A) : Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (cost < 0)
            Text(Tr.t('maxLevel'), style: gs(16, color: const Color(0xFF39D98A)))
          else
            GameButton(
              enabled: can,
              onTap: () {
                if (world.buyUpgrade(u)) {
                  setState(() {});
                  _haptic(heavy: true);
                  _save();
                }
              },
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              radius: 14,
              color: const Color(0xFF39B5F0),
              shade: const Color(0xFF1F7FB3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [const GemIcon(size: 18), const SizedBox(width: 4), Text('$cost', style: gs(18))],
              ),
            ),
        ],
      ),
    );
  }

  Widget _settingsView() {
    Widget toggle(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: gs(17))),
            Switch(value: value, onChanged: (v) => setState(() => onChanged(v))),
          ],
        ),
      );
    }

    return _dimmed(
      child: Panel(
        title: Tr.t('settings'),
        onClose: _closePanels,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              toggle(Icons.volume_up_rounded, Tr.t('sound'), audio.soundOn, (v) {
                audio.soundOn = v;
                _store?.sound = v;
              }),
              toggle(Icons.music_note_rounded, Tr.t('music'), audio.musicOn, (v) {
                audio.setMusic(v);
                _store?.music = v;
              }),
              toggle(Icons.vibration_rounded, Tr.t('vibration'), _vibration, (v) {
                _vibration = v;
                _store?.vibration = v;
              }),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.translate_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(child: Text(Tr.t('language'), style: gs(17))),
                  _langToggle(),
                ],
              ),
              const SizedBox(height: 18),
              if (!_confirmReset)
                GameButton(
                  color: const Color(0xFFE5383B),
                  shade: const Color(0xFF9E1F22),
                  onTap: () => setState(() => _confirmReset = true),
                  child: Text(Tr.t('reset'), style: gs(18)),
                )
              else
                Column(
                  children: [
                    Text(Tr.t('resetConfirm'), style: gs(17)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GameButton(
                          color: const Color(0xFFE5383B),
                          shade: const Color(0xFF9E1F22),
                          onTap: _reset,
                          child: Text(Tr.t('yes'), style: gs(18)),
                        ),
                        const SizedBox(width: 14),
                        GameButton(
                          color: const Color(0xFF39B5F0),
                          shade: const Color(0xFF1F7FB3),
                          onTap: () => setState(() => _confirmReset = false),
                          child: Text(Tr.t('no'), style: gs(18)),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
