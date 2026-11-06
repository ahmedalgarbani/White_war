import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:white_war/game/world.dart';

/// A scripted player that plays the whole loop: gather, cook, sell, collect,
/// unlock, level up stations, claim quests and travel.
class Bot {
  Bot(this.w);

  GameWorld w;
  String why = '';
  Offset _lastPos = Offset.zero;
  int _stuck = 0;
  int _detour = 0;
  double _detourSign = 1;

  bool _goTo(Offset target, {double near = 0.25}) {
    final d = target - w.player.pos;
    if (d.distance < near) {
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
    why = '';
    for (var i = 0; i < w.quests.length; i++) {
      if (w.quests[i].done) w.claimQuest(i);
    }
    final p = w.player;
    // keep loading while standing on a pile, like a player collecting a full stack
    for (final pile in w.pickPiles) {
      if (pile.zone.contains(p.pos) && pile.items.isNotEmpty && !p.isFull) {
        why = 'loading';
        w.input = Offset.zero;
        return;
      }
    }
    if (p.carries(Cat.prodA) && !w.standA.stock.isFull) {
      why = 'deliverA';
      _goTo(w.standA.stock.zone.center);
      return;
    }
    if (p.carries(Cat.prodB) && !w.standB!.stock.isFull) {
      why = 'deliverB';
      _goTo(w.standB!.stock.zone.center);
      return;
    }
    for (final t in w.tiles) {
      if (w.tileVisible(t) && w.money >= t.price - t.paid) {
        why = 'tile ${t.def.id}';
        _goTo(t.def.pos);
        return;
      }
    }
    // keep enough coins for the next unlock, spend the surplus on station levels
    var reserve = 0;
    for (final t in w.tiles) {
      if (!w.tileVisible(t)) continue;
      final r = t.price - t.paid;
      if (reserve == 0 || r < reserve) reserve = r;
    }
    for (final t in w.levelTiles) {
      if (w.levelTileVisible(t) && w.money - reserve >= w.levelPrice(t.kind) - t.paid + 30 * w.mul) {
        why = 'level ${t.kind.name}';
        _goTo(t.pos);
        return;
      }
    }
    if (p.carries(Cat.raw)) {
      final b = w.procB;
      final target = (b != null && !b.input.isFull && b.input.items.length < 3) ? b.input : w.procA.input;
      if (!target.isFull) {
        why = 'deliverRaw';
        _goTo(target.zone.center);
        return;
      }
    }
    for (final c in w.cashPiles) {
      if (c.amount >= 40 * w.costMul) {
        why = 'cash';
        _goTo(c.zone.center);
        return;
      }
    }
    final pb = w.procB?.output;
    if (pb != null && pb.items.length >= 3 && !p.isFull) {
      why = 'pickB';
      _goTo(pb.zone.center);
      return;
    }
    if (w.procA.output.items.length >= 6 && !p.isFull) {
      why = 'pickA';
      _goTo(w.procA.output.zone.center);
      return;
    }
    if (w.rawPad.items.length >= 6 && !p.isFull) {
      why = 'pickRaw';
      _goTo(w.rawPad.zone.center);
      return;
    }
    why = 'harvest';
    if (w.isRiver) {
      _goTo(const Offset(-3.2, -0.6));
    } else {
      final n = w.nearestNode(w.player.pos, 30);
      if (n == null) {
        _goTo(const Offset(-3.0, -1.0));
      } else {
        _goTo(n.pos + const Offset(1.0, 0.0), near: 0.5);
      }
    }
  }
}

const double dt = 1 / 30;

void run(Bot bot, double seconds) {
  for (var t = 0.0; t < seconds; t += dt) {
    bot.think();
    bot.w.update(dt);
    bot.w.sfx.clear();
    bot.w.events.clear();
  }
}

GameWorld newWorld({int region = 0}) {
  final w = GameWorld(regionIndex: region)..started = true;
  w.cam.size = const Size(400, 800);
  return w;
}

void main() {
  test('the economy loop earns money and unlocks helpers', () {
    final bot = Bot(newWorld());
    run(bot, 240);
    expect(bot.w.earned, greaterThan(100));
    expect(bot.w.unlocked, contains('h1'));
    expect(bot.w.harvesters, isNotEmpty);
  });

  test('field regions are mined and chopped', () {
    for (final r in [1, 2]) {
      final bot = Bot(newWorld(region: r));
      run(bot, 240);
      expect(bot.w.earned, greaterThan(100 * bot.w.mul), reason: 'region $r');
      expect(bot.w.unlocked, contains('h1'), reason: 'region $r');
    }
  });

  test('the full expedition can be played through three regions', () {
    final bot = Bot(newWorld());
    final times = <String>[];
    for (var region = 0; region < 3; region++) {
      var t = 0.0;
      while (!bot.w.regionComplete && t < 100 * 60) {
        run(bot, 30);
        t += 30;
      }
      final w = bot.w;
      final levels = w.slv.values.fold(0, (a, b) => a + b);
      times.add('${w.region.key}: ${(t / 60).toStringAsFixed(1)} min, raids=${w.raid.index}, '
          'levels=$levels, quests=${w.regionQuests}, crystals=${w.crystals}, upg=${w.upg.values.fold(0, (a, b) => a + b)}');
      expect(w.regionComplete, isTrue, reason: 'region ${w.region.key} not finished in time');
      // spend crystals like a player would
      for (var k = 0; k < 40; k++) {
        final u = Upg.values[k % Upg.values.length];
        w.buyUpgrade(u);
      }
      bot.w = w.travel()..cam.size = const Size(400, 800);
    }
    // ignore: avoid_print
    print(times.join('\n'));
    expect(bot.w.star, 1);
    expect(bot.w.completed, 3);
  });

  test('raids freeze the river, spawn wolves and end', () {
    final w = newWorld();
    final bot = Bot(w);
    w.unlock('h1', silent: true);
    w.unlock('h2', silent: true);
    w.triggerRaidSoon();
    for (var i = 0; i < 8; i++) {
      w.rawPad.items.add(Item.fish);
    }
    w.player.pos = const Offset(0.7, -2.5);
    for (var t = 0.0; t < 6; t += dt) {
      w.update(dt);
    }
    expect(w.raid.active, isTrue);
    expect(w.raid.freeze, greaterThan(0.5));
    for (var t = 0.0; t < 60; t += dt) {
      w.update(dt);
    }
    expect(w.raid.active, isFalse);
    expect(w.raid.index, 1);
    expect(w.crystals, greaterThan(0));
    expect(bot.w, w);
  });

  test('boss raids spawn a boss that can be beaten', () {
    final w = newWorld();
    w.applyDemo('all');
    w.triggerRaidSoon(boss: true);
    var sawBoss = false;
    for (var t = 0.0; t < 120 && (w.raid.index < 4); t += dt) {
      w.update(dt);
      if (w.enemies.any((e) => e.boss)) sawBoss = true;
    }
    expect(sawBoss, isTrue);
    expect(w.raid.index, 4);
  });

  test('save and load round-trip keeps progress', () {
    final bot = Bot(newWorld(region: 1));
    run(bot, 300);
    final w = bot.w;
    final json = w.toJson();
    final w2 = GameWorld.fromSave(json);
    expect(w2.regionIndex, 1);
    expect(w2.unlocked, w.unlocked);
    expect(w2.money, json['money']);
    expect(w2.harvesters.length, w.harvesters.length);
    expect(w2.couriers.length, w.couriers.length);
    expect(w2.slv, w.slv);
    expect(w2.quests.length, 3);
  });

  test('version 1 saves are migrated', () {
    final v1 = {
      'v': 1,
      'money': 321,
      'crystals': 7,
      'upg': {'power': 2, 'kitchen': 3},
      'unlocked': ['harp1', 'porter1', 'harp2', 'chowder'],
      'piles': {
        'fishPad': [0, 1, 0],
        'grillOut': [3, 3],
      },
    };
    final w = GameWorld.fromSave(v1);
    expect(w.regionIndex, 0);
    expect(w.money, 321);
    expect(w.unlocked, containsAll(['h1', 'porter1', 'h2', 'zoneB']));
    expect(w.zoneB, isTrue);
    expect(w.upg[Upg.helpers], 3);
    expect(w.rawPad.items, [Item.fish, Item.goldFish, Item.fish]);
    expect(w.procA.output.items.length, 2);
  });

  test('offline earnings need an automated chain', () {
    final w = newWorld();
    expect(w.offlineReward(3600), 0);
    w.applyDemo('all');
    expect(w.offlineReward(3600), greaterThan(0));
    expect(w.offlineReward(99999), w.offlineReward(3600));
  });

  test('outfits cost crystals and can be worn', () {
    final w = newWorld();
    expect(w.buyOutfit(1), isFalse);
    w.crystals = 100;
    expect(w.buyOutfit(1), isTrue);
    expect(w.outfit, 1);
    expect(w.crystals, 100 - outfits[1].cost);
    expect(w.buyOutfit(0), isTrue);
    expect(w.outfit, 0);
  });
}
