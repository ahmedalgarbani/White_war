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
  int _shopTab = 0;
  bool _settings = false;
  bool _questsOpen = false;
  bool _expedition = false;
  bool _confirmReset = false;
  bool _vibration = true;
  bool _hasSave = false;
  int _offline = 0;
  bool _offlineShown = false;
  double _saveTimer = 0;
  double _shownMoney = 0;
  double _moneyPulse = 0;
  double _gemPulse = 0;
  double _questPulse = 0;
  double _hapticCd = 0;
  int _lastMoney = 0;
  int _lastGems = 0;
  final List<_Banner> _banners = [];
  final Set<LogicalKeyboardKey> _keys = {};
  final FocusNode _focus = FocusNode();
  EdgeInsets _pad = EdgeInsets.zero;

  bool get _panelOpen => _shop || _settings || _questsOpen || _expedition || (_offline > 0 && _offlineShown);

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
        world = GameWorld.fromSave(data);
        _hasSave = world.progress > 0 || world.money > 0 || world.completed > 0;
        final last = data['lastSeen'];
        if (last is num) {
          final away = (DateTime.now().millisecondsSinceEpoch - last.toInt()) / 1000.0;
          _offline = world.offlineReward(away);
        }
      }
      final l = store.lang;
      if (l != null) Tr.lang = l;
      audio.soundOn = store.sound;
      audio.musicOn = store.music;
      _vibration = store.vibration;
    }
    if (kIsWeb) _applyWebParams();
    _syncCounters();
    if (mounted) setState(() {});
    await audio.init();
  }

  void _syncCounters() {
    _shownMoney = world.money.toDouble();
    _lastMoney = world.money;
    _lastGems = world.crystals;
  }

  /// Query parameters used for automated testing of the web build.
  void _applyWebParams() {
    final q = Uri.base.queryParameters;
    final l = q['lang'];
    if (l == 'ar' || l == 'en') Tr.lang = l!;
    final region = int.tryParse(q['region'] ?? '');
    if (region != null) {
      world = GameWorld(regionIndex: region.clamp(0, regions.length - 1), star: int.tryParse(q['star'] ?? '') ?? 0);
    }
    final demo = q['demo'];
    if (demo != null) world.applyDemo(demo);
    if (q['raid'] == '1') world.triggerRaidSoon();
    if (q['boss'] == '1') world.triggerRaidSoon(boss: true);
    final x = double.tryParse(q['x'] ?? ''), y = double.tryParse(q['y'] ?? '');
    if (x != null && y != null) {
      world.player.pos = Offset(x, y);
      world.cam.cx = x;
      world.cam.cy = y;
    }
    final off = int.tryParse(q['offline'] ?? '');
    if (off != null) _offline = off;
    if (q['autostart'] == '1') {
      _title = false;
      world.started = true;
      _offlineShown = true;
    }
    if (q['panel'] == 'quests') _questsOpen = true;
    if (q['panel'] == 'map') _expedition = true;
    if (q['panel'] == 'wardrobe') {
      _shop = true;
      _shopTab = 1;
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
    if (!_panelOpen) {
      world.input = _title ? Offset.zero : _inputVector();
      world.update(dt);
    }
    _hapticCd -= dt;
    for (final s in world.sfx) {
      audio.play(s);
      if ((s == Sfx.pop || s == Sfx.chop || s == Sfx.mine) && _hapticCd <= 0) {
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
    _questPulse = math.max(0, _questPulse - dt * 1.5);
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
      _pushBanner(Tr.t('zoneB_${world.region.key}'), Tr.t('newArea'), const Color(0xFF5CF0A8), 2.6);
      _haptic(heavy: true);
      _save();
    } else if (e == 'raid_start') {
      _pushBanner(Tr.t('raidNow'), Tr.t('raidSub'), const Color(0xFFFF6B6B), 2.8);
      _haptic(heavy: true);
    } else if (e == 'boss_start') {
      _pushBanner(Tr.t('bossNow'), Tr.t('bossSub'), const Color(0xFFD291FF), 3.2);
      _haptic(heavy: true);
    } else if (e.startsWith('raid_end:')) {
      _pushBanner(Tr.t('victory'), '+${e.substring(9)} ${Tr.t('crystals')}', const Color(0xFFFFD447), 2.4);
      _save();
    } else if (e == 'landmark') {
      _pushBanner(Tr.t('landmark_${world.region.key}'), Tr.t('landmarkDone'), const Color(0xFFFFD447), 3.6);
      _haptic(heavy: true);
      _save();
    } else if (e == 'quest') {
      _questPulse = 1;
      _haptic();
    } else if (e.startsWith('level:')) {
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
    if (_title || _panelOpen || joy.pointer != null) return;
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
      _offlineShown = true;
    });
    audio.startMusic();
    _focus.requestFocus();
  }

  void _open(void Function() f) => setState(() {
        f();
        joy.clear();
      });

  void _closePanels() => setState(() {
        _shop = false;
        _settings = false;
        _questsOpen = false;
        _expedition = false;
        _confirmReset = false;
        _focus.requestFocus();
      });

  void _collectOffline() {
    world.grantMoney(_offline);
    setState(() => _offline = 0);
    _haptic(heavy: true);
  }

  void _travel() {
    if (!world.regionComplete) return;
    final next = world.travel();
    setState(() {
      world = next;
      _expedition = false;
      _banners.clear();
      _syncCounters();
    });
    _pushBanner(Tr.region(world.region), Tr.t('regiondesc_${world.region.key}'), const Color(0xFF8FE3FF), 3.4);
    audio.play(Sfx.victory);
    _haptic(heavy: true);
    _save();
  }

  Future<void> _reset() async {
    await _store?.clear();
    setState(() {
      world = GameWorld()..started = true;
      _confirmReset = false;
      _settings = false;
      _hasSave = false;
      _offline = 0;
      _banners.clear();
      _syncCounters();
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
      canPop: !_panelOpen,
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
            world.cam.dpr = mq.devicePixelRatio.clamp(1.0, 3.0);
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
            child: HudPill(icon: const CoinIcon(), text: fmtNum(_shownMoney.round()), pulse: _moneyPulse),
          ),
          Positioned(
            left: _pad.left + 12,
            top: _pad.top + 56,
            child: HudPill(icon: const GemIcon(), text: fmtNum(world.crystals), pulse: _gemPulse, width: 96),
          ),
          Positioned(left: _pad.left + 12, top: _pad.top + 102, child: _questTracker()),
          Positioned(right: _pad.right + 70, top: _pad.top + 12, child: _regionBar()),
          Positioned(
            right: _pad.right + 10,
            top: _pad.top + 6,
            child: RoundIconButton(icon: Icons.settings_rounded, onTap: () => _open(() {
                  _settings = true;
                  _confirmReset = false;
                })),
          ),
          Positioned(right: _pad.right + 10, top: _pad.top + 62, child: _raidChip()),
          Positioned(right: _pad.right + 14, bottom: _pad.bottom + 18, child: _workshopButton()),
          Positioned(left: _pad.left + 14, bottom: _pad.bottom + 18, child: _expeditionButton()),
          if (_banners.isNotEmpty) Positioned.fill(child: IgnorePointer(child: _bannerView(_banners.first))),
        ],
        if (_title) Positioned.fill(child: _titleView()),
        if (_shop) Positioned.fill(child: _shopView()),
        if (_settings) Positioned.fill(child: _settingsView()),
        if (_questsOpen) Positioned.fill(child: _questView()),
        if (_expedition) Positioned.fill(child: _expeditionView()),
        if (!_title && _offline > 0 && _offlineShown && !_shop && !_settings) Positioned.fill(child: _offlineView()),
      ],
    );
  }

  String _mmss(double t) {
    final s = t.ceil().clamp(0, 5999);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _regionBar() {
    final f = world.progress / world.progressMax;
    final stars = world.star > 0 ? ' ${'★' * math.min(world.star, 3)}${world.star > 3 ? world.star : ''}' : '';
    return Container(
      width: 132,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 7),
      decoration: BoxDecoration(
        color: const Color(0xD914284A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${Tr.region(world.region)}$stars', style: gs(13, color: const Color(0xFFFFE28A))),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(value: f, backgroundColor: Colors.white24, color: const Color(0xFF39D98A)),
            ),
          ),
          const SizedBox(height: 1),
          Text('${world.progress}/${world.progressMax}', style: gs(11, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _questTracker() {
    final claimable = world.claimableQuests;
    final q = world.quests.where((q) => !q.done).firstOrNull ?? world.quests.firstOrNull;
    if (q == null) return const SizedBox.shrink();
    final pulse = claimable > 0 ? 0.5 + 0.5 * math.sin(world.time * 6) : _questPulse;
    return GestureDetector(
      onTap: () => _open(() => _questsOpen = true),
      child: Container(
        width: 176,
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
        decoration: BoxDecoration(
          color: Color.lerp(const Color(0xD914284A), const Color(0xF2B8860B), claimable > 0 ? pulse * 0.8 : 0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35 + 0.5 * pulse), width: 2),
        ),
        child: claimable > 0
            ? Row(
                children: [
                  const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${Tr.t('claim')}! ($claimable)', style: gs(15))),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flag_rounded, color: Color(0xFFFFD447), size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(Tr.quest(q.kind, q.target, world.region),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: gs(12.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                          value: q.progress / q.target, backgroundColor: Colors.white24, color: const Color(0xFFFFD447)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _raidChip() {
    final r = world.raid;
    if (!r.enabled) return const SizedBox.shrink();
    final active = r.active;
    final boss = active ? r.boss : world.nextRaidIsBoss;
    final urgent = !active && r.timer < 10;
    final pulse = 0.5 + 0.5 * math.sin(world.time * 8);
    final hot = boss ? const Color(0xF29B4DE0) : const Color(0xF2E5383B);
    final color = active ? hot : (urgent ? Color.lerp(const Color(0xD914284A), hot, pulse)! : const Color(0xD914284A));
    final label = active
        ? '${Tr.t(boss ? 'bossNow' : 'raidNow')}  ${world.enemiesLeft}'
        : '${Tr.t(boss ? 'bossIn' : 'raidIn')} ${_mmss(r.timer)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.pets : (boss ? Icons.whatshot_rounded : Icons.ac_unit_rounded), color: Colors.white, size: 17),
          const SizedBox(width: 5),
          Text(label, style: gs(14)),
        ],
      ),
    );
  }

  Widget _roundAction({required IconData icon, required String label, required VoidCallback onTap, required List<Color> colors, bool alert = false}) {
    final bob = alert ? math.sin(world.time * 5) * 3 : 0.0;
    return GestureDetector(
      onTap: onTap,
      child: Transform.translate(
        offset: Offset(0, bob),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 4))],
                  ),
                  child: Icon(icon, color: Colors.white, size: 32),
                ),
                if (alert)
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
            StrokeText(label, size: 14, strokeWidth: 4),
          ],
        ),
      ),
    );
  }

  Widget _workshopButton() {
    final can = Upg.values.any((u) {
      final c = world.upgCost(u);
      return c >= 0 && world.crystals >= c;
    });
    return _roundAction(
      icon: Icons.handyman_rounded,
      label: Tr.t('workshop'),
      onTap: () => _open(() => _shop = true),
      colors: const [Color(0xFFFFB067), Color(0xFFF27A2A)],
      alert: can,
    );
  }

  Widget _expeditionButton() {
    return _roundAction(
      icon: Icons.map_rounded,
      label: Tr.t('expedition'),
      onTap: () => _open(() => _expedition = true),
      colors: const [Color(0xFF6FD3FF), Color(0xFF2E7FD8)],
      alert: world.regionComplete,
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
              StrokeText(b.title, size: 40, color: b.color, strokeWidth: 9),
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
            if (_hasSave)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('${Tr.region(world.region)}${world.star > 0 ? '  ★${world.star}' : ''}',
                    style: gs(16, color: const Color(0xFFFFE28A))),
              ),
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
          child: Text('EXPEDITION • الرحلة', style: gs(14)),
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

  Widget _dimmed({required Widget child, Alignment align = Alignment.center, VoidCallback? onDismiss}) {
    return GestureDetector(
      onTap: onDismiss ?? _closePanels,
      child: Container(
        color: const Color(0x99000000),
        alignment: align,
        child: SafeArea(child: GestureDetector(onTap: () {}, child: child)),
      ),
    );
  }

  Widget _tabs(List<String> labels, int selected, ValueChanged<int> onTap) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF0E1B33), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: i == selected ? const Color(0xFF2E5C9E) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(labels[i], style: gs(15, color: i == selected ? Colors.white : Colors.white60)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gemHeader() {
    return Row(
      children: [
        const GemIcon(size: 24),
        const SizedBox(width: 6),
        Text(fmtNum(world.crystals), style: gs(24)),
        const SizedBox(width: 12),
        Expanded(child: Text(Tr.t('gemsHint'), style: gs(12, weight: 500, color: Colors.white70, height: 1.3))),
      ],
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
              _tabs([Tr.t('upgrades'), Tr.t('wardrobe')], _shopTab, (i) => setState(() => _shopTab = i)),
              const SizedBox(height: 12),
              _gemHeader(),
              const SizedBox(height: 12),
              if (_shopTab == 0)
                for (final u in Upg.values) _upgRow(u)
              else
                _wardrobe(),
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
      Upg.helpers => Icons.groups_rounded,
      Upg.income => Icons.trending_up_rounded,
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
                        width: 11,
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

  Widget _wardrobe() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < outfits.length; i++) _outfitCard(i),
      ],
    );
  }

  Widget _outfitCard(int i) {
    final o = outfits[i];
    final owned = world.outfitsOwned.contains(i);
    final wearing = world.outfit == i;
    final can = owned || world.crystals >= o.cost;
    return Container(
      width: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: wearing ? const Color(0xFF2E5C9E) : const Color(0xFF213B66),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: wearing ? const Color(0xFFFFD447) : Colors.transparent, width: 2),
      ),
      child: Column(
        children: [
          SizedBox(width: 64, height: 64, child: CustomPaint(painter: _OutfitPainter(o.look))),
          const SizedBox(height: 4),
          Text(Tr.t('outfit_${o.key}'), style: gs(13.5), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          if (wearing)
            Text(Tr.t('wearing'), style: gs(14, color: const Color(0xFFFFD447)))
          else
            GameButton(
              enabled: can,
              onTap: () {
                if (world.buyOutfit(i)) {
                  setState(() {});
                  _haptic(heavy: true);
                  _save();
                }
              },
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              radius: 12,
              color: owned ? const Color(0xFF39D98A) : const Color(0xFF39B5F0),
              shade: owned ? const Color(0xFF1E8F58) : const Color(0xFF1F7FB3),
              child: owned
                  ? Text(Tr.t('wear'), style: gs(15))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [const GemIcon(size: 16), const SizedBox(width: 3), Text('${o.cost}', style: gs(15))],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _questView() {
    return _dimmed(
      child: Panel(
        title: Tr.t('quests'),
        onClose: _closePanels,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [for (var i = 0; i < world.quests.length; i++) _questRow(i)],
          ),
        ),
      ),
    );
  }

  Widget _questRow(int i) {
    final q = world.quests[i];
    final icon = switch (q.kind) {
      QuestKind.harvest => Icons.agriculture_rounded,
      QuestKind.rare => Icons.auto_awesome_rounded,
      QuestKind.sellA || QuestKind.sellB => Icons.storefront_rounded,
      QuestKind.defeat => Icons.shield_rounded,
      QuestKind.earn => Icons.savings_rounded,
      QuestKind.levelUp => Icons.upgrade_rounded,
      QuestKind.unlock => Icons.lock_open_rounded,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: q.done ? const Color(0xFF2B5A3E) : const Color(0xFF213B66),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: q.done ? const Color(0xFF5CF0A8) : Colors.transparent, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFF2E5C9E), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFFFFD447), size: 26),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Tr.quest(q.kind, q.target, world.region), style: gs(15)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    height: 8,
                    child: LinearProgressIndicator(
                        value: q.progress / q.target, backgroundColor: Colors.white24, color: const Color(0xFFFFD447)),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${fmtNum(q.progress)}/${fmtNum(q.target)}', style: gs(12, color: Colors.white70)),
                    const Spacer(),
                    if (q.coins > 0) ...[const CoinIcon(size: 15), const SizedBox(width: 3), Text(fmtNum(q.coins), style: gs(13))],
                    if (q.gems > 0) ...[const SizedBox(width: 8), const GemIcon(size: 15), const SizedBox(width: 3), Text('${q.gems}', style: gs(13))],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GameButton(
            enabled: q.done,
            onTap: () {
              if (world.claimQuest(i)) {
                setState(() {});
                _haptic(heavy: true);
                _save();
              }
            },
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            radius: 12,
            color: const Color(0xFFFFB13D),
            shade: const Color(0xFFC77A12),
            child: Text(Tr.t('claim'), style: gs(15)),
          ),
        ],
      ),
    );
  }

  Widget _expeditionView() {
    final nextIdx = (world.regionIndex + 1) % regions.length;
    final next = regions[nextIdx];
    final bonus = (world.completed * 25);
    return _dimmed(
      child: Panel(
        title: '${Tr.t('expedition')}${world.star > 0 ? '  ★${world.star}' : ''}',
        onClose: _closePanels,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in regions) _regionRow(r),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.trending_up_rounded, color: Color(0xFF5CF0A8), size: 20),
                  const SizedBox(width: 6),
                  Text('${Tr.t('bonus')}: +$bonus%', style: gs(15, color: const Color(0xFF5CF0A8))),
                ],
              ),
              const SizedBox(height: 6),
              Text(Tr.t('loopInfo'), style: gs(12, weight: 500, color: Colors.white70, height: 1.35)),
              const SizedBox(height: 14),
              if (world.regionComplete) ...[
                Text(Tr.t('travelInfo'), textAlign: TextAlign.center, style: gs(13, weight: 600, color: Colors.white, height: 1.35)),
                const SizedBox(height: 10),
                GameButton(
                  onTap: _travel,
                  color: const Color(0xFF39B5F0),
                  shade: const Color(0xFF1F7FB3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sailing_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Text('${Tr.t('travelTo')} ${Tr.region(next)}', style: gs(18)),
                    ],
                  ),
                ),
              ] else
                Text(Tr.t('travelLocked'), textAlign: TextAlign.center, style: gs(14, color: const Color(0xFFFFE28A))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _regionRow(RegionDef r) {
    final here = r.index == world.regionIndex;
    final done = r.index < world.regionIndex || (here && world.regionComplete);
    final icon = switch (r.source) {
      SourceKind.river => Icons.set_meal_rounded,
      SourceKind.quarry => Icons.diamond_rounded,
      SourceKind.grove => Icons.forest_rounded,
    };
    final color = switch (r.source) {
      SourceKind.river => const Color(0xFF3D8BEA),
      SourceKind.quarry => const Color(0xFF8E5BD6),
      SourceKind.grove => const Color(0xFF2E9E5B),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: here ? const Color(0xFF2E5C9E) : const Color(0xFF213B66),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: here ? const Color(0xFFFFD447) : Colors.transparent, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Tr.region(r), style: gs(17)),
                Text(Tr.t('regiondesc_${r.key}'), style: gs(11.5, weight: 500, color: Colors.white70)),
              ],
            ),
          ),
          if (done)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF5CF0A8), size: 26)
          else if (here)
            Text(Tr.t('current'), style: gs(12, color: const Color(0xFFFFD447)))
          else
            const Icon(Icons.lock_rounded, color: Colors.white38, size: 22),
        ],
      ),
    );
  }

  Widget _offlineView() {
    return _dimmed(
      onDismiss: _collectOffline,
      child: Panel(
        title: Tr.t('welcomeBack'),
        onClose: _collectOffline,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.nights_stay_rounded, color: Color(0xFFFFE28A), size: 44),
              const SizedBox(height: 6),
              Text(Tr.t('offlineEarned'), textAlign: TextAlign.center, style: gs(16)),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [const CoinIcon(size: 30), const SizedBox(width: 8), Text(fmtNum(_offline), style: gs(32))],
              ),
              const SizedBox(height: 14),
              GameButton(
                onTap: _collectOffline,
                color: const Color(0xFFFFB13D),
                shade: const Color(0xFFC77A12),
                child: Text(Tr.t('collect'), style: gs(20)),
              ),
            ],
          ),
        ),
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

/// Small portrait of an outfit for the wardrobe.
class _OutfitPainter extends CustomPainter {
  _OutfitPainter(this.look);

  final Look look;

  @override
  void paint(Canvas canvas, Size size) {
    final q = size.width / 1.6;
    final f = Offset(size.width / 2, size.height * 0.98);
    final p = Paint()..isAntiAlias = true;
    canvas.drawOval(Rect.fromCenter(center: f.translate(0, -0.05 * q), width: 0.9 * q, height: 0.3 * q), p..color = const Color(0x33000000));
    final bc = f.translate(0, -0.64 * q);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: bc, width: 0.84 * q, height: 0.86 * q), Radius.circular(0.38 * q)),
        p..color = look.coatDark);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: bc.translate(-0.05 * q, -0.04 * q), width: 0.7 * q, height: 0.76 * q),
            Radius.circular(0.33 * q)),
        p..color = look.coat);
    canvas.drawOval(Rect.fromCenter(center: f.translate(0, -0.27 * q), width: 0.86 * q, height: 0.2 * q), p..color = look.trim);
    final scarf = look.scarf;
    if (scarf != null) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: f.translate(0, -0.99 * q), width: 0.68 * q, height: 0.18 * q),
              Radius.circular(0.09 * q)),
          p..color = scarf);
    }
    final hc = f.translate(0, -1.2 * q);
    canvas.drawCircle(hc, 0.44 * q, p..color = look.coat);
    canvas.drawCircle(hc.translate(0, 0.03 * q), 0.35 * q, p..color = look.trim);
    canvas.drawCircle(hc.translate(0, 0.04 * q), 0.27 * q, p..color = look.skin);
    p.color = const Color(0xFF1E2238);
    canvas.drawOval(Rect.fromCenter(center: hc.translate(-0.095 * q, 0.03 * q), width: 0.065 * q, height: 0.095 * q), p);
    canvas.drawOval(Rect.fromCenter(center: hc.translate(0.095 * q, 0.03 * q), width: 0.065 * q, height: 0.095 * q), p);
  }

  @override
  bool shouldRepaint(covariant _OutfitPainter oldDelegate) => oldDelegate.look != look;
}
