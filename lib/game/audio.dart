import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'world.dart';

/// Small sound manager: a few pooled players per effect plus a looping track.
/// Every call is fire-and-forget and failures are swallowed so audio problems
/// can never break the game loop.
class AudioManager {
  bool soundOn = true;
  bool musicOn = true;

  final Map<Sfx, List<AudioPlayer>> _pool = {};
  final Map<Sfx, int> _next = {};
  final Map<Sfx, int> _last = {};
  final Stopwatch _clock = Stopwatch()..start();
  AudioPlayer? _music;
  bool _ready = false;
  bool _musicWanted = false;

  static const Map<Sfx, String> _files = {
    Sfx.throwSpear: 'throw.wav',
    Sfx.hit: 'hit.wav',
    Sfx.pop: 'pop.wav',
    Sfx.coin: 'coin.wav',
    Sfx.unlock: 'unlock.wav',
    Sfx.alarm: 'alarm.wav',
    Sfx.howl: 'howl.wav',
    Sfx.poof: 'poof.wav',
    Sfx.snowball: 'snowball.wav',
    Sfx.victory: 'victory.wav',
  };

  static const Map<Sfx, double> _volume = {
    Sfx.throwSpear: 0.35,
    Sfx.hit: 0.55,
    Sfx.pop: 0.45,
    Sfx.coin: 0.4,
    Sfx.unlock: 0.8,
    Sfx.alarm: 0.75,
    Sfx.howl: 0.7,
    Sfx.poof: 0.6,
    Sfx.snowball: 0.5,
    Sfx.victory: 0.8,
  };

  static const Map<Sfx, int> _gapMs = {
    Sfx.throwSpear: 70,
    Sfx.hit: 60,
    Sfx.pop: 55,
    Sfx.coin: 70,
    Sfx.snowball: 60,
    Sfx.poof: 80,
  };

  Future<void> init() async {
    try {
      final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      await AudioPlayer.global.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());
      for (final e in _files.entries) {
        final busy = e.key == Sfx.pop || e.key == Sfx.coin || e.key == Sfx.throwSpear || e.key == Sfx.hit;
        final list = <AudioPlayer>[];
        for (var i = 0; i < (busy ? 4 : 2); i++) {
          final p = AudioPlayer();
          await p.setReleaseMode(ReleaseMode.stop);
          if (android) await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setVolume(_volume[e.key] ?? 0.7);
          await p.setSource(AssetSource('audio/${e.value}'));
          list.add(p);
        }
        _pool[e.key] = list;
      }
      final m = AudioPlayer();
      await m.setReleaseMode(ReleaseMode.loop);
      await m.setVolume(0.3);
      await m.setSource(AssetSource('audio/music.ogg'));
      _music = m;
      _ready = true;
      if (_musicWanted && musicOn) unawaited(m.resume().catchError((_) {}));
    } catch (e) {
      debugPrint('audio disabled: $e');
    }
  }

  void play(Sfx s) {
    if (!soundOn || !_ready) return;
    final now = _clock.elapsedMilliseconds;
    if (now - (_last[s] ?? -100000) < (_gapMs[s] ?? 40)) return;
    _last[s] = now;
    final list = _pool[s];
    if (list == null || list.isEmpty) return;
    final i = (_next[s] ?? 0) % list.length;
    _next[s] = i + 1;
    final p = list[i];
    unawaited(() async {
      try {
        await p.stop();
        await p.resume();
      } catch (_) {}
    }());
  }

  void startMusic() {
    _musicWanted = true;
    final m = _music;
    if (m == null || !musicOn) return;
    unawaited(m.resume().catchError((_) {}));
  }

  void pauseMusic() {
    final m = _music;
    if (m == null) return;
    unawaited(m.pause().catchError((_) {}));
  }

  void setMusic(bool on) {
    musicOn = on;
    if (on && _musicWanted) {
      startMusic();
    } else {
      pauseMusic();
    }
  }
}
