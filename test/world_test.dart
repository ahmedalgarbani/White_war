import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:white_war/game/world.dart';

/// A simple scripted player used to exercise the whole economy loop.
class Bot {
  Bot(this.w);

  final GameWorld w;
  Offset _lastPos = Offset.zero;
  int _stuck = 0;
  int _detour = 0;
  double _detourSign = 1;

  bool _goTo(Offset target) {
    final d = target - w.player.pos;
    if (d.distance < 0.25) {
      w.input = Offset.zero;
      _stuck = 0;
      return true;
    }
    var dir = d / d.distance;
    if ((w.player.pos - _lastPos).distance < 0.01) {
      _stuck++;
    } else {
      _stuck = 0;
    }
    _lastPos = w.player.pos;
    if (_stuck > 6) {
      _detour = 20;
      _detourSign = -_detourSign;
      _stuck = 0;
    }
    if (_detour > 0) {
      _detour--;
      dir = Offset(-dir.dy * _detourSign, dir.dx * _detourSign);
    }
    w.input = dir;
    return false;
  }

  void think() {
    final p = w.player;
    final cat = p.carryCat;
    if (cat == Cat.fish) {
      final pot = w.pot;
      final target = (pot != null && pot.input.items.length < 3) ? pot.input.zone.center : w.grill.input.zone.center;
      _goTo(target);
      return;
    }
    if (cat == Cat.cake) {
      _goTo(w.standA.stock.zone.center);
      return;
    }
    if (cat == Cat.chowder) {
      _goTo(w.standB!.stock.zone.center);
      return;
    }
    for (final t in w.tiles) {
      if (w.tileVisible(t) && w.money >= t.def.price - t.paid) {
        _goTo(t.def.pos);
        return;
      }
    }
    for (final c in w.cashPiles) {
      if (c.amount >= 40) {
        _goTo(c.zone.center);
        return;
      }
    }
    final potOut = w.pot?.output;
    if (potOut != null && potOut.items.length >= 3) {
      _goTo(potOut.zone.center);
      return;
    }
    if (w.grill.output.items.length >= 6) {
      _goTo(w.grill.output.zone.center);
      return;
    }
    if (w.fishPad.items.length >= 6) {
      _goTo(w.fishPad.zone.center);
      return;
    }
    _goTo(const Offset(-3.2, -0.6));
  }
}

void run(GameWorld w, double seconds, {Bot? bot}) {
  const dt = 1 / 30;
  for (var t = 0.0; t < seconds; t += dt) {
    bot?.think();
    w.update(dt);
    w.sfx.clear();
    w.events.clear();
  }
}

GameWorld newWorld() {
  final w = GameWorld()..started = true;
  w.cam.size = const Size(400, 800);
  return w;
}

void main() {
  test('the economy loop earns money and unlocks helpers', () {
    final w = newWorld();
    final bot = Bot(w);
    run(w, 240, bot: bot);
    expect(w.earned, greaterThan(100));
    expect(w.unlocked, contains('harp1'));
    expect(w.harpooners, isNotEmpty);
  });

  test('a long session reaches the chowder house and survives raids', () {
    final w = newWorld();
    final bot = Bot(w);
    run(w, 1800, bot: bot);
    // ignore: avoid_print
    print('after 30 min: unlocked=${w.unlocked.length}/${unlockDefs.length} earned=${w.earned} '
        'money=${w.money} crystals=${w.crystals} raids=${w.raid.index}');
    expect(w.unlocked, contains('chowder'));
    expect(w.raid.index, greaterThan(0));
    expect(w.crystals + w.upg.values.fold(0, (a, b) => a + b), greaterThan(0));
  });

  test('raids freeze the river, spawn wolves and end', () {
    final w = newWorld();
    w.unlock('harp1', silent: true);
    w.unlock('harp2', silent: true);
    w.triggerRaidSoon();
    for (var i = 0; i < 8; i++) {
      w.fishPad.items.add(Item.fish);
    }
    w.player.pos = const Offset(0.7, -2.5);
    run(w, 6);
    expect(w.raid.active, isTrue);
    expect(w.raid.freeze, greaterThan(0.5));
    run(w, 60);
    expect(w.raid.active, isFalse);
    expect(w.raid.index, 1);
    expect(w.crystals, greaterThan(0));
  });

  test('save and load round-trip keeps progress', () {
    final w = newWorld();
    final bot = Bot(w);
    run(w, 200, bot: bot);
    final json = w.toJson();
    final w2 = newWorld()..loadJson(json);
    expect(w2.unlocked, w.unlocked);
    expect(w2.money, json['money']);
    expect(w2.harpooners.length, w.harpooners.length);
    expect(w2.couriers.length, w.couriers.length);
  });

  test('demo mode builds every station', () {
    final w = newWorld()..applyDemo('all');
    expect(w.zoneB, isTrue);
    expect(w.lighthouse, isTrue);
    run(w, 20);
    expect(w.pot, isNotNull);
  });
}
