import 'dart:math' as math;
import 'dart:ui';

import 'defs.dart';
import 'iso.dart';

export 'defs.dart';

// =============================================================================
// Entities
// =============================================================================

class Actor {
  Offset pos;
  Offset vel = Offset.zero;
  double facing;
  double walk = 0;
  double move = 0;
  Look look;
  final List<Item> carry = [];
  final List<Item> inbound = [];
  int capacity;
  double cd = 0;
  double action = 0;
  double pop = 1;

  Actor(this.pos, this.look, {this.facing = 0.8, this.capacity = 6});

  Cat? get carryCat {
    if (carry.isNotEmpty) return catOf(carry.first);
    if (inbound.isNotEmpty) return catOf(inbound.first);
    return null;
  }

  Item? get carryRep => carry.isNotEmpty ? carry.first : (inbound.isNotEmpty ? inbound.first : null);
  int get load => carry.length + inbound.length;
  bool get isFull => load >= capacity;
  Offset get dir => Offset(math.cos(facing), math.sin(facing));
  Offset get stackPos => pos + dir * 0.5;

  bool carries(Cat c) => carry.any((it) => catOf(it) == c) || inbound.any((it) => catOf(it) == c);

  /// Height above the ground of stack slot [i] (items may have different heights).
  double stackZ(int i) {
    var z = 0.55;
    for (var j = 0; j < i; j++) {
      final k = j - carry.length;
      final it = j < carry.length ? carry[j] : (k < inbound.length ? inbound[k] : null);
      z += it == null ? 0.12 : itemH(it);
    }
    return z;
  }

  void faceTo(Offset d) {
    if (d.dx * d.dx + d.dy * d.dy > 1e-8) facing = math.atan2(d.dy, d.dx);
  }
}

class Courier extends Actor {
  final Pile from;
  final Pile to;
  int state = 0;
  double wait = 0;

  Courier(super.pos, super.look, this.from, this.to) : super(capacity: 8);
}

/// Gathers the region's raw resource: harpoons fish from the dock, or walks to
/// rocks / trees in the field and hits them.
class Harvester extends Actor {
  final Offset home;
  Node? node;

  Harvester(super.pos, super.look)
      : home = pos,
        super(facing: math.pi);
}

class Cashier extends Actor {
  CashPile? target;
  double collectCd = 0;

  Cashier(super.pos, super.look);
}

class Pile {
  final String id;
  final Rect zone;
  final Offset at;
  final double baseZ;
  int capacity;
  final Cat cat;
  final int cols;
  final double gap;
  final Item rep;
  final List<Item> items = [];
  int incoming = 0;
  double bounce = 0;
  double warn = 0;

  Pile(this.id, this.zone, this.at, this.baseZ, this.capacity, this.cat, this.cols, this.gap, this.rep);

  bool get isFull => items.length + incoming >= capacity;
  int get space => capacity - items.length - incoming;
  double get layerH => itemH(rep);

  Offset colOffset(int col) {
    if (cols == 1) return Offset.zero;
    if (cols == 2) return Offset(0, col == 0 ? -gap : gap);
    return Offset(col.isOdd ? gap : -gap, col >= 2 ? gap : -gap);
  }

  Offset slotXY(int i) => at + colOffset(i % cols);
  double slotZ(int i) => baseZ + (i ~/ cols) * layerH;
}

class Processor {
  final String id;
  final Offset pos;
  final bool isB;
  final Pile input;
  final Pile output;
  final Actor chef;
  final Offset workAt;
  final double workZ;
  final double baseTime;
  final Item product;
  Item? working;
  double t = 0;
  double anim = 0;
  double pop = 1;
  double steamCd = 0;

  Processor({
    required this.id,
    required this.pos,
    required this.isB,
    required this.input,
    required this.output,
    required this.chef,
    required this.workAt,
    required this.workZ,
    required this.baseTime,
    required this.product,
  });

  int yieldOf(Item raw) => isB
      ? (isRare(raw) ? 2 : (isBig(raw) ? 3 : 1))
      : (isRare(raw) ? 6 : (isBig(raw) ? 8 : 3));
}

class Customer extends Actor {
  int want;
  int got = 0;
  int pending = 0;
  double hop = 0;
  double hopV = 0;
  final double phase;
  bool done = false;
  Offset target;

  Customer(super.pos, super.look, this.want, this.phase)
      : target = pos,
        super(capacity: 0);
}

class CashPile {
  final String id;
  final Rect zone;
  final Offset at;
  int amount = 0;
  double bounce = 0;

  CashPile(this.id, this.zone, this.at);
}

class Counter {
  final String id;
  final Offset pos;
  final double hx;
  final double hy;
  final Pile stock;
  final CashPile cash;
  final Item product;
  final List<Offset> slots;
  final Offset entry;
  final Rect crowdArea;
  final Rect lane;
  final Color canopy;
  final List<Customer> queue = [];
  final List<Customer> leaving = [];
  final List<Customer> crowd = [];
  double buyCd = 0;
  double spawnCd = 0;
  double pop = 1;

  Counter({
    required this.id,
    required this.pos,
    required this.hx,
    required this.hy,
    required this.stock,
    required this.cash,
    required this.product,
    required this.slots,
    required this.entry,
    required this.crowdArea,
    required this.lane,
    required this.canopy,
  });
}

class UnlockTile {
  final UnlockDef def;
  final int price;
  int paid = 0;
  double appear = 0;
  double glow = 0;

  UnlockTile(this.def, this.price);

  Rect get zone => Rect.fromCenter(center: def.pos, width: 1.6, height: 1.6);
}

class LevelTile {
  final StationKind kind;
  final Offset pos;
  int paid = 0;
  double appear = 0;
  double glow = 0;
  double flash = 0;

  LevelTile(this.kind, this.pos);

  Rect get zone => Rect.fromCenter(center: pos, width: 1.25, height: 1.25);
}

class Fish {
  Offset pos;
  final double baseX;
  final double speed;
  final Item kind;
  int hp;
  final int maxHp;
  double phase;
  double flash = 0;
  int pending = 0;
  double vis;
  bool alive = true;

  Fish(this.pos, this.baseX, this.speed, this.kind, this.hp, this.phase, this.vis) : maxHp = hp;

  bool get doomed => pending >= hp;
}

/// A rock or tree in the field that can be mined / chopped and grows back.
class Node {
  final Offset pos;
  Item kind;
  int hp;
  int maxHp;
  bool alive = true;
  double regrow = 0;
  double grow = 1;
  double shake = 0;
  double fall = 1;
  final double fallDir;
  final double seed;

  Node(this.pos, this.kind, this.hp, this.fallDir, this.seed) : maxHp = hp;
}

class Enemy {
  Offset pos;
  int hp;
  final int maxHp;
  final bool boss;
  final double speed;
  final int steal;
  int state = 0; // 0 = approach, 1 = flee
  Pile? target;
  final List<Item> stolen = [];
  Pile? stolenFrom;
  double phase;
  double flash = 0;
  int pending = 0;
  double facing = 0;
  bool alive = true;
  double life = 0;

  Enemy(this.pos, this.hp, this.boss, this.speed, this.phase, this.steal) : maxHp = hp;
}

class Proj {
  final ProjKind kind;
  final Offset from;
  final double fromZ;
  final Object target;
  final int dmg;
  final double dur;
  double t = 0;
  Offset pos;
  double z;
  Offset dir = const Offset(1, 0);
  double dz = 0;
  bool done = false;

  Proj(this.kind, this.from, this.fromZ, this.target, this.dmg, this.dur)
      : pos = from,
        z = fromZ;
}

/// An item (or a coin when [item] is null) flying in an arc between two places.
class Flight {
  final Item? item;
  final Offset from;
  final double fromZ;
  final Offset Function() to;
  final double Function() toZ;
  final double dur;
  final double arc;
  final void Function()? onLand;
  final double spin;
  double t = 0;
  Offset pos;
  double z;
  bool done = false;

  Flight(this.item, this.from, this.fromZ, this.to, this.toZ, this.dur, this.arc, this.onLand, {this.spin = 0})
      : pos = from,
        z = fromZ;
}

class Particle {
  double x, y, z, vx, vy, vz;
  double life = 0;
  final double max;
  final double size;
  final Color color;
  final PK kind;
  final double grav;
  double rot;
  final double vr;

  Particle(this.kind, this.x, this.y, this.z, this.vx, this.vy, this.vz, this.max, this.size, this.color,
      {this.grav = 0, this.rot = 0, this.vr = 0});
}

class FloatText {
  final Offset pos;
  final double z;
  final String text;
  final Color color;
  final double size;
  final double max;
  double life = 0;

  FloatText(this.pos, this.z, this.text, this.color, {this.size = 17, this.max = 1.1});
}

/// A coin or crystal flying (in screen space) towards the HUD counters.
class HudFly {
  final Offset from;
  final bool gem;
  final int value;
  final double dur;
  double t;
  bool done = false;

  HudFly(this.from, this.gem, this.value, this.dur, double delay) : t = -delay;
}

class Cannon {
  final Offset pos;
  double cd = 0.5;
  double aim = math.pi;
  double recoil = 0;
  double pop = 1;

  Cannon(this.pos);
}

class Tree {
  final Offset pos;
  final double size;
  final double tint;
  final bool inZoneB;

  Tree(this.pos, this.size, this.tint, this.inZoneB);
}

class Prop {
  final PropKind kind;
  final Offset pos;
  final double size;
  final bool inZoneB;

  Prop(this.kind, this.pos, {this.size = 1, this.inZoneB = false});
}

class Ob {
  final Rect? rect;
  final Offset? c;
  final double r;

  const Ob.rect(Rect this.rect)
      : c = null,
        r = 0;
  const Ob.circle(Offset this.c, this.r) : rect = null;

  bool hit(Offset p) {
    final rr = rect;
    if (rr != null) return rr.contains(p);
    return (p - c!).distanceSquared < r * r;
  }
}

class Raid {
  bool enabled = false;
  bool active = false;
  bool boss = false;
  double timer = 75;
  int index = 0;
  double freeze = 0;
  int toSpawn = 0;
  int total = 0;
  double spawnCd = 0;
  int earned = 0;
  int defeated = 0;
  bool howled = false;
}

class Quest {
  final QuestKind kind;
  final int target;
  final int coins;
  final int gems;
  int progress = 0;

  Quest(this.kind, this.target, this.coins, this.gems);

  bool get done => progress >= target;

  Map<String, dynamic> toJson() => {'k': kind.name, 't': target, 'c': coins, 'g': gems, 'p': progress};

  static Quest? fromJson(Object? j) {
    if (j is! Map) return null;
    final k = QuestKind.values.where((e) => e.name == j['k']).firstOrNull;
    if (k == null) return null;
    int i(Object? v) => v is num ? v.toInt() : 0;
    return Quest(k, math.max(1, i(j['t'])), i(j['c']), i(j['g']))..progress = i(j['p']);
  }
}

// =============================================================================
// The world (one region of the expedition)
// =============================================================================

class GameWorld {
  GameWorld({this.regionIndex = 0, this.star = 0})
      : region = regions[regionIndex % regions.length],
        defs = unlocksFor(regions[regionIndex % regions.length]) {
    _build();
  }

  final int regionIndex;
  final int star;
  final RegionDef region;
  final List<UnlockDef> defs;

  final math.Random rnd = math.Random();
  final IsoCamera cam = IsoCamera();
  double time = 0;
  double playTime = 0;
  bool started = false;
  bool dirty = false;

  // ---- meta progression (carried to the next region)
  int crystals = 0;
  final Map<Upg, int> upg = {for (final u in Upg.values) u: 0};
  int completed = 0;
  int outfit = 0;
  final Set<int> outfitsOwned = {0};
  int questLevel = 0;
  int lifetimeEarned = 0;

  // ---- region state
  int money = 0;
  int earned = 0;
  int regionQuests = 0;
  final Set<String> unlocked = <String>{};
  final Map<StationKind, int> slv = {for (final k in StationKind.values) k: 0};
  final List<Quest> quests = [];

  late final Actor player;
  Offset input = Offset.zero;
  double _pickCd = 0;
  double _payCd = 0;
  double _cashCd = 0;
  double _throwCd = 0;
  double _fishCd = 0;
  double _coinFxCd = 0;
  double _tileDwell = 0;

  late final Pile rawPad;
  late final Processor procA;
  late final Counter standA;
  Processor? procB;
  Counter? standB;
  Cashier? cashier;

  final List<Pile> piles = [];
  final List<Pile> pickPiles = [];
  final List<Pile> dropPiles = [];
  final List<CashPile> cashPiles = [];
  final List<Processor> processors = [];
  final List<Counter> counters = [];
  final List<Harvester> harvesters = [];
  final List<Courier> couriers = [];
  final List<Cannon> cannons = [];
  final List<Fish> fish = [];
  final List<Node> nodes = [];
  final List<Proj> projs = [];
  final List<Flight> flights = [];
  final List<Enemy> enemies = [];
  final List<Particle> parts = [];
  final List<FloatText> texts = [];
  final List<HudFly> hudFlies = [];
  final List<UnlockTile> tiles = [];
  final List<LevelTile> levelTiles = [];
  final List<Tree> trees = [];
  final List<Prop> props = [];
  final List<Offset> fencePosts = [];
  final List<Ob> obstacles = [];
  final Raid raid = Raid();
  bool zoneB = false;
  bool landmark = false;
  double landmarkT = 0;
  final List<Sfx> sfx = [];
  final List<String> events = [];
  double shake = 0;
  Offset hudCoin = const Offset(40, 40);
  Offset hudGem = const Offset(40, 90);

  double rr(double a, double b) => a + rnd.nextDouble() * (b - a);

  bool get isRiver => region.source == SourceKind.river;

  /// Multiplier for sale prices in this region of the expedition.
  double get mul => math.pow(6, regionIndex + 3 * star).toDouble();

  /// Costs grow a little faster than prices, so permanent bonuses and
  /// workshop upgrades don't make later regions trivial.
  double get costMul => mul * (1 + 1.0 * regionIndex) * (1 + 0.5 * star);

  // ------------------------------------------------------------------ stats
  int lv(Upg u) => upg[u] ?? 0;
  int sl(StationKind k) => slv[k] ?? 0;
  double get playerSpeed => 4.4 * (1 + 0.07 * lv(Upg.speed));
  double get playerRate => 0.6 * math.pow(0.92, lv(Upg.rate)).toDouble();
  int get playerDmg => 1 + lv(Upg.power);
  int get harvesterDmg => 1 + lv(Upg.power) ~/ 2;
  double get harvesterRate => 1.2 * math.pow(0.9, lv(Upg.helpers)).toDouble();
  int get cannonDmg => (3 + lv(Upg.power)) * (1 + regionIndex);
  int get playerCap => 8 + 3 * lv(Upg.capacity);
  int get courierCap => 8 + lv(Upg.capacity);
  double get courierSpeed => 2.8 * (1 + 0.07 * lv(Upg.helpers));
  double get incomeBonus =>
      (1 + 0.25 * completed) * (1 + 0.06 * lv(Upg.income)) * (landmark ? 2 : 1);
  bool get canHarvest => raid.freeze < 0.05;
  int get progress => unlocked.length;
  int get progressMax => defs.length;
  bool get regionComplete => landmark;

  int priceOf(Item it) {
    final b = catOf(it) == Cat.prodB;
    final lvl = sl(b ? StationKind.standB : StationKind.standA);
    final v = (b ? 16 : 4) * mul * incomeBonus * (1 + 0.12 * lvl);
    return math.max(1, v.round());
  }

  int levelPrice(StationKind k) => (levelBaseCost[k]! * math.pow(1.6, sl(k)) * costMul).round();

  bool stationExists(StationKind k) => switch (k) {
        StationKind.procB || StationKind.standB => zoneB,
        _ => true,
      };

  int upgCost(Upg u) => lv(u) >= upgMax ? -1 : upgCosts[lv(u)];

  bool buyUpgrade(Upg u) {
    final c = upgCost(u);
    if (c < 0 || crystals < c) return false;
    crystals -= c;
    upg[u] = lv(u) + 1;
    _applyUpgrades();
    dirty = true;
    sfx.add(Sfx.unlock);
    return true;
  }

  bool buyOutfit(int i) {
    if (i < 0 || i >= outfits.length) return false;
    if (outfitsOwned.contains(i)) {
      wearOutfit(i);
      return true;
    }
    if (crystals < outfits[i].cost) return false;
    crystals -= outfits[i].cost;
    outfitsOwned.add(i);
    wearOutfit(i);
    sfx.add(Sfx.unlock);
    return true;
  }

  void wearOutfit(int i) {
    outfit = i;
    player.look = outfits[i].look;
    dirty = true;
  }

  void _applyUpgrades() {
    player.capacity = playerCap;
    for (final c in couriers) {
      c.capacity = courierCap;
    }
  }

  void _applyLevels() {
    rawPad.capacity = 20 + 6 * sl(StationKind.pad);
    procA.output.capacity = 40 + 4 * sl(StationKind.procA);
    standA.stock.capacity = 32 + 4 * sl(StationKind.standA);
    procB?.output.capacity = 24 + 4 * sl(StationKind.procB);
    standB?.stock.capacity = 24 + 4 * sl(StationKind.standB);
  }

  bool tileVisible(UnlockTile t) => !unlocked.contains(t.def.id) && t.def.req.every(unlocked.contains);

  bool levelTileVisible(LevelTile t) =>
      started && unlocked.contains('h1') && stationExists(t.kind) && sl(t.kind) < stationMaxLevel - 1;

  // ------------------------------------------------------------------ build
  void _build() {
    player = Actor(const Offset(0.4, -1.0), outfits[0].look, facing: 2.3, capacity: 8);
    rawPad = Pile('rawPad', Rect.fromCenter(center: const Offset(0.7, -3.7), width: 1.9, height: 1.9),
        const Offset(0.7, -3.7), 0.03, 20, Cat.raw, 2, 0.3, region.raw);
    final aIn = Pile('procAIn', Rect.fromCenter(center: const Offset(4.0, -3.6), width: 1.5, height: 1.2),
        const Offset(4.0, -2.15), 0.81, 8, Cat.raw, 1, 0, region.raw);
    final aOut = Pile('procAOut', Rect.fromCenter(center: const Offset(5.45, -1.0), width: 1.4, height: 1.6),
        const Offset(5.45, -1.0), 0.03, 40, Cat.prodA, 4, 0.27, region.prodA);
    procA = Processor(
        id: 'procA',
        pos: const Offset(4.0, -1.6),
        isB: false,
        input: aIn,
        output: aOut,
        chef: Actor(const Offset(3.0, -1.6), region.chefA, facing: 0),
        workAt: const Offset(4.0, -1.12),
        workZ: 0.87,
        baseTime: 1.3,
        product: region.prodA);
    final sA = Pile('standA', Rect.fromCenter(center: const Offset(4.6, -5.85), width: 1.7, height: 1.3),
        const Offset(4.6, -7.0), 0.92, 32, Cat.prodA, 4, 0.27, region.prodA);
    final cashA = CashPile('cashA', Rect.fromCenter(center: const Offset(7.1, -5.7), width: 1.5, height: 1.5),
        const Offset(7.1, -5.7));
    standA = Counter(
        id: 'standA',
        pos: const Offset(4.6, -7.0),
        hx: 1.15,
        hy: 0.4,
        stock: sA,
        cash: cashA,
        product: region.prodA,
        slots: const [Offset(4.6, -8.1), Offset(4.6, -9.1), Offset(4.6, -10.1), Offset(4.6, -11.1)],
        entry: const Offset(4.6, -14.5),
        crowdArea: const Rect.fromLTRB(-0.6, -15.5, 10.4, -8.3),
        lane: const Rect.fromLTRB(3.75, -16, 5.45, -7),
        canopy: region.canopyA);
    piles.addAll([rawPad, aIn, aOut, sA]);
    pickPiles.addAll([rawPad, aOut]);
    dropPiles.addAll([aIn, sA]);
    cashPiles.add(cashA);
    processors.add(procA);
    counters.add(standA);
    _fillCrowd(standA, 46);
    for (final d in defs) {
      tiles.add(UnlockTile(d, (d.price * costMul).round()));
    }
    for (final k in StationKind.values) {
      levelTiles.add(LevelTile(k, levelTileSpots[k]!));
    }
    _buildScenery();
    _rebuildFences();
    _rebuildObstacles();
    if (isRiver) {
      for (var i = 0; i < 18; i++) {
        _spawnFish(rr(-18, 16), 1);
      }
    } else {
      final r = math.Random(regionIndex * 97 + 5);
      for (final p in nodeSpots) {
        final k = _rollNodeKind();
        nodes.add(Node(p + Offset((r.nextDouble() - 0.5) * 0.3, (r.nextDouble() - 0.5) * 0.3), k, _nodeHp(k),
            r.nextDouble() < 0.5 ? -1 : 1, r.nextDouble()));
      }
    }
    _ensureQuests();
    cam.cx = player.pos.dx;
    cam.cy = player.pos.dy;
  }

  Item _rollNodeKind() {
    final roll = rnd.nextDouble();
    return roll < 0.08 ? region.rare : (roll < 0.14 ? region.big : region.raw);
  }

  int _nodeHp(Item k) => isRare(k) ? region.nodeHp - 1 : (isBig(k) ? region.nodeHp * 2 + 1 : region.nodeHp);

  void _openZoneB() {
    if (zoneB) return;
    zoneB = true;
    final bIn = Pile('procBIn', Rect.fromCenter(center: const Offset(4.95, 6.45), width: 1.5, height: 1.4),
        const Offset(3.45, 6.25), 0.47, 8, Cat.raw, 1, 0, region.raw);
    final bOut = Pile('procBOut', Rect.fromCenter(center: const Offset(4.95, 8.75), width: 1.5, height: 1.5),
        const Offset(4.95, 8.75), 0.03, 24, Cat.prodB, 4, 0.28, region.prodB);
    procB = Processor(
        id: 'procB',
        pos: const Offset(3.4, 7.7),
        isB: true,
        input: bIn,
        output: bOut,
        chef: Actor(const Offset(2.2, 7.45), region.chefB, facing: 0),
        workAt: const Offset(3.4, 7.7),
        workZ: 1.05,
        baseTime: 2.4,
        product: region.prodB);
    final sB = Pile('standB', Rect.fromCenter(center: const Offset(9.25, 7.4), width: 1.3, height: 1.7),
        const Offset(10.5, 7.4), 0.92, 24, Cat.prodB, 4, 0.27, region.prodB);
    final cashB = CashPile('cashB', Rect.fromCenter(center: const Offset(8.9, 9.7), width: 1.5, height: 1.5),
        const Offset(8.9, 9.7));
    standB = Counter(
        id: 'standB',
        pos: const Offset(10.5, 7.4),
        hx: 0.4,
        hy: 1.15,
        stock: sB,
        cash: cashB,
        product: region.prodB,
        slots: const [Offset(11.6, 7.4), Offset(12.6, 7.4), Offset(13.6, 7.4), Offset(14.6, 7.4)],
        entry: const Offset(17.6, 7.4),
        crowdArea: const Rect.fromLTRB(11.3, 3.2, 17.8, 11.8),
        lane: const Rect.fromLTRB(10.5, 6.65, 19, 8.15),
        canopy: region.canopyB);
    piles.addAll([bIn, bOut, sB]);
    pickPiles.add(bOut);
    dropPiles.addAll([bIn, sB]);
    cashPiles.add(cashB);
    processors.add(procB!);
    counters.add(standB!);
    _fillCrowd(standB!, 30);
    trees.removeWhere((t) => t.inZoneB);
    props.removeWhere((p) => p.inZoneB);
    _applyLevels();
    _rebuildFences();
    _rebuildObstacles();
  }

  void _fillCrowd(Counter k, int n) {
    final r = math.Random(k.id.hashCode + regionIndex * 31);
    var tries = 0;
    while (k.crowd.length < n && tries < n * 40) {
      tries++;
      final p = Offset(k.crowdArea.left + r.nextDouble() * k.crowdArea.width,
          k.crowdArea.top + r.nextDouble() * k.crowdArea.height);
      if (k.lane.inflate(0.25).contains(p)) continue;
      if (k.crowd.any((o) => (o.pos - p).distanceSquared < 0.62)) continue;
      final c = Customer(p, _randomLook(r), 0, r.nextDouble() * 6.28);
      c.faceTo(k.pos - p);
      k.crowd.add(c);
    }
  }

  Look _randomLook([math.Random? r]) {
    final g = r ?? rnd;
    final pal = region.coats;
    final coat = pal[g.nextInt(pal.length)];
    final hat = pal[g.nextInt(pal.length)];
    return Look(
      coat: coat,
      coatDark: darken(coat, 0.22),
      hat: hat,
      skin: skinPalette[g.nextInt(skinPalette.length)],
      hatKind: g.nextDouble() < 0.25 ? 3 : 0,
      trim: g.nextDouble() < 0.5 ? const Color(0xFFF7F4EE) : lighten(coat, 0.55),
    );
  }

  bool _reservedForScenery(Offset p) {
    if (p.dx < riverX1 + 0.7 && p.dx > riverX0 - 1.0) return true;
    if (const Rect.fromLTRB(-1.8, -7.8, 11.3, 11.8).contains(p)) return true;
    if (const Rect.fromLTRB(-1.4, -16.6, 11.2, -7.4).contains(p)) return true;
    if (const Rect.fromLTRB(10.8, 2.4, 19.2, 12.6).contains(p)) return true;
    return false;
  }

  void _buildScenery() {
    final r = math.Random(1337 + regionIndex);
    final quarry = region.source == SourceKind.quarry;
    // the far side of the river / field
    for (var x = -11.9; x > -23; x -= 1.25) {
      for (var y = -36.0; y < 36; y += 1.35) {
        final p = Offset(x + (r.nextDouble() - 0.5) * 0.8, y + (r.nextDouble() - 0.5) * 0.9);
        if (quarry && r.nextDouble() < 0.7) {
          if (r.nextDouble() < 0.55) {
            props.add(Prop(r.nextDouble() < 0.8 ? PropKind.boulder : PropKind.crystals, p, size: 0.9 + r.nextDouble() * 0.9));
          }
          continue;
        }
        trees.add(Tree(p, 0.85 + r.nextDouble() * 0.45, r.nextDouble(), false));
      }
    }
    // around the camp
    final placed = <Offset>[];
    for (var i = 0; i < 700 && placed.length < 150; i++) {
      final p = Offset(-1.5 + r.nextDouble() * 26, -30 + r.nextDouble() * 60);
      if (_reservedForScenery(p)) continue;
      if (placed.any((o) => (o - p).distanceSquared < 1.7)) continue;
      placed.add(p);
      if (quarry && r.nextDouble() < 0.45) {
        props.add(Prop(PropKind.boulder, p, size: 0.8 + r.nextDouble() * 0.7));
      } else {
        trees.add(Tree(p, 0.8 + r.nextDouble() * 0.5, r.nextDouble(), false));
      }
    }
    // the locked plot is overgrown until it is bought
    final zb = <Offset>[];
    for (var i = 0; i < 200 && zb.length < 12; i++) {
      final p = Offset(0.4 + r.nextDouble() * 9.4, 4.9 + r.nextDouble() * 5.5);
      if (zb.any((o) => (o - p).distanceSquared < 2.2)) continue;
      zb.add(p);
      if (quarry) {
        props.add(Prop(PropKind.boulder, p, size: 0.8 + r.nextDouble() * 0.6, inZoneB: true));
      } else {
        trees.add(Tree(p, 0.75 + r.nextDouble() * 0.4, r.nextDouble(), true));
      }
    }
    props.addAll([
      Prop(PropKind.lantern, const Offset(-1.15, -6.75)),
      Prop(PropKind.lantern, const Offset(10.25, -6.75)),
      Prop(PropKind.lantern, const Offset(-1.15, 2.3)),
      Prop(PropKind.lantern, const Offset(6.35, -1.5)),
      Prop(PropKind.crate, const Offset(9.6, -0.9)),
      Prop(PropKind.crate, const Offset(9.75, 0.15), size: 0.8),
      Prop(PropKind.sign, const Offset(5.9, 3.7)),
      Prop(PropKind.mound, const Offset(2.5, 8.6), inZoneB: true, size: 1.4),
      Prop(PropKind.mound, const Offset(8.0, 9.9), inZoneB: true, size: 1.1),
    ]);
    switch (region.source) {
      case SourceKind.river:
        props.addAll([Prop(PropKind.barrel, const Offset(-1.0, -4.9)), Prop(PropKind.barrel, const Offset(9.7, 2.6))]);
      case SourceKind.quarry:
        props.addAll([
          Prop(PropKind.cart, const Offset(-0.9, -4.9)),
          Prop(PropKind.crystals, const Offset(9.7, 2.6), size: 0.8),
          Prop(PropKind.crystals, const Offset(-10.6, -6.6), size: 1.2),
        ]);
      case SourceKind.grove:
        props.addAll([
          Prop(PropKind.logpile, const Offset(-0.9, -4.9)),
          Prop(PropKind.stump, const Offset(9.7, 2.6)),
          Prop(PropKind.logpile, const Offset(-10.4, 4.6)),
        ]);
    }
    for (var i = 0; i < 40; i++) {
      final p = Offset(-1.5 + r.nextDouble() * 26, -28 + r.nextDouble() * 56);
      if (_reservedForScenery(p)) continue;
      props.add(Prop(r.nextDouble() < 0.6 ? PropKind.mound : PropKind.rock, p, size: 0.7 + r.nextDouble() * 0.9));
    }
  }

  void _rebuildFences() {
    fencePosts.clear();
    void line(Offset a, Offset b, [List<(double, double)> gaps = const []]) {
      final d = b - a;
      final len = d.distance;
      final n = (len / 0.34).round();
      for (var i = 0; i <= n; i++) {
        final t = i / n;
        final along = len * t;
        if (gaps.any((g) => along > g.$1 && along < g.$2)) continue;
        final p = a + d * t;
        if (fencePosts.any((o) => (o - p).distanceSquared < 0.01)) continue;
        fencePosts.add(p);
      }
    }

    line(const Offset(-1.35, -7.0), const Offset(10.5, -7.0), [(3.42 + 1.35, 5.78 + 1.35)]);
    if (!zoneB) {
      line(const Offset(10.5, -7.0), const Offset(10.5, 4.0));
      line(const Offset(-1.35, 4.0), const Offset(10.5, 4.0), [(3.72 + 1.35, 5.28 + 1.35)]);
    } else {
      line(const Offset(10.5, -7.0), const Offset(10.5, 11.0), [(6.2 + 7.0, 8.6 + 7.0)]);
      line(const Offset(-1.35, 11.0), const Offset(10.5, 11.0));
    }
  }

  void _rebuildObstacles() {
    obstacles
      ..clear()
      ..add(const Ob.rect(Rect.fromLTRB(3.25, -2.85, 4.75, -0.35)))
      ..add(const Ob.rect(Rect.fromLTRB(3.3, -7.6, 5.9, -6.45)));
    if (zoneB) {
      obstacles
        ..add(const Ob.circle(Offset(3.4, 7.7), 1.05))
        ..add(const Ob.rect(Rect.fromLTRB(2.9, 5.7, 4.0, 6.8)))
        ..add(const Ob.rect(Rect.fromLTRB(9.95, 6.1, 11.0, 8.7)));
    }
    for (final c in cannons) {
      obstacles.add(Ob.circle(c.pos, 0.72));
    }
    if (landmark) obstacles.add(const Ob.circle(landmarkPos, 0.95));
  }

  // ------------------------------------------------------------------ loop
  void update(double dt) {
    time += dt;
    if (started) {
      playTime += dt;
      _updatePlayer(dt);
      _updateThrowers(dt);
      _updateInteractions(dt);
      _updateTiles(dt);
      _updateRaid(dt);
      _updateCashier(dt);
    } else {
      cam.cx = 1.6 + math.sin(time * 0.12) * 2.4;
      cam.cy = -2.2 + math.cos(time * 0.09) * 2.0;
    }
    _updateCamera(dt);
    if (isRiver) {
      _updateFish(dt);
    } else {
      _updateNodes(dt);
    }
    _updateProjs(dt);
    _updateFlights(dt);
    for (final p in processors) {
      _updateProcessor(p, dt);
    }
    for (final c in couriers) {
      _updateCourier(c, dt);
    }
    for (final k in counters) {
      _updateCounter(k, dt);
    }
    _updateEnemies(dt);
    _updateCannons(dt);
    _updateFx(dt);
  }

  void _updateCamera(double dt) {
    if (started) {
      final target = player.pos + player.vel * 0.12;
      final k = 1 - math.exp(-dt * 5);
      cam.cx += (target.dx - cam.cx) * k;
      cam.cy += (target.dy - cam.cy) * k;
    }
    if (shake > 0) {
      shake = math.max(0, shake - dt);
      final m = shake * 16;
      cam.shake = Offset(rr(-m, m), rr(-m, m));
    } else {
      cam.shake = Offset.zero;
    }
  }

  bool _walkable(Offset p) {
    final left = isRiver ? dockRect.contains(p) : fieldRect.contains(p);
    final inside = left || walkA.contains(p) || (zoneB && walkB.contains(p));
    if (!inside) return false;
    for (final o in obstacles) {
      if (o.hit(p)) return false;
    }
    if (!isRiver && p.dx < -1.0) {
      for (final n in nodes) {
        if (n.alive && (n.pos - p).distanceSquared < 0.2) return false;
      }
    }
    return true;
  }

  Offset _resolveMove(Offset from, Offset to) {
    if (_walkable(to)) return to;
    final d = to - from;
    final len = d.distance;
    if (len < 1e-9) return from;
    final dir = d / len;
    var best = from;
    var bestScore = len * 0.04;
    void consider(Offset p) {
      if (!_walkable(p)) return;
      final mv = p - from;
      final score = mv.dx * dir.dx + mv.dy * dir.dy;
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }

    // slide along walls; slightly rotated steps help around round obstacles
    consider(Offset(to.dx, from.dy));
    consider(Offset(from.dx, to.dy));
    for (final a in const [0.45, -0.45, 0.9, -0.9, 1.3, -1.3]) {
      final ca = math.cos(a), sa = math.sin(a);
      consider(from + Offset(d.dx * ca - d.dy * sa, d.dx * sa + d.dy * ca));
    }
    return best;
  }

  double groundZ(Offset p) => isRiver && dockRect.contains(p) && !walkA.contains(p) ? dockZ : 0;

  void _updatePlayer(double dt) {
    final p = player;
    final mag = input.distance;
    if (mag > 0.08) {
      final m = math.min(1.0, mag);
      final dir = input / mag;
      final v = dir * (playerSpeed * m);
      p.pos = _resolveMove(p.pos, p.pos + v * dt);
      p.faceTo(dir);
      p.vel = v;
      p.walk += dt * (7 + 6 * m);
      p.move = math.min(1, p.move + dt * 8);
    } else {
      p.vel = Offset.zero;
      p.move = math.max(0, p.move - dt * 8);
    }
    p.action = math.max(0, p.action - dt * 4);
  }

  // ------------------------------------------------------------------ harvesting
  int get _doomedFish {
    var n = 0;
    for (final f in fish) {
      if (f.alive && f.doomed) n++;
    }
    return n;
  }

  bool get padHasRoom => rawPad.items.length + rawPad.incoming + _doomedFish < rawPad.capacity;

  Fish? _nearestFish(Offset from, double range) {
    Fish? best;
    var bd = range * range;
    for (final f in fish) {
      if (!f.alive || f.doomed || f.vis < 0.8) continue;
      final d = (f.pos - from).distanceSquared;
      if (d < bd) {
        bd = d;
        best = f;
      }
    }
    return best;
  }

  Node? nearestNode(Offset from, double range, {Harvester? exclude}) {
    Node? best;
    var bd = range * range;
    for (final n in nodes) {
      if (!n.alive || n.grow < 0.95) continue;
      if (exclude != null && harvesters.any((h) => !identical(h, exclude) && identical(h.node, n))) continue;
      final d = (n.pos - from).distanceSquared;
      if (d < bd) {
        bd = d;
        best = n;
      }
    }
    return best;
  }

  Enemy? _nearestEnemy(Offset from, double range) {
    Enemy? best;
    var bd = range * range;
    for (final w in enemies) {
      if (!w.alive || w.pending >= w.hp) continue;
      final d = (w.pos - from).distanceSquared;
      if (d < bd) {
        bd = d;
        best = w;
      }
    }
    return best;
  }

  void _launch(ProjKind k, Offset from, double fz, Object target, int dmg) {
    Offset tp;
    if (target is Fish) {
      target.pending += dmg;
      tp = target.pos;
    } else {
      final w = target as Enemy;
      w.pending += dmg;
      tp = w.pos;
    }
    final dist = (tp - from).distance;
    final dur = k == ProjKind.cannonball ? 0.42 + dist * 0.05 : 0.16 + dist * 0.04;
    projs.add(Proj(k, from, fz, target, dmg, dur));
    sfx.add(Sfx.throwSpear);
  }

  void _updateThrowers(double dt) {
    _throwCd -= dt;
    final pz = groundZ(player.pos);
    if (_throwCd <= 0) {
      final w = _nearestEnemy(player.pos, 6.8);
      if (w != null) {
        _launch(ProjKind.snowball, player.pos, pz + 1.3, w, playerDmg);
        if (player.move < 0.2) player.faceTo(w.pos - player.pos);
        player.action = 1;
        _throwCd = playerRate;
      } else if (canHarvest && padHasRoom) {
        if (isRiver) {
          if (dockRect.contains(player.pos)) {
            final f = _nearestFish(player.pos, 7.8);
            if (f != null) {
              _launch(ProjKind.harpoon, player.pos, pz + 1.3, f, playerDmg);
              if (player.move < 0.2) player.faceTo(f.pos - player.pos);
              player.action = 1;
              _throwCd = playerRate;
            }
          }
        } else {
          final n = nearestNode(player.pos, 1.75);
          if (n != null) {
            if (player.move < 0.2) player.faceTo(n.pos - player.pos);
            player.action = 1;
            _strikeNode(n, playerDmg);
            _throwCd = playerRate;
          }
        }
      }
    }
    for (final h in harvesters) {
      h.action = math.max(0, h.action - dt * 4);
      if (h.pop < 1) h.pop = math.min(1, h.pop + dt * 2.5);
      if (isRiver) {
        _riverHarvester(h, dt);
      } else {
        _fieldHarvester(h, dt);
      }
    }
  }

  void _riverHarvester(Harvester h, double dt) {
    h.cd -= dt;
    if (h.cd > 0) return;
    final w = _nearestEnemy(h.pos, 7.5);
    if (w != null) {
      _launch(ProjKind.snowball, h.pos, dockZ + 1.3, w, harvesterDmg);
      h.faceTo(w.pos - h.pos);
      h.action = 1;
      h.cd = harvesterRate;
      return;
    }
    if (canHarvest && padHasRoom) {
      final f = _nearestFish(h.pos, 8.2);
      if (f != null) {
        _launch(ProjKind.harpoon, h.pos, dockZ + 1.3, f, harvesterDmg);
        h.faceTo(f.pos - h.pos);
        h.action = 1;
        h.cd = harvesterRate;
        return;
      }
    }
    h.cd = 0.2;
  }

  void _fieldHarvester(Harvester h, double dt) {
    h.cd -= dt;
    final speed = courierSpeed * 0.9;
    final w = _nearestEnemy(h.pos, 7.0);
    if (w != null) {
      h.move = math.max(0, h.move - dt * 8);
      if (h.cd <= 0) {
        _launch(ProjKind.snowball, h.pos, 1.3, w, harvesterDmg);
        h.faceTo(w.pos - h.pos);
        h.action = 1;
        h.cd = harvesterRate;
      }
      return;
    }
    if (!canHarvest || !padHasRoom) {
      h.node = null;
      _walkTo(h, h.home, speed, dt);
      return;
    }
    final cur = h.node;
    if (cur == null || !cur.alive) h.node = nearestNode(h.home, 3.6, exclude: h);
    final n = h.node;
    if (n == null) {
      _walkTo(h, h.home, speed, dt);
      return;
    }
    var d = h.home - n.pos;
    if (d.distance < 0.1) d = const Offset(1, 0);
    final stand = n.pos + d / d.distance * 0.85;
    if (!_walkTo(h, stand, speed, dt)) return;
    h.faceTo(n.pos - h.pos);
    if (h.cd <= 0) {
      h.action = 1;
      h.cd = harvesterRate;
      _strikeNode(n, harvesterDmg);
    }
  }

  void _strikeNode(Node n, int dmg) {
    if (!n.alive) return;
    n.hp -= dmg;
    n.shake = 1;
    final quarry = region.source == SourceKind.quarry;
    _burst(PK.chip, n.pos, 0.6, 6, quarry ? const Color(0xFFA8E6FF) : const Color(0xFFB07A4A),
        speed: 2.2, up: 3.2, size: 0.07, life: 0.6);
    sfx.add(quarry ? Sfx.mine : Sfx.chop);
    if (n.hp <= 0) _breakNode(n);
  }

  void _breakNode(Node n) {
    n.alive = false;
    n.regrow = 0;
    n.fall = 0;
    final it = n.kind;
    _burst(PK.puff, n.pos, 0.4, 8, const Color(0xFFFFFFFF), speed: 1.8, up: 1.4, size: 0.22);
    if (rawPad.isFull) return;
    final slot = rawPad.items.length + rawPad.incoming;
    rawPad.incoming++;
    flights.add(Flight(it, n.pos, 0.6, () => rawPad.slotXY(slot), () => rawPad.slotZ(slot), 0.7, 3.0, () {
      rawPad.incoming--;
      rawPad.items.add(it);
      rawPad.bounce = 1;
      sfx.add(Sfx.pop);
      _questEvent(QuestKind.harvest, 1);
    }, spin: 1));
    _rareBonus(it, n.pos);
  }

  void _rareBonus(Item it, Offset at) {
    if (!isRare(it) && !isBig(it)) return;
    if (isBig(it) && rnd.nextBool()) return;
    const n = 1;
    _gainGems(n, at, 0.6);
    texts.add(FloatText(at, 1.4, '+$n', const Color(0xFF7FE7FF)));
    if (isRare(it)) _questEvent(QuestKind.rare, 1);
  }

  void _updateNodes(double dt) {
    for (final n in nodes) {
      n.shake = math.max(0, n.shake - dt * 6);
      if (!n.alive) {
        n.fall = math.min(1, n.fall + dt * 1.8);
        n.regrow += dt;
        if (n.regrow >= region.regrow) {
          n.kind = _rollNodeKind();
          n.maxHp = _nodeHp(n.kind);
          n.hp = n.maxHp;
          n.alive = true;
          n.grow = 0;
        }
      } else if (n.grow < 1) {
        n.grow = math.min(1, n.grow + dt * 1.6);
      }
    }
  }

  // ------------------------------------------------------------------ projectiles
  void _updateProjs(double dt) {
    for (final p in projs) {
      p.t += dt;
      final t = p.target;
      final tp = t is Fish ? t.pos : (t as Enemy).pos;
      final tz = t is Fish ? waterZ + 0.15 : 0.6;
      final u = math.min(1.0, p.t / p.dur);
      final np = Offset.lerp(p.from, tp, u)!;
      final arcH = switch (p.kind) {
        ProjKind.cannonball => 2.4,
        ProjKind.snowball => 1.0,
        ProjKind.harpoon => 0.7,
      };
      final nz = p.fromZ + (tz - p.fromZ) * u + arcH * 4 * u * (1 - u);
      final d = np - p.pos;
      if (d.distanceSquared > 1e-9) p.dir = d;
      p.dz = nz - p.z;
      p.pos = np;
      p.z = nz;
      if (u >= 1) {
        p.done = true;
        _impact(p);
      }
    }
    projs.removeWhere((p) => p.done);
  }

  void _impact(Proj p) {
    final t = p.target;
    if (t is Fish) {
      t.pending = math.max(0, t.pending - p.dmg);
      _burst(PK.splash, t.pos, waterZ + 0.05, 7, const Color(0xFFE3F6FF), speed: 1.8, up: 3.2, size: 0.09);
      if (!t.alive) return;
      t.hp -= p.dmg;
      t.flash = 1;
      sfx.add(Sfx.hit);
      if (t.hp <= 0) _catchFish(t);
    } else if (t is Enemy) {
      t.pending = math.max(0, t.pending - p.dmg);
      final big = p.kind == ProjKind.cannonball;
      _burst(PK.puff, t.pos, 0.6, big ? 12 : 6, const Color(0xFFFFFFFF),
          speed: big ? 2.6 : 1.6, up: 1.5, size: big ? 0.3 : 0.2);
      sfx.add(Sfx.snowball);
      if (!t.alive) return;
      t.hp -= p.dmg;
      t.flash = 1;
      if (t.hp <= 0) _killEnemy(t);
    }
  }

  void _catchFish(Fish f) {
    f.alive = false;
    if (rawPad.isFull) return;
    final slot = rawPad.items.length + rawPad.incoming;
    rawPad.incoming++;
    final it = f.kind;
    flights.add(Flight(it, f.pos, waterZ + 0.1, () => rawPad.slotXY(slot), () => rawPad.slotZ(slot), 0.75, 3.4, () {
      rawPad.incoming--;
      rawPad.items.add(it);
      rawPad.bounce = 1;
      sfx.add(Sfx.pop);
      _questEvent(QuestKind.harvest, 1);
    }, spin: 1));
    _rareBonus(it, f.pos);
  }

  void _killEnemy(Enemy w) {
    w.alive = false;
    raid.defeated++;
    _burst(PK.puff, w.pos, 0.5, w.boss ? 36 : 18, const Color(0xFFFFFFFF),
        speed: w.boss ? 4 : 3, up: 2.5, size: w.boss ? 0.45 : 0.32, life: 0.9);
    _burst(PK.spark, w.pos, 0.6, w.boss ? 20 : 8, const Color(0xFF8DEBFF), speed: 2.5, up: 4);
    sfx.add(w.boss ? Sfx.victory : Sfx.poof);
    if (w.boss) shake = 0.4;
    final gems = w.boss ? 12 + 3 * regionIndex : 1 + regionIndex ~/ 2;
    raid.earned += gems;
    _gainGems(gems, w.pos, 0.8);
    texts.add(FloatText(w.pos, 1.5, '+$gems', const Color(0xFF7FE7FF), size: w.boss ? 26 : 17));
    _questEvent(QuestKind.defeat, 1);
    final src = w.stolenFrom;
    if (src != null) {
      for (final it in w.stolen) {
        if (src.isFull) break;
        final slot = src.items.length + src.incoming;
        src.incoming++;
        flights.add(Flight(it, w.pos, 0.8, () => src.slotXY(slot), () => src.slotZ(slot), 0.6, 2.2, () {
          src.incoming--;
          src.items.add(it);
          src.bounce = 1;
        }));
      }
    }
    w.stolen.clear();
  }

  void _updateCannons(double dt) {
    for (final c in cannons) {
      if (c.pop < 1) c.pop = math.min(1, c.pop + dt * 2.5);
      c.recoil = math.max(0, c.recoil - dt * 3);
      c.cd -= dt;
      final w = _nearestEnemy(c.pos, 9.5);
      if (w != null) {
        final want = math.atan2(w.pos.dy - c.pos.dy, w.pos.dx - c.pos.dx);
        c.aim = _lerpAngle(c.aim, want, math.min(1, dt * 8));
        if (c.cd <= 0) {
          _launch(ProjKind.cannonball, c.pos, 2.0, w, cannonDmg);
          c.cd = 1.1;
          c.recoil = 1;
        }
      } else {
        c.aim = _lerpAngle(c.aim, math.pi * 0.9, dt * 1.2);
      }
    }
  }

  double _lerpAngle(double a, double b, double t) {
    var d = (b - a) % (math.pi * 2);
    if (d > math.pi) d -= math.pi * 2;
    if (d < -math.pi) d += math.pi * 2;
    return a + d * t;
  }

  // ------------------------------------------------------------------ fish
  void _spawnFish(double y, double vis) {
    final roll = rnd.nextDouble();
    final kind = roll < 0.07 ? Item.goldFish : (roll < 0.12 ? Item.bigFish : Item.fish);
    final hp = switch (kind) {
      Item.goldFish => 2,
      Item.bigFish => 7,
      _ => 3,
    };
    final speed = -switch (kind) {
      Item.goldFish => rr(2.0, 2.6),
      Item.bigFish => rr(0.8, 1.1),
      _ => rr(1.1, 1.8),
    };
    final x = rr(riverX0 + 0.9, riverX1 - 0.7);
    fish.add(Fish(Offset(x, y), x, speed, kind, hp, rr(0, 6.28), vis));
  }

  void _updateFish(double dt) {
    final freeze = raid.freeze;
    for (final f in fish) {
      f.phase += dt * 2.2;
      f.pos = Offset(f.baseX + math.sin(f.phase * 0.8) * 0.28, f.pos.dy + f.speed * dt);
      f.flash = math.max(0, f.flash - dt * 5);
      if (freeze > 0.02) {
        f.vis = math.max(0, f.vis - dt * 1.6);
      } else {
        f.vis = math.min(1, f.vis + dt * 1.2);
      }
    }
    fish.removeWhere((f) => !f.alive || f.pos.dy < -22 || (freeze > 0.3 && f.vis <= 0 && f.pending == 0));
    if (freeze < 0.02) {
      _fishCd -= dt;
      if (_fishCd <= 0) {
        _fishCd = rr(0.5, 0.95);
        if (fish.length < 30) _spawnFish(18, 0);
      }
      if (fish.length < 12) _spawnFish(rr(-14, 12), 0);
    }
  }

  // ------------------------------------------------------------------ items
  void _pileToActor(Pile pile, Actor a) {
    final it = pile.items.removeLast();
    final idx = pile.items.length;
    final from = pile.slotXY(idx);
    final fz = pile.slotZ(idx);
    a.inbound.add(it);
    final target = a.load - 1;
    flights.add(Flight(it, from, fz, () => a.stackPos, () => groundZ(a.pos) + a.stackZ(target), 0.2, 0.9, () {
      a.inbound.remove(it);
      a.carry.add(it);
    }));
    pile.bounce = 0.6;
    sfx.add(Sfx.pop);
  }

  void _actorToPile(Actor a, Pile pile) {
    var idx = a.carry.length - 1;
    while (idx >= 0 && catOf(a.carry[idx]) != pile.cat) {
      idx--;
    }
    if (idx < 0) return;
    final fz = groundZ(a.pos) + a.stackZ(idx);
    final it = a.carry.removeAt(idx);
    final from = a.stackPos;
    final slot = pile.items.length + pile.incoming;
    pile.incoming++;
    flights.add(Flight(it, from, fz, () => pile.slotXY(slot), () => pile.slotZ(slot), 0.2, 0.8, () {
      pile.incoming--;
      pile.items.add(it);
      pile.bounce = 1;
    }));
    sfx.add(Sfx.pop);
  }

  void _updateInteractions(double dt) {
    final p = player;
    _pickCd -= dt;
    if (_pickCd <= 0) {
      var done = false;
      // the hero may carry a mixed stack: drop whatever each station accepts
      for (final pile in dropPiles) {
        if (!pile.zone.contains(p.pos) || !p.carry.any((it) => catOf(it) == pile.cat)) continue;
        if (!pile.isFull) {
          _actorToPile(p, pile);
          _pickCd = 0.06;
          done = true;
        } else {
          pile.warn = 1;
        }
        break;
      }
      if (!done && !p.isFull) {
        for (final pile in pickPiles) {
          if (pile.items.isNotEmpty && pile.zone.contains(p.pos)) {
            _pileToActor(pile, p);
            _pickCd = 0.06;
            break;
          }
        }
      }
    }
    _cashCd -= dt;
    if (_cashCd <= 0) {
      for (final c in cashPiles) {
        if (c.amount > 0 && c.zone.contains(p.pos)) {
          _collectFrom(c, c.at);
          _cashCd = 0.05;
          break;
        }
      }
    }
  }

  void _collectFrom(CashPile c, Offset fxFrom) {
    final chunk = math.min(c.amount, math.max((5 * mul).round(), (c.amount / 4).ceil()));
    c.amount -= chunk;
    c.bounce = 1;
    _gainMoney(chunk, fxFrom, 0.5);
  }

  void _gainMoney(int v, Offset at, double z) {
    hudFlies.add(HudFly(cam.w2s(at.dx, at.dy, z), false, v, 0.5 + rnd.nextDouble() * 0.15, 0));
  }

  void _gainGems(int n, Offset at, double z) {
    final s = cam.w2s(at.dx, at.dy, z);
    final shown = math.min(n, 8);
    for (var i = 0; i < shown; i++) {
      final v = i == shown - 1 ? n - (shown - 1) : 1;
      hudFlies.add(HudFly(s + Offset(rr(-12, 12), rr(-12, 12)), true, v, 0.65, i * 0.07));
    }
  }

  // ------------------------------------------------------------------ cashier
  void _updateCashier(double dt) {
    final c = cashier;
    if (c == null) return;
    if (c.pop < 1) c.pop = math.min(1, c.pop + dt * 2.5);
    c.action = math.max(0, c.action - dt * 4);
    final speed = courierSpeed * 1.1;
    var t = c.target;
    if (t == null || t.amount <= 0) {
      t = null;
      var best = 0;
      for (final cp in cashPiles) {
        if (cp.amount > best && cp.amount >= (8 * mul).round()) {
          best = cp.amount;
          t = cp;
        }
      }
      c.target = t;
    }
    if (t == null) {
      _walkTo(c, cashierHome, speed, dt);
      return;
    }
    if (!_walkTo(c, t.zone.center, speed, dt)) return;
    c.collectCd -= dt;
    if (c.collectCd <= 0 && t.amount > 0) {
      c.collectCd = 0.08;
      c.action = 1;
      _collectFrom(t, c.pos);
    }
  }

  // ------------------------------------------------------------------ tiles
  void _updateTiles(double dt) {
    _payCd -= dt;
    _coinFxCd -= dt;
    // paying starts only after standing on a tile for a moment, so walking
    // across one never spends coins by accident
    final onTile = tiles.any((t) => tileVisible(t) && t.zone.contains(player.pos)) ||
        levelTiles.any((t) => levelTileVisible(t) && t.zone.contains(player.pos));
    _tileDwell = onTile ? _tileDwell + dt : 0;
    if (_tileDwell < 0.35) _payCd = math.max(_payCd, 0.001);
    for (final t in tiles) {
      if (!tileVisible(t)) continue;
      t.appear = math.min(1, t.appear + dt * 2.2);
      final inside = t.zone.contains(player.pos);
      t.glow = inside ? math.min(1, t.glow + dt * 5) : math.max(0, t.glow - dt * 4);
      if (inside && _payCd <= 0 && money > 0 && t.paid < t.price) {
        t.paid += _pay(t.price - t.paid, t.price, t.def.pos);
        if (t.paid >= t.price) unlock(t.def.id);
      }
    }
    for (final t in levelTiles) {
      t.flash = math.max(0, t.flash - dt * 2);
      if (!levelTileVisible(t)) continue;
      t.appear = math.min(1, t.appear + dt * 2.2);
      final inside = t.zone.contains(player.pos);
      t.glow = inside ? math.min(1, t.glow + dt * 5) : math.max(0, t.glow - dt * 4);
      final price = levelPrice(t.kind);
      if (inside && _payCd <= 0 && money > 0 && t.paid < price) {
        t.paid += _pay(price - t.paid, price, t.pos);
        if (t.paid >= price) _levelUp(t);
      }
    }
  }

  int _pay(int remain, int price, Offset target) {
    final step = math.max(1, (price / 36).ceil());
    final chunk = math.min(remain, math.min(money, step));
    money -= chunk;
    dirty = true;
    _payCd = 0.035;
    if (_coinFxCd <= 0) {
      _coinFxCd = 0.07;
      flights.add(Flight(null, player.pos, groundZ(player.pos) + 1.4, () => target, () => groundZ(target) + 0.05, 0.25,
          0.8, null));
      sfx.add(Sfx.coin);
    }
    return chunk;
  }

  void _levelUp(LevelTile t) {
    slv[t.kind] = sl(t.kind) + 1;
    t.paid = 0;
    t.flash = 1;
    t.appear = 0.35;
    _applyLevels();
    dirty = true;
    sfx.add(Sfx.unlock);
    final at = switch (t.kind) {
      StationKind.pad => rawPad.at,
      StationKind.procA => procA.pos,
      StationKind.standA => standA.pos,
      StationKind.procB => procB?.pos ?? t.pos,
      StationKind.standB => standB?.pos ?? t.pos,
    };
    _burst(PK.confetti, at, 1.2, 26, const Color(0xFFFFFFFF), speed: 3.5, up: 5.5, size: 0.1, life: 1.1);
    texts.add(FloatText(at, 2.4, 'LV ${sl(t.kind) + 1}', const Color(0xFF5CF0A8), size: 24, max: 1.4));
    _questEvent(QuestKind.levelUp, 1);
    events.add('level:${t.kind.name}:${sl(t.kind) + 1}');
  }

  void unlock(String id, {bool silent = false}) {
    if (unlocked.contains(id)) return;
    final def = defs.where((d) => d.id == id).firstOrNull;
    if (def == null) return;
    unlocked.add(id);
    switch (id) {
      case 'h1' || 'h2' || 'h3' || 'h4':
        harvesters.add(Harvester(def.pos, region.helper)..pop = silent ? 1 : 0);
      case 'porter1':
        _addCourier(def.pos, Looks.porter, rawPad, procA.input, silent);
      case 'waiter1':
        _addCourier(def.pos, Looks.waiter, procA.output, standA.stock, silent);
      case 'cannon1' || 'cannon2':
        cannons.add(Cannon(def.pos)..pop = silent ? 1 : 0);
        _rebuildObstacles();
        _pushPlayerOut();
      case 'zoneB':
        if (!silent) {
          for (final t in trees) {
            if (t.inZoneB) {
              _burst(PK.puff, t.pos, 0.6, 8, const Color(0xFFFFFFFF), speed: 2, up: 2.5, size: 0.35, life: 0.9);
            }
          }
          for (final p in props) {
            if (p.inZoneB) _burst(PK.puff, p.pos, 0.4, 6, const Color(0xFFFFFFFF), speed: 2, up: 2, size: 0.3, life: 0.8);
          }
        }
        _openZoneB();
      case 'porter2':
        _addCourier(def.pos, Looks.porter, rawPad, procB!.input, silent);
      case 'waiter2':
        _addCourier(def.pos, Looks.waiter, procB!.output, standB!.stock, silent);
      case 'cashier':
        cashier = Cashier(def.pos, Looks.cashier)..pop = silent ? 1 : 0;
      case 'landmark':
        landmark = true;
        _rebuildObstacles();
        _pushPlayerOut();
    }
    _applyUpgrades();
    dirty = true;
    if (!silent) {
      _questEvent(QuestKind.unlock, 1);
      sfx.add(id == 'landmark' ? Sfx.victory : Sfx.unlock);
      shake = 0.25;
      _burst(PK.confetti, def.pos, 0.8, 46, const Color(0xFFFFFFFF), speed: 4.5, up: 6.5, size: 0.12, life: 1.4);
      _burst(PK.ring, def.pos, 0.05, 1, const Color(0xFFFFFFFF), life: 0.7);
      events.add(switch (id) {
        'landmark' => 'landmark',
        'zoneB' => 'zoneB',
        _ => 'unlock:${def.name}',
      });
    }
  }

  void _pushPlayerOut() {
    if (_walkable(player.pos)) return;
    for (var r = 0.3; r < 3; r += 0.2) {
      for (var a = 0.0; a < math.pi * 2; a += 0.4) {
        final p = player.pos + Offset(math.cos(a), math.sin(a)) * r;
        if (_walkable(p)) {
          player.pos = p;
          return;
        }
      }
    }
  }

  void _addCourier(Offset pos, Look look, Pile from, Pile to, bool silent) {
    final c = Courier(pos, look, from, to);
    c.pop = silent ? 1 : 0;
    c.capacity = courierCap;
    couriers.add(c);
  }

  // ------------------------------------------------------------------ kitchens
  void _updateProcessor(Processor pr, double dt) {
    if (pr.pop < 1) pr.pop = math.min(1, pr.pop + dt * 2);
    final w = pr.working;
    if (w == null) {
      pr.anim = math.max(0, pr.anim - dt);
      if (pr.input.items.isNotEmpty) {
        final it = pr.input.items.last;
        if (pr.output.space >= 1) {
          pr.input.items.removeLast();
          pr.input.bounce = 0.5;
          pr.working = it;
          pr.t = 0;
        } else {
          pr.output.warn = math.max(pr.output.warn, 0.7);
        }
      }
      return;
    }
    pr.anim += dt;
    final lvl = sl(pr.isB ? StationKind.procB : StationKind.procA);
    pr.t += dt / (pr.baseTime * math.pow(0.86, lvl));
    pr.steamCd -= dt;
    if (pr.steamCd <= 0) {
      final sparks = region.source == SourceKind.quarry && !pr.isB;
      pr.steamCd = sparks ? 0.05 : (pr.isB ? 0.16 : 0.1);
      if (sparks) {
        parts.add(Particle(PK.spark, pr.workAt.dx, pr.workAt.dy, pr.workZ + 0.2, rr(-1.5, 1.5), rr(-1.5, 1.5),
            rr(1.0, 2.5), rr(0.25, 0.45), 0.05, const Color(0xFFBDF4FF),
            grav: 9));
      } else {
        parts.add(Particle(PK.steam, pr.workAt.dx + rr(-0.25, 0.25), pr.workAt.dy + rr(-0.25, 0.25), pr.workZ + 0.15,
            rr(-0.1, 0.1), rr(-0.1, 0.1), rr(0.8, 1.3), rr(0.8, 1.2), rr(0.16, 0.26), const Color(0xFFFFFFFF)));
      }
    }
    if (pr.t >= 1) {
      final n = pr.yieldOf(w);
      final out = pr.output;
      final prod = pr.product;
      for (var i = 0; i < n; i++) {
        final slot = out.items.length + out.incoming;
        out.incoming++;
        flights.add(Flight(prod, pr.workAt, pr.workZ + 0.1, () => out.slotXY(slot), () => out.slotZ(slot),
            0.32 + i * 0.05, 1.5, () {
          out.incoming--;
          out.items.add(prod);
          out.bounce = 1;
        }));
      }
      pr.working = null;
      pr.t = 0;
      sfx.add(Sfx.pop);
    }
  }

  bool _walkTo(Actor a, Offset target, double speed, double dt) {
    final d = target - a.pos;
    final dist = d.distance;
    if (dist < 0.06) {
      a.move = math.max(0, a.move - dt * 8);
      a.vel = Offset.zero;
      return true;
    }
    final step = math.min(dist, speed * dt);
    final dir = d / dist;
    a.pos += dir * step;
    a.vel = dir * speed;
    a.faceTo(dir);
    a.walk += dt * 11;
    a.move = math.min(1, a.move + dt * 8);
    return dist - step < 0.06;
  }

  void _updateCourier(Courier c, double dt) {
    if (c.pop < 1) c.pop = math.min(1, c.pop + dt * 2.5);
    final speed = courierSpeed;
    switch (c.state) {
      case 0:
        if (_walkTo(c, c.from.zone.center, speed, dt)) c.state = 1;
      case 1:
        c.move = math.max(0, c.move - dt * 8);
        c.cd -= dt;
        if (c.cd > 0) break;
        c.cd = 0.12;
        if (!c.isFull && c.from.items.isNotEmpty && (c.carryCat == null || c.carryCat == c.from.cat)) {
          _pileToActor(c.from, c);
          c.wait = 0;
        } else if (c.isFull || (c.load > 0 && c.wait > 1.0)) {
          c.state = 2;
          c.wait = 0;
        } else {
          c.wait += 0.12;
        }
      case 2:
        if (c.inbound.isNotEmpty) {
          c.move = math.max(0, c.move - dt * 8);
          break;
        }
        if (_walkTo(c, c.to.zone.center, speed, dt)) c.state = 3;
      case 3:
        c.move = math.max(0, c.move - dt * 8);
        c.cd -= dt;
        if (c.cd > 0) break;
        c.cd = 0.1;
        if (c.carry.isNotEmpty && !c.to.isFull) {
          _actorToPile(c, c.to);
        } else if (c.carry.isEmpty && c.inbound.isEmpty) {
          c.state = 0;
        } else {
          c.to.warn = 1;
          c.cd = 0.25;
        }
    }
  }

  // ------------------------------------------------------------------ customers
  void _updateCounter(Counter k, double dt) {
    if (k.pop < 1) k.pop = math.min(1, k.pop + dt * 2);
    if (k.queue.length < k.slots.length) {
      k.spawnCd -= dt;
      if (k.spawnCd <= 0) {
        final isA = catOf(k.product) == Cat.prodA;
        final want = isA ? 2 + rnd.nextInt(5) : 1 + rnd.nextInt(3);
        final c = Customer(k.entry + Offset(rr(-0.5, 0.5), rr(-0.5, 0.5)), _randomLook(), want, rr(0, 6.28));
        k.queue.add(c);
        k.spawnCd = 0.45;
      }
    }
    for (var i = 0; i < k.queue.length; i++) {
      final c = k.queue[i];
      if (_walkTo(c, k.slots[i], 2.6, dt)) c.faceTo(k.pos - c.pos);
    }
    if (k.queue.isNotEmpty) {
      final c = k.queue.first;
      final atSlot = (c.pos - k.slots.first).distanceSquared < 0.04;
      if (atSlot && c.got + c.pending < c.want) {
        k.buyCd -= dt;
        if (k.buyCd <= 0 && k.stock.items.isNotEmpty) {
          final isA = k.stock.cat == Cat.prodA;
          k.buyCd = 0.22 * math.pow(0.9, sl(isA ? StationKind.standA : StationKind.standB));
          final it = k.stock.items.removeLast();
          final idx = k.stock.items.length;
          final price = priceOf(it);
          c.pending++;
          k.stock.bounce = 0.6;
          final cash = k.cash;
          flights.add(Flight(it, k.stock.slotXY(idx), k.stock.slotZ(idx), () => c.pos, () => 1.0, 0.26, 0.7, () {
            c.pending--;
            c.got++;
            c.hopV = 2.2;
            _questEvent(isA ? QuestKind.sellA : QuestKind.sellB, 1);
            flights.add(Flight(null, c.pos, 1.2, () => cash.at, () => 0.1, 0.42, 1.6, () {
              cash.amount += price;
              cash.bounce = 1;
            }));
          }));
        }
      }
      if (c.got >= c.want && c.pending == 0) {
        c.done = true;
        k.queue.removeAt(0);
        k.leaving.add(c);
        c.target = k.entry + Offset(rr(-1.2, 1.2), rr(-1.2, 1.2));
        c.hopV = 3.2;
        parts.add(Particle(PK.heart, c.pos.dx, c.pos.dy, 2.0, 0, 0, 1.2, 1.1, 0.3, const Color(0xFFFF5D7A)));
        texts.add(FloatText(c.pos, 2.9, '+${fmtNum(c.want * priceOf(k.product))}', const Color(0xFFFFD447)));
      }
    }
    for (final c in k.leaving) {
      _walkTo(c, c.target, 2.4, dt);
      c.cd += dt;
    }
    k.leaving.removeWhere((c) => c.cd > 5 || (c.pos - c.target).distanceSquared < 0.05);
    for (final c in [...k.queue, ...k.leaving, ...k.crowd]) {
      if (c.hopV == 0 && c.hop == 0 && rnd.nextDouble() < dt * 0.08) c.hopV = 2.4;
      if (c.hopV != 0 || c.hop > 0) {
        c.hop += c.hopV * dt;
        c.hopV -= 13 * dt;
        if (c.hop <= 0) {
          c.hop = 0;
          c.hopV = 0;
        }
      }
    }
  }

  // ------------------------------------------------------------------ raids
  void _updateRaid(double dt) {
    final r = raid;
    if (!r.enabled) {
      if (unlocked.contains('h2') || playTime > 420) {
        r.enabled = true;
        r.timer = 75;
        dirty = true;
      }
      return;
    }
    if (!r.active) {
      r.freeze = math.max(0, r.freeze - dt * 0.5);
      r.timer -= dt;
      if (r.timer < 6 && !r.howled) {
        r.howled = true;
        sfx.add(Sfx.howl);
      }
      if (r.timer <= 0) _startRaid();
    } else {
      r.freeze = math.min(1, r.freeze + dt * 0.6);
      if (r.freeze > 0.5 && r.toSpawn > 0) {
        r.spawnCd -= dt;
        if (r.spawnCd <= 0) {
          _spawnEnemy(boss: r.boss && r.toSpawn == 1);
          r.toSpawn--;
          r.spawnCd = rr(0.45, 1.0);
        }
      }
      if (r.toSpawn == 0 && enemies.every((w) => !w.alive)) _endRaid();
    }
  }

  int get enemiesLeft => raid.toSpawn + enemies.where((w) => w.alive).length;
  bool get nextRaidIsBoss => raid.index % 4 == 3;

  void _startRaid() {
    raid.active = true;
    raid.howled = false;
    raid.defeated = 0;
    raid.earned = 0;
    raid.boss = nextRaidIsBoss;
    final n = math.min(3 + raid.index * 2, 18) + (raid.boss ? 1 : 0);
    raid.toSpawn = n;
    raid.total = n;
    raid.spawnCd = 1.0;
    sfx.add(raid.boss ? Sfx.boss : Sfx.alarm);
    events.add(raid.boss ? 'boss_start' : 'raid_start');
    shake = 0.35;
  }

  void _endRaid() {
    raid.active = false;
    raid.index++;
    raid.timer = 100 + rnd.nextDouble() * 25;
    final bonus = 1 + raid.index ~/ 2 + regionIndex;
    raid.earned += bonus;
    _gainGems(bonus, player.pos, 2.0);
    events.add('raid_end:${raid.earned}');
    sfx.add(Sfx.victory);
    enemies.clear();
    dirty = true;
  }

  void _spawnEnemy({bool boss = false}) {
    final base = math.min(3 + raid.index, 14) * region.enemyHp * (1 + star);
    final hp = math.max(1, (base * (boss ? 10 : 1)).round());
    final spd = math.min(region.enemySpeed + raid.index * 0.06, region.enemySpeed + 0.9) * (boss ? 0.72 : 1);
    final y = rr(-6.0, zoneB ? 10.0 : 3.0);
    enemies.add(Enemy(Offset(-15.5, y), hp, boss, spd, rr(0, 6.28), boss ? 3 : region.enemySteal));
  }

  Pile? _enemyTarget(Enemy w) {
    final cands = <Pile>[
      rawPad,
      procA.output,
      procA.input,
      if (procB != null) procB!.output,
      if (procB != null) procB!.input,
    ];
    Pile? best;
    var bd = double.infinity;
    for (final p in cands) {
      if (p.items.isEmpty) continue;
      final d = (p.at - w.pos).distanceSquared;
      if (d < bd) {
        bd = d;
        best = p;
      }
    }
    return best;
  }

  void _updateEnemies(double dt) {
    for (final w in enemies) {
      if (!w.alive) continue;
      w.life += dt;
      w.flash = math.max(0, w.flash - dt * 4);
      w.phase += dt * (w.boss ? 7 : 12);
      Offset goal;
      var spd = w.speed;
      if (w.state == 0) {
        if (w.target == null || w.target!.items.isEmpty) w.target = _enemyTarget(w);
        final tg = w.target;
        goal = tg?.at ?? const Offset(5.6, -1.0);
        if ((goal - w.pos).distanceSquared < (w.boss ? 1.0 : 0.6)) {
          if (tg != null && tg.items.isNotEmpty) {
            for (var i = 0; i < w.steal && tg.items.isNotEmpty; i++) {
              w.stolen.add(tg.items.removeLast());
            }
            w.stolenFrom = tg;
            tg.bounce = 1;
            texts.add(FloatText(tg.at, 1.4, '-${w.stolen.length}', const Color(0xFFFF5A5A)));
            sfx.add(Sfx.pop);
          }
          w.state = 1;
        }
      } else {
        goal = Offset(-17.5, w.pos.dy);
        spd *= 1.12;
        if (w.pos.dx < -16.8) w.alive = false;
      }
      var sep = Offset.zero;
      for (final o in enemies) {
        if (identical(o, w) || !o.alive) continue;
        final dd = w.pos - o.pos;
        final l2 = dd.distanceSquared;
        if (l2 < 0.7 && l2 > 1e-6) sep += dd / l2 * 0.25;
      }
      final dir = goal - w.pos;
      final len = dir.distance;
      if (len > 1e-3) {
        final v = dir / len * spd + sep;
        w.pos += v * dt;
        w.facing = math.atan2(v.dy, v.dx);
      }
    }
    enemies.removeWhere((w) => !w.alive);
  }

  // ------------------------------------------------------------------ quests
  void _ensureQuests() {
    while (quests.length < 3) {
      quests.add(_newQuest());
    }
  }

  static int _nice(double v) {
    if (v < 10) return math.max(1, v.round());
    if (v < 100) return (v / 5).round() * 5;
    if (v < 1000) return (v / 10).round() * 10;
    final p = math.pow(10, (math.log(v) / math.ln10).floor() - 1).toDouble();
    return ((v / p).round() * p).round();
  }

  Quest _newQuest() {
    final avail = <QuestKind>[QuestKind.harvest, QuestKind.sellA, QuestKind.earn, QuestKind.rare];
    if (zoneB) avail.add(QuestKind.sellB);
    if (raid.enabled) avail.add(QuestKind.defeat);
    if (unlocked.isNotEmpty) avail.add(QuestKind.levelUp);
    if (tiles.any(tileVisible)) avail.add(QuestKind.unlock);
    avail.removeWhere((k) => quests.any((q) => q.kind == k && !q.done));
    final k = avail.isEmpty ? QuestKind.harvest : avail[rnd.nextInt(avail.length)];
    final f = 1 + 0.25 * math.min(regionQuests, 12);
    final m = mul * (1 + 0.25 * completed);
    switch (k) {
      case QuestKind.harvest:
        final t = _nice(12 * f);
        return Quest(k, t, _nice(t * 7 * m), 1);
      case QuestKind.rare:
        final t = 2 + regionQuests ~/ 4;
        return Quest(k, t, 0, t + 1);
      case QuestKind.sellA:
        final t = _nice(30 * f);
        return Quest(k, t, _nice(t * 3 * m), 1);
      case QuestKind.sellB:
        final t = _nice(6 * f);
        return Quest(k, t, _nice(t * 14 * m), 1);
      case QuestKind.defeat:
        final t = _nice(4 * f);
        return Quest(k, t, 0, 2 + t ~/ 2);
      case QuestKind.earn:
        final t = _nice(300 * f * m);
        return Quest(k, t, _nice(t * 0.35), 1);
      case QuestKind.levelUp:
        final t = 1 + regionQuests ~/ 5;
        return Quest(k, t, _nice(250 * m * t), 2);
      case QuestKind.unlock:
        return Quest(k, 1, 0, 3);
    }
  }

  void _questEvent(QuestKind k, int n) {
    for (final q in quests) {
      if (q.kind != k || q.done) continue;
      q.progress = math.min(q.target, q.progress + n);
      if (q.done) {
        events.add('quest');
        sfx.add(Sfx.quest);
      }
    }
  }

  int get claimableQuests => quests.where((q) => q.done).length;

  bool claimQuest(int i) {
    if (i < 0 || i >= quests.length || !quests[i].done) return false;
    final q = quests[i];
    final from = Offset(cam.size.width / 2, cam.size.height * 0.45);
    if (q.coins > 0) hudFlies.add(HudFly(from, false, q.coins, 0.7, 0));
    final shown = math.min(q.gems, 8);
    for (var g = 0; g < shown; g++) {
      final v = g == shown - 1 ? q.gems - (shown - 1) : 1;
      hudFlies.add(HudFly(from + Offset(rr(-20, 20), rr(-20, 20)), true, v, 0.8, 0.1 + g * 0.06));
    }
    quests.removeAt(i);
    regionQuests++;
    questLevel++;
    quests.insert(i, _newQuest());
    dirty = true;
    sfx.add(Sfx.unlock);
    return true;
  }

  // ------------------------------------------------------------------ effects
  static const confettiColors = [
    Color(0xFFFF5D73),
    Color(0xFFFFC93C),
    Color(0xFF3DDC97),
    Color(0xFF4CC9F0),
    Color(0xFFB388FF),
    Color(0xFFFFFFFF),
  ];

  void _burst(PK kind, Offset at, double z, int n, Color color,
      {double speed = 2, double up = 2, double size = 0.12, double life = 0.7}) {
    if (parts.length > 700) return;
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final s = speed * (0.35 + rnd.nextDouble() * 0.65);
      final c = kind == PK.confetti ? confettiColors[rnd.nextInt(confettiColors.length)] : color;
      final g = switch (kind) {
        PK.confetti || PK.splash || PK.spark || PK.chip => 9.0,
        PK.puff => 1.5,
        _ => 0.0,
      };
      parts.add(Particle(kind, at.dx, at.dy, z, math.cos(a) * s, math.sin(a) * s, up * (0.5 + rnd.nextDouble() * 0.7),
          life * (0.7 + rnd.nextDouble() * 0.6), size * (0.7 + rnd.nextDouble() * 0.6), c,
          grav: g, rot: rnd.nextDouble() * 6, vr: rr(-9, 9)));
    }
  }

  void _updateFlights(double dt) {
    var anyDone = false;
    for (final f in flights) {
      f.t += dt;
      final u = math.min(1.0, f.t / f.dur);
      f.pos = Offset.lerp(f.from, f.to(), u)!;
      f.z = f.fromZ + (f.toZ() - f.fromZ) * u + f.arc * 4 * u * (1 - u);
      if (u >= 1) {
        f.done = true;
        anyDone = true;
      }
    }
    if (anyDone) {
      final landed = flights.where((f) => f.done).toList();
      flights.removeWhere((f) => f.done);
      for (final f in landed) {
        f.onLand?.call();
      }
    }
  }

  void _updateFx(double dt) {
    for (final p in parts) {
      p.life += dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.z += p.vz * dt;
      p.rot += p.vr * dt;
      if (p.grav != 0) {
        p.vz -= p.grav * dt;
        if (p.z < 0 && p.vz < 0) {
          p.z = 0;
          p.vz = -p.vz * 0.3;
          p.vx *= 0.5;
          p.vy *= 0.5;
        }
      }
    }
    parts.removeWhere((p) => p.life >= p.max);
    for (final t in texts) {
      t.life += dt;
    }
    texts.removeWhere((t) => t.life >= t.max);
    for (final h in hudFlies) {
      h.t += dt;
      if (h.t >= h.dur && !h.done) {
        h.done = true;
        if (h.gem) {
          crystals += h.value;
        } else {
          money += h.value;
          earned += h.value;
          lifetimeEarned += h.value;
          sfx.add(Sfx.coin);
          _questEvent(QuestKind.earn, h.value);
        }
        dirty = true;
      }
    }
    hudFlies.removeWhere((h) => h.done);
    for (final p in piles) {
      p.bounce = math.max(0, p.bounce - dt * 5);
      p.warn = math.max(0, p.warn - dt * 1.2);
    }
    for (final c in cashPiles) {
      c.bounce = math.max(0, c.bounce - dt * 5);
    }
    if (landmark) landmarkT += dt;
  }

  // ------------------------------------------------------------------ guide
  Offset? guideTarget() {
    if (!started) return null;
    UnlockTile? best;
    for (final t in tiles) {
      if (!tileVisible(t)) continue;
      if (money >= t.price - t.paid && (best == null || t.price < best.price)) best = t;
    }
    if (unlocked.length >= 3) return best?.def.pos;
    if (player.carries(Cat.prodA)) return standA.stock.zone.center;
    if (player.carries(Cat.prodB)) return standB?.stock.zone.center;
    if (player.carries(Cat.raw)) {
      if (!procA.input.isFull) return procA.input.zone.center;
      if (procA.output.items.isNotEmpty) return procA.output.zone.center;
      return procA.input.zone.center;
    }
    if (best != null) return best.def.pos;
    if (standA.cash.amount > 0) return standA.cash.zone.center;
    if (procA.output.items.length >= 3) return procA.output.zone.center;
    final inSource = isRiver ? dockRect.contains(player.pos) : fieldRect.contains(player.pos);
    if (inSource) {
      return rawPad.items.length >= 6 || rawPad.isFull ? rawPad.zone.center : null;
    }
    if (rawPad.items.isNotEmpty) return rawPad.zone.center;
    return isRiver ? const Offset(-2.3, 0.6) : const Offset(-3.4, -1.0);
  }

  // ------------------------------------------------------------------ offline
  /// Coins the helpers earn while the game is closed (capped at one hour).
  int offlineReward(double seconds) {
    if (couriers.length < 2 || harvesters.isEmpty) return 0;
    final s = seconds.clamp(0, 3600).toDouble();
    if (s < 120) return 0;
    final rate =
        0.04 * (harvesters.length * 2 + couriers.length + (cashier != null ? 2 : 0)) * priceOf(region.prodA);
    return (rate * s).round();
  }

  void grantMoney(int amount) {
    if (amount <= 0) return;
    hudFlies.add(HudFly(Offset(cam.size.width / 2, cam.size.height * 0.5), false, amount, 0.8, 0.1));
  }

  // ------------------------------------------------------------------ travel
  /// Builds the next region of the expedition, carrying over the meta progression.
  GameWorld travel() {
    final nextIndex = (regionIndex + 1) % regions.length;
    final nextStar = star + (regionIndex + 1 >= regions.length ? 1 : 0);
    final w = GameWorld(regionIndex: nextIndex, star: nextStar);
    var pendingGems = 0;
    for (final h in hudFlies) {
      if (h.gem) pendingGems += h.value;
    }
    w.crystals = crystals + pendingGems;
    w.upg.addAll(upg);
    w.completed = completed + 1;
    w.outfitsOwned.addAll(outfitsOwned);
    w.wearOutfit(outfit);
    w.questLevel = questLevel;
    w.lifetimeEarned = lifetimeEarned;
    w._applyUpgrades();
    w.quests.clear();
    w._ensureQuests();
    w.started = true;
    w.dirty = true;
    return w;
  }

  // ------------------------------------------------------------------ save
  Map<String, dynamic> toJson() {
    var pendingMoney = 0;
    var pendingGems = 0;
    for (final h in hudFlies) {
      if (h.gem) {
        pendingGems += h.value;
      } else {
        pendingMoney += h.value;
      }
    }
    return {
      'v': 2,
      'region': regionIndex,
      'star': star,
      'completed': completed,
      'money': money + pendingMoney,
      'crystals': crystals + pendingGems,
      'earned': earned,
      'lifetime': lifetimeEarned,
      'playTime': playTime,
      'upg': {for (final u in Upg.values) u.name: lv(u)},
      'outfit': outfit,
      'outfits': outfitsOwned.toList(),
      'questLevel': questLevel,
      'regionQuests': regionQuests,
      'quests': [for (final q in quests) q.toJson()],
      'unlocked': [
        for (final d in defs)
          if (unlocked.contains(d.id)) d.id
      ],
      'paid': {
        for (final t in tiles)
          if (t.paid > 0 && !unlocked.contains(t.def.id)) t.def.id: t.paid
      },
      'slv': {for (final k in StationKind.values) k.name: sl(k)},
      'slvPaid': {for (final t in levelTiles) t.kind.name: t.paid},
      'raid': {'enabled': raid.enabled, 'index': raid.index, 'timer': raid.active ? 30.0 : raid.timer},
      'piles': {
        for (final p in piles) p.id: [for (final it in p.items) it.name]
      },
      'cash': {for (final c in cashPiles) c.id: c.amount},
      'carry': [for (final it in player.carry) it.name],
      'pos': [player.pos.dx, player.pos.dy],
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static int _i(Object? v, [int d = 0]) => v is num ? v.toInt() : d;
  static double _d(Object? v, [double d = 0]) => v is num ? v.toDouble() : d;

  static Item? _item(Object? v) {
    if (v is String) return Item.values.where((e) => e.name == v).firstOrNull;
    if (v is num) {
      // version 1 stored indexes of: fish, goldFish, bigFish, cake, chowder
      final i = v.toInt();
      return i >= 0 && i < 5 ? Item.values[i] : null;
    }
    return null;
  }

  /// Creates the world described by a save (any version).
  static GameWorld fromSave(Map<String, dynamic> j) {
    final region = _i(j['region']).clamp(0, regions.length - 1);
    final w = GameWorld(regionIndex: region, star: math.max(0, _i(j['star'])));
    w._load(j);
    return w;
  }

  void _load(Map<String, dynamic> j) {
    try {
      final v1 = _i(j['v'], 1) < 2;
      money = math.max(0, _i(j['money']));
      crystals = math.max(0, _i(j['crystals']));
      earned = math.max(0, _i(j['earned']));
      lifetimeEarned = math.max(earned, _i(j['lifetime']));
      completed = math.max(0, _i(j['completed']));
      playTime = _d(j['playTime']);
      questLevel = math.max(0, _i(j['questLevel']));
      regionQuests = math.max(0, _i(j['regionQuests']));
      final u = j['upg'];
      if (u is Map) {
        for (final x in Upg.values) {
          upg[x] = _i(u[x.name]).clamp(0, upgMax);
        }
        if (v1) upg[Upg.helpers] = _i(u['kitchen']).clamp(0, upgMax);
      }
      final owned = j['outfits'];
      if (owned is List) {
        for (final o in owned) {
          final i = _i(o, -1);
          if (i >= 0 && i < outfits.length) outfitsOwned.add(i);
        }
      }
      final of = _i(j['outfit']);
      wearOutfit(outfitsOwned.contains(of) ? of : 0);
      final ul = j['unlocked'];
      if (ul is List) {
        final ids = ul.map((e) => legacyUnlockIds[e] ?? e).toSet();
        for (final d in defs) {
          if (ids.contains(d.id)) unlock(d.id, silent: true);
        }
      }
      final paid = j['paid'];
      if (paid is Map) {
        for (final t in tiles) {
          final legacy = legacyUnlockIds.entries.where((e) => e.value == t.def.id).map((e) => e.key).firstOrNull;
          final pv = paid[t.def.id] ?? (legacy != null ? paid[legacy] : null);
          t.paid = _i(pv).clamp(0, t.price - 1);
        }
      }
      final lvs = j['slv'];
      if (lvs is Map) {
        for (final k in StationKind.values) {
          slv[k] = _i(lvs[k.name]).clamp(0, stationMaxLevel - 1);
        }
      }
      final lp = j['slvPaid'];
      if (lp is Map) {
        for (final t in levelTiles) {
          t.paid = _i(lp[t.kind.name]).clamp(0, math.max(0, levelPrice(t.kind) - 1));
        }
      }
      _applyLevels();
      final r = j['raid'];
      if (r is Map) {
        raid.enabled = r['enabled'] == true;
        raid.index = math.max(0, _i(r['index']));
        raid.timer = _d(r['timer'], 75).clamp(20, 200).toDouble();
      }
      final ps = j['piles'];
      if (ps is Map) {
        const legacyPileIds = {
          'rawPad': 'fishPad',
          'procAIn': 'grillIn',
          'procAOut': 'grillOut',
          'procBIn': 'potIn',
          'procBOut': 'potOut',
        };
        for (final p in piles) {
          final l = ps[p.id] ?? ps[legacyPileIds[p.id]];
          if (l is! List) continue;
          p.items
            ..clear()
            ..addAll(l.map(_item).whereType<Item>().where((it) => _belongs(it, p.cat)).take(p.capacity));
        }
      }
      final cash = j['cash'];
      if (cash is Map) {
        for (final c in cashPiles) {
          c.amount = math.max(0, _i(cash[c.id]));
        }
      }
      _applyUpgrades();
      final carry = j['carry'];
      if (carry is List) {
        final items = carry.map(_item).whereType<Item>().where(_belongsAny).toList();
        player.carry.addAll(items.take(player.capacity));
      }
      final pos = j['pos'];
      if (pos is List && pos.length == 2) {
        final p = Offset(_d(pos[0]), _d(pos[1]));
        if (_walkable(p)) player.pos = p;
      }
      final qs = j['quests'];
      if (qs is List) {
        final loaded = qs.map(Quest.fromJson).whereType<Quest>().take(3).toList();
        if (loaded.isNotEmpty) {
          quests
            ..clear()
            ..addAll(loaded);
        }
      }
      _ensureQuests();
      cam.cx = player.pos.dx;
      cam.cy = player.pos.dy;
    } catch (_) {
      // A corrupted save should never prevent the game from starting.
    }
  }

  bool _belongs(Item it, Cat c) => catOf(it) == c && _belongsAny(it);

  bool _belongsAny(Item it) => switch (catOf(it)) {
        Cat.raw => it == region.raw || it == region.rare || it == region.big,
        Cat.prodA => it == region.prodA,
        Cat.prodB => it == region.prodB,
      };

  /// Demo / test helper used by the web build (query parameters) and tests.
  void applyDemo(String mode) {
    if (mode == 'rich') {
      money = (99999 * mul).round();
      crystals = 999;
    } else if (mode == 'all') {
      for (final d in defs) {
        unlock(d.id, silent: true);
      }
      money = (5000 * mul).round();
      crystals = 60;
      for (final k in StationKind.values) {
        slv[k] = 3;
      }
      _applyLevels();
      for (var i = 0; i < 14; i++) {
        rawPad.items.add(i % 7 == 0 ? region.rare : region.raw);
        procA.output.items.add(region.prodA);
        standA.stock.items.add(region.prodA);
      }
      for (var i = 0; i < 9; i++) {
        procB!.output.items.add(region.prodB);
        standB!.stock.items.add(region.prodB);
      }
      standA.cash.amount = (160 * mul).round();
      standB!.cash.amount = (240 * mul).round();
    }
  }

  void triggerRaidSoon({bool boss = false}) {
    raid.enabled = true;
    raid.timer = 3;
    if (boss) raid.index = 3;
  }
}

/// Compact number formatting (1.2K, 3.4M ...).
String fmtNum(num v) {
  final a = v.abs();
  if (a >= 1e12) return '${(v / 1e12).toStringAsFixed(a >= 1e13 ? 0 : 1)}T';
  if (a >= 1e9) return '${(v / 1e9).toStringAsFixed(a >= 1e10 ? 0 : 1)}B';
  if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(a >= 1e7 ? 0 : 1)}M';
  if (a >= 1e4) return '${(v / 1e3).toStringAsFixed(a >= 1e5 ? 0 : 1)}K';
  return v.round().toString();
}
