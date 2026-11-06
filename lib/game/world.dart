import 'dart:math' as math;
import 'dart:ui';

import 'iso.dart';

// =============================================================================
// Enums & small helpers
// =============================================================================

enum Item { fish, goldFish, bigFish, cake, chowder }

enum Cat { fish, cake, chowder }

enum Sfx { throwSpear, hit, pop, coin, unlock, alarm, howl, poof, snowball, victory }

enum Upg { power, rate, capacity, speed, kitchen }

enum TileIcon { harpoon, porter, waiter, cannon, key, lighthouse }

enum ProjKind { harpoon, snowball, cannonball }

enum PK { puff, spark, confetti, steam, splash, ring, ember, heart }

enum PropKind { lantern, crate, barrel, mound, rock, sign }

Cat catOf(Item i) => switch (i) {
      Item.fish || Item.goldFish || Item.bigFish => Cat.fish,
      Item.cake => Cat.cake,
      Item.chowder => Cat.chowder,
    };

double catH(Cat c) => switch (c) {
      Cat.fish => 0.21,
      Cat.cake => 0.11,
      Cat.chowder => 0.2,
    };

// World layout ---------------------------------------------------------------
const double riverX0 = -10.5;
const double riverX1 = -1.6;
const double waterZ = -0.45;
const double dockZ = 0.12;
const Rect dockRect = Rect.fromLTRB(-4.9, -3.2, -1.2, 2.0);
const Rect walkA = Rect.fromLTRB(-1.5, -6.7, 10.2, 3.7);
const Rect walkB = Rect.fromLTRB(-1.5, 3.6, 10.2, 10.7);
const Rect zoneARect = Rect.fromLTRB(-1.35, -7.0, 10.5, 4.0);
const Rect zoneBRect = Rect.fromLTRB(-1.35, 4.0, 10.5, 11.0);
const Offset lighthousePos = Offset(-0.45, -6.1);

const List<int> upgCosts = [2, 4, 6, 9, 13, 18, 24, 32];
const int upgMax = 8;

// =============================================================================
// Looks
// =============================================================================

class Look {
  final Color coat;
  final Color coatDark;
  final Color trim;
  final Color hat;
  final Color skin;
  final Color pants;
  final int hatKind; // 0 beanie, 1 chef, 2 fur cap, 3 hood
  final Color? scarf;
  final bool tool;

  const Look({
    required this.coat,
    required this.coatDark,
    required this.hat,
    this.trim = const Color(0xFFF7F4EE),
    this.skin = const Color(0xFFF6CFB0),
    this.pants = const Color(0xFF34395A),
    this.hatKind = 0,
    this.scarf,
    this.tool = false,
  });
}

class Looks {
  static const player = Look(
      coat: Color(0xFFE2483D),
      coatDark: Color(0xFFAE2E28),
      hat: Color(0xFFE2483D),
      hatKind: 3,
      scarf: Color(0xFFFFC93C));
  static const chef = Look(
      coat: Color(0xFFF4F6FA),
      coatDark: Color(0xFFC6CFDD),
      hat: Color(0xFFFFFFFF),
      hatKind: 1,
      pants: Color(0xFF59607A));
  static const cook = Look(
      coat: Color(0xFFF3A65A),
      coatDark: Color(0xFFC97B34),
      hat: Color(0xFFFFFFFF),
      hatKind: 1,
      skin: Color(0xFFC98E66));
  static const porter = Look(
      coat: Color(0xFF43A35B),
      coatDark: Color(0xFF2D7841),
      hat: Color(0xFFF2C14E),
      skin: Color(0xFFE8B48F));
  static const waiter = Look(
      coat: Color(0xFF7E5BD6),
      coatDark: Color(0xFF583CA4),
      hat: Color(0xFFFF8FB1));
  static const harpooner = Look(
      coat: Color(0xFF2E5E8E),
      coatDark: Color(0xFF1E4168),
      hat: Color(0xFF8A5A3B),
      hatKind: 2,
      skin: Color(0xFFE8B48F),
      tool: true);
}

const List<Color> coatPalette = [
  Color(0xFF5DADE2),
  Color(0xFFF5B041),
  Color(0xFFAF7AC5),
  Color(0xFF48C9B0),
  Color(0xFFEC7063),
  Color(0xFFF4D03F),
  Color(0xFF85C1E9),
  Color(0xFFF1948A),
  Color(0xFF82E0AA),
  Color(0xFFBB8FCE),
  Color(0xFF5D6D7E),
  Color(0xFFE59866),
];

const List<Color> skinPalette = [
  Color(0xFFF6CFB0),
  Color(0xFFE8B48F),
  Color(0xFFC98E66),
  Color(0xFF9C6644),
  Color(0xFFFFDDC4),
];

Color darken(Color c, double t) => Color.lerp(c, const Color(0xFF15192B), t)!;
Color lighten(Color c, double t) => Color.lerp(c, const Color(0xFFFFFFFF), t)!;

// =============================================================================
// Entities
// =============================================================================

class Actor {
  Offset pos;
  Offset vel = Offset.zero;
  double facing;
  double walk = 0;
  double move = 0;
  final Look look;
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

  int get load => carry.length + inbound.length;
  bool get isFull => load >= capacity;
  Offset get dir => Offset(math.cos(facing), math.sin(facing));
  Offset get stackPos => pos + dir * 0.5;

  double stackZ(int i) => 0.55 + i * catH(carryCat ?? Cat.cake);

  void faceTo(Offset d) {
    if (d.dx * d.dx + d.dy * d.dy > 1e-8) facing = math.atan2(d.dy, d.dx);
  }
}

class Courier extends Actor {
  final Pile from;
  final Pile to;
  int state = 0;
  double wait = 0;

  Courier(super.pos, super.look, this.from, this.to) : super(capacity: 6);
}

class Pile {
  final String id;
  final Rect zone;
  final Offset at;
  final double baseZ;
  final int capacity;
  final Cat cat;
  final int cols;
  final double gap;
  final List<Item> items = [];
  int incoming = 0;
  double bounce = 0;
  double warn = 0;

  Pile(this.id, this.zone, this.at, this.baseZ, this.capacity, this.cat,
      this.cols, this.gap);

  bool get isFull => items.length + incoming >= capacity;
  int get space => capacity - items.length - incoming;

  Offset colOffset(int col) {
    if (cols == 1) return Offset.zero;
    if (cols == 2) return Offset(0, col == 0 ? -gap : gap);
    return Offset(col.isOdd ? gap : -gap, col >= 2 ? gap : -gap);
  }

  Offset slotXY(int i) => at + colOffset(i % cols);
  double slotZ(int i) => baseZ + (i ~/ cols) * catH(cat);
}

class Processor {
  final String id;
  final Offset pos;
  final bool isPot;
  final Pile input;
  final Pile output;
  final Actor chef;
  final Offset workAt;
  final double workZ;
  final double baseTime;
  Item? working;
  double t = 0;
  double anim = 0;
  double pop = 1;
  double steamCd = 0;

  Processor({
    required this.id,
    required this.pos,
    required this.isPot,
    required this.input,
    required this.output,
    required this.chef,
    required this.workAt,
    required this.workZ,
    required this.baseTime,
  });

  Item get product => isPot ? Item.chowder : Item.cake;

  int yieldOf(Item fish) => isPot
      ? switch (fish) {
          Item.goldFish => 2,
          Item.bigFish => 3,
          _ => 1,
        }
      : switch (fish) {
          Item.goldFish => 6,
          Item.bigFish => 8,
          _ => 3,
        };
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

class UnlockDef {
  final String id;
  final Offset pos;
  final int price;
  final List<String> req;
  final String name;
  final TileIcon icon;

  const UnlockDef(this.id, this.pos, this.price, this.req, this.name, this.icon);
}

const List<UnlockDef> unlockDefs = [
  UnlockDef('harp1', Offset(-4.45, -2.6), 40, [], 'harpooner', TileIcon.harpoon),
  UnlockDef('porter1', Offset(2.3, -0.2), 110, ['harp1'], 'porter', TileIcon.porter),
  UnlockDef('harp2', Offset(-4.45, -1.25), 180, ['harp1'], 'harpooner', TileIcon.harpoon),
  UnlockDef('waiter1', Offset(7.0, -3.4), 260, ['porter1'], 'waiter', TileIcon.waiter),
  UnlockDef('cannon1', Offset(0.3, 3.0), 330, ['harp2'], 'cannon', TileIcon.cannon),
  UnlockDef('chowder', Offset(4.5, 3.1), 600, ['waiter1'], 'chowderHouse', TileIcon.key),
  UnlockDef('harp3', Offset(-4.45, 0.1), 650, ['chowder'], 'harpooner', TileIcon.harpoon),
  UnlockDef('porter2', Offset(2.0, 5.3), 750, ['chowder'], 'porter', TileIcon.porter),
  UnlockDef('waiter2', Offset(7.0, 9.3), 900, ['porter2'], 'waiter', TileIcon.waiter),
  UnlockDef('harp4', Offset(-4.45, 1.45), 1100, ['harp3'], 'harpooner', TileIcon.harpoon),
  UnlockDef('cannon2', Offset(0.3, 9.7), 1300, ['chowder', 'cannon1'], 'cannon', TileIcon.cannon),
  UnlockDef('lighthouse', Offset(0.75, -5.7), 2400, ['harp4', 'waiter2'], 'lighthouse', TileIcon.lighthouse),
];

class UnlockTile {
  final UnlockDef def;
  int paid = 0;
  double appear = 0;
  double glow = 0;

  UnlockTile(this.def);

  Rect get zone => Rect.fromCenter(center: def.pos, width: 1.6, height: 1.6);
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

  Fish(this.pos, this.baseX, this.speed, this.kind, this.hp, this.phase, this.vis)
      : maxHp = hp;

  bool get doomed => pending >= hp;
}

class Wolf {
  Offset pos;
  int hp;
  final int maxHp;
  final bool leader;
  final double speed;
  int state = 0; // 0 = approach, 1 = flee
  Pile? target;
  Item? stolen;
  Pile? stolenFrom;
  double phase;
  double flash = 0;
  int pending = 0;
  double facing = 0;
  bool alive = true;
  double life = 0;

  Wolf(this.pos, this.hp, this.leader, this.speed, this.phase) : maxHp = hp;
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

  Flight(this.item, this.from, this.fromZ, this.to, this.toZ, this.dur, this.arc,
      this.onLand,
      {this.spin = 0})
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

  Particle(this.kind, this.x, this.y, this.z, this.vx, this.vy, this.vz, this.max,
      this.size, this.color,
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

// =============================================================================
// The world
// =============================================================================

class GameWorld {
  GameWorld() {
    _build();
  }

  final math.Random rnd = math.Random();
  final IsoCamera cam = IsoCamera();
  double time = 0;
  double playTime = 0;
  bool started = false;
  int money = 0;
  int crystals = 0;
  int earned = 0;
  final Map<Upg, int> upg = {for (final u in Upg.values) u: 0};
  final Set<String> unlocked = <String>{};
  bool dirty = false;

  late final Actor player;
  Offset input = Offset.zero;
  double _pickCd = 0;
  double _payCd = 0;
  double _cashCd = 0;
  double _throwCd = 0;
  double _fishCd = 0;
  double _coinFxCd = 0;

  late final Pile fishPad;
  late final Processor grill;
  late final Counter standA;
  Processor? pot;
  Counter? standB;

  final List<Pile> piles = [];
  final List<Pile> pickPiles = [];
  final List<Pile> dropPiles = [];
  final List<CashPile> cashPiles = [];
  final List<Processor> processors = [];
  final List<Counter> counters = [];
  final List<Actor> harpooners = [];
  final List<Courier> couriers = [];
  final List<Cannon> cannons = [];
  final List<Fish> fish = [];
  final List<Proj> projs = [];
  final List<Flight> flights = [];
  final List<Wolf> wolves = [];
  final List<Particle> parts = [];
  final List<FloatText> texts = [];
  final List<HudFly> hudFlies = [];
  final List<UnlockTile> tiles = [];
  final List<Tree> trees = [];
  final List<Prop> props = [];
  final List<Offset> fencePosts = [];
  final List<Ob> obstacles = [];
  final Raid raid = Raid();
  bool zoneB = false;
  bool lighthouse = false;
  double lighthouseT = 0;
  final List<Sfx> sfx = [];
  final List<String> events = [];
  double shake = 0;
  Offset hudCoin = const Offset(40, 40);
  Offset hudGem = const Offset(40, 90);

  double rr(double a, double b) => a + rnd.nextDouble() * (b - a);

  // ---------------------------------------------------------------- stats
  int lv(Upg u) => upg[u] ?? 0;
  double get playerSpeed => 4.4 * (1 + 0.08 * lv(Upg.speed));
  double get playerRate => 0.6 * math.pow(0.9, lv(Upg.rate)).toDouble();
  int get playerDmg => 1 + lv(Upg.power);
  int get harpoonerDmg => 1 + lv(Upg.power) ~/ 2;
  double get harpoonerRate => 1.2 * math.pow(0.9, lv(Upg.rate)).toDouble();
  int get cannonDmg => 3 + lv(Upg.power);
  int get playerCap => 8 + 3 * lv(Upg.capacity);
  int get courierCap => 8 + lv(Upg.capacity);
  double get courierSpeed => 2.8 * (1 + 0.06 * lv(Upg.speed));
  double get kitchenMul => math.pow(0.88, lv(Upg.kitchen)).toDouble();
  double get buyInterval => 0.22 * math.pow(0.92, lv(Upg.kitchen)).toDouble();
  int priceOf(Item it) => (it == Item.chowder ? 16 : 4) * (lighthouse ? 2 : 1);
  int get progress => unlocked.length;
  int get progressMax => unlockDefs.length;
  bool get canFish => raid.freeze < 0.05;

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

  void _applyUpgrades() {
    player.capacity = playerCap;
    for (final c in couriers) {
      c.capacity = courierCap;
    }
  }

  bool tileVisible(UnlockTile t) =>
      !unlocked.contains(t.def.id) && t.def.req.every(unlocked.contains);

  // ---------------------------------------------------------------- build
  void _build() {
    player = Actor(const Offset(0.4, -1.0), Looks.player, facing: 2.3, capacity: 8);
    fishPad = Pile('fishPad', Rect.fromCenter(center: const Offset(0.7, -3.7), width: 1.9, height: 1.9),
        const Offset(0.7, -3.7), 0.03, 20, Cat.fish, 2, 0.3);
    final gIn = Pile('grillIn', Rect.fromCenter(center: const Offset(4.0, -3.6), width: 1.5, height: 1.2),
        const Offset(4.0, -2.15), 0.81, 8, Cat.fish, 1, 0);
    final gOut = Pile('grillOut', Rect.fromCenter(center: const Offset(5.45, -1.0), width: 1.4, height: 1.6),
        const Offset(5.45, -1.0), 0.03, 40, Cat.cake, 4, 0.27);
    grill = Processor(
        id: 'grill',
        pos: const Offset(4.0, -1.6),
        isPot: false,
        input: gIn,
        output: gOut,
        chef: Actor(const Offset(3.0, -1.6), Looks.chef, facing: 0),
        workAt: const Offset(4.0, -1.12),
        workZ: 0.87,
        baseTime: 1.3);
    final sA = Pile('standA', Rect.fromCenter(center: const Offset(4.6, -5.85), width: 1.7, height: 1.3),
        const Offset(4.6, -7.0), 0.92, 32, Cat.cake, 4, 0.27);
    final cashA = CashPile('cashA', Rect.fromCenter(center: const Offset(7.1, -5.7), width: 1.5, height: 1.5),
        const Offset(7.1, -5.7));
    standA = Counter(
        id: 'standA',
        pos: const Offset(4.6, -7.0),
        hx: 1.15,
        hy: 0.4,
        stock: sA,
        cash: cashA,
        product: Item.cake,
        slots: const [Offset(4.6, -8.1), Offset(4.6, -9.1), Offset(4.6, -10.1), Offset(4.6, -11.1)],
        entry: const Offset(4.6, -14.5),
        crowdArea: const Rect.fromLTRB(-0.6, -15.5, 10.4, -8.3),
        lane: const Rect.fromLTRB(3.75, -16, 5.45, -7),
        canopy: const Color(0xFFE5484D));
    piles.addAll([fishPad, gIn, gOut, sA]);
    pickPiles.addAll([fishPad, gOut]);
    dropPiles.addAll([gIn, sA]);
    cashPiles.add(cashA);
    processors.add(grill);
    counters.add(standA);
    _fillCrowd(standA, 46);
    for (final d in unlockDefs) {
      tiles.add(UnlockTile(d));
    }
    _buildScenery();
    _rebuildFences();
    _rebuildObstacles();
    for (var i = 0; i < 18; i++) {
      _spawnFish(rr(-18, 16), 1);
    }
    cam.cx = player.pos.dx;
    cam.cy = player.pos.dy;
  }

  void _openZoneB() {
    if (zoneB) return;
    zoneB = true;
    final pIn = Pile('potIn', Rect.fromCenter(center: const Offset(4.95, 6.45), width: 1.5, height: 1.4),
        const Offset(3.45, 6.25), 0.47, 8, Cat.fish, 1, 0);
    final pOut = Pile('potOut', Rect.fromCenter(center: const Offset(4.95, 8.75), width: 1.5, height: 1.5),
        const Offset(4.95, 8.75), 0.03, 24, Cat.chowder, 4, 0.28);
    pot = Processor(
        id: 'pot',
        pos: const Offset(3.4, 7.7),
        isPot: true,
        input: pIn,
        output: pOut,
        chef: Actor(const Offset(2.2, 7.45), Looks.cook, facing: 0),
        workAt: const Offset(3.4, 7.7),
        workZ: 1.05,
        baseTime: 2.4);
    final sB = Pile('standB', Rect.fromCenter(center: const Offset(9.25, 7.4), width: 1.3, height: 1.7),
        const Offset(10.5, 7.4), 0.92, 24, Cat.chowder, 4, 0.27);
    final cashB = CashPile('cashB', Rect.fromCenter(center: const Offset(8.9, 9.7), width: 1.5, height: 1.5),
        const Offset(8.9, 9.7));
    standB = Counter(
        id: 'standB',
        pos: const Offset(10.5, 7.4),
        hx: 0.4,
        hy: 1.15,
        stock: sB,
        cash: cashB,
        product: Item.chowder,
        slots: const [Offset(11.6, 7.4), Offset(12.6, 7.4), Offset(13.6, 7.4), Offset(14.6, 7.4)],
        entry: const Offset(17.6, 7.4),
        crowdArea: const Rect.fromLTRB(11.3, 3.2, 17.8, 11.8),
        lane: const Rect.fromLTRB(10.5, 6.65, 19, 8.15),
        canopy: const Color(0xFF3D8BEA));
    piles.addAll([pIn, pOut, sB]);
    pickPiles.add(pOut);
    dropPiles.addAll([pIn, sB]);
    cashPiles.add(cashB);
    processors.add(pot!);
    counters.add(standB!);
    _fillCrowd(standB!, 30);
    trees.removeWhere((t) => t.inZoneB);
    props.removeWhere((p) => p.inZoneB);
    _rebuildFences();
    _rebuildObstacles();
  }

  void _fillCrowd(Counter k, int n) {
    final r = math.Random(k.id.hashCode);
    var tries = 0;
    while (k.crowd.length < n && tries < n * 40) {
      tries++;
      final p = Offset(k.crowdArea.left + r.nextDouble() * k.crowdArea.width,
          k.crowdArea.top + r.nextDouble() * k.crowdArea.height);
      if (k.lane.inflate(0.25).contains(p)) continue;
      var ok = true;
      for (final o in k.crowd) {
        if ((o.pos - p).distanceSquared < 0.62) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      final c = Customer(p, _randomLook(r), 0, r.nextDouble() * 6.28);
      c.faceTo(k.pos - p);
      k.crowd.add(c);
    }
  }

  Look _randomLook([math.Random? r]) {
    final g = r ?? rnd;
    final coat = coatPalette[g.nextInt(coatPalette.length)];
    final hat = coatPalette[g.nextInt(coatPalette.length)];
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
    final r = math.Random(1337);
    // forest on the far bank
    for (var x = -11.9; x > -23; x -= 1.25) {
      for (var y = -36.0; y < 36; y += 1.35) {
        trees.add(Tree(Offset(x + (r.nextDouble() - 0.5) * 0.8, y + (r.nextDouble() - 0.5) * 0.9),
            0.85 + r.nextDouble() * 0.45, r.nextDouble(), false));
      }
    }
    // around the camp
    final placed = <Offset>[];
    for (var i = 0; i < 700 && placed.length < 150; i++) {
      final p = Offset(-1.5 + r.nextDouble() * 26, -30 + r.nextDouble() * 60);
      if (_reservedForScenery(p)) continue;
      if (placed.any((o) => (o - p).distanceSquared < 1.7)) continue;
      placed.add(p);
      trees.add(Tree(p, 0.8 + r.nextDouble() * 0.5, r.nextDouble(), false));
    }
    // the locked chowder plot is overgrown until it is bought
    final zb = <Offset>[];
    for (var i = 0; i < 200 && zb.length < 12; i++) {
      final p = Offset(0.4 + r.nextDouble() * 9.4, 4.9 + r.nextDouble() * 5.5);
      if (zb.any((o) => (o - p).distanceSquared < 2.2)) continue;
      zb.add(p);
      trees.add(Tree(p, 0.75 + r.nextDouble() * 0.4, r.nextDouble(), true));
    }
    // props
    props.addAll([
      Prop(PropKind.lantern, const Offset(-1.15, -6.75)),
      Prop(PropKind.lantern, const Offset(10.25, -6.75)),
      Prop(PropKind.lantern, const Offset(-1.15, 2.3)),
      Prop(PropKind.lantern, const Offset(6.35, -1.5)),
      Prop(PropKind.barrel, const Offset(-1.0, -4.9)),
      Prop(PropKind.crate, const Offset(9.6, -0.9)),
      Prop(PropKind.crate, const Offset(9.75, 0.15), size: 0.8),
      Prop(PropKind.barrel, const Offset(9.7, 2.6)),
      Prop(PropKind.sign, const Offset(5.9, 3.7)),
      Prop(PropKind.mound, const Offset(2.5, 8.6), inZoneB: true, size: 1.4),
      Prop(PropKind.rock, const Offset(6.8, 6.2), inZoneB: true),
      Prop(PropKind.mound, const Offset(8.0, 9.9), inZoneB: true, size: 1.1),
    ]);
    for (var i = 0; i < 40; i++) {
      final p = Offset(-1.5 + r.nextDouble() * 26, -28 + r.nextDouble() * 56);
      if (_reservedForScenery(p)) continue;
      props.add(Prop(r.nextDouble() < 0.6 ? PropKind.mound : PropKind.rock, p,
          size: 0.7 + r.nextDouble() * 0.9));
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
    if (lighthouse) obstacles.add(const Ob.circle(lighthousePos, 0.95));
  }

  // ---------------------------------------------------------------- loop
  void update(double dt) {
    time += dt;
    if (started) {
      playTime += dt;
      _updatePlayer(dt);
      _updateThrowers(dt);
      _updateInteractions(dt);
      _updateTiles(dt);
      _updateRaid(dt);
    } else {
      cam.cx = 1.6 + math.sin(time * 0.12) * 2.4;
      cam.cy = -2.2 + math.cos(time * 0.09) * 2.0;
    }
    _updateCamera(dt);
    _updateFish(dt);
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
    _updateWolves(dt);
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
    final inside = dockRect.contains(p) || walkA.contains(p) || (zoneB && walkB.contains(p));
    if (!inside) return false;
    for (final o in obstacles) {
      if (o.hit(p)) return false;
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

  double groundZ(Offset p) => dockRect.contains(p) && !walkA.contains(p) ? dockZ : 0;

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

  // ---------------------------------------------------------------- combat
  int get _doomedFish {
    var n = 0;
    for (final f in fish) {
      if (f.alive && f.doomed) n++;
    }
    return n;
  }

  bool get _padHasRoom =>
      fishPad.items.length + fishPad.incoming + _doomedFish < fishPad.capacity;

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

  Wolf? _nearestWolf(Offset from, double range) {
    Wolf? best;
    var bd = range * range;
    for (final w in wolves) {
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
      final w = target as Wolf;
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
      final w = _nearestWolf(player.pos, 6.8);
      if (w != null) {
        _launch(ProjKind.snowball, player.pos, pz + 1.3, w, playerDmg);
        if (player.move < 0.2) player.faceTo(w.pos - player.pos);
        player.action = 1;
        _throwCd = playerRate;
      } else if (dockRect.contains(player.pos) && canFish && _padHasRoom) {
        final f = _nearestFish(player.pos, 7.8);
        if (f != null) {
          _launch(ProjKind.harpoon, player.pos, pz + 1.3, f, playerDmg);
          if (player.move < 0.2) player.faceTo(f.pos - player.pos);
          player.action = 1;
          _throwCd = playerRate;
        }
      }
    }
    for (final h in harpooners) {
      h.cd -= dt;
      h.action = math.max(0, h.action - dt * 4);
      if (h.pop < 1) h.pop = math.min(1, h.pop + dt * 2.5);
      if (h.cd > 0) continue;
      final w = _nearestWolf(h.pos, 7.5);
      if (w != null) {
        _launch(ProjKind.snowball, h.pos, dockZ + 1.3, w, harpoonerDmg);
        h.faceTo(w.pos - h.pos);
        h.action = 1;
        h.cd = harpoonerRate;
        continue;
      }
      if (canFish && _padHasRoom) {
        final f = _nearestFish(h.pos, 8.2);
        if (f != null) {
          _launch(ProjKind.harpoon, h.pos, dockZ + 1.3, f, harpoonerDmg);
          h.faceTo(f.pos - h.pos);
          h.action = 1;
          h.cd = harpoonerRate;
          continue;
        }
      }
      h.cd = 0.2;
    }
  }

  void _updateProjs(double dt) {
    for (final p in projs) {
      p.t += dt;
      final t = p.target;
      final tp = t is Fish ? t.pos : (t as Wolf).pos;
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
    } else if (t is Wolf) {
      t.pending = math.max(0, t.pending - p.dmg);
      final big = p.kind == ProjKind.cannonball;
      _burst(PK.puff, t.pos, 0.6, big ? 12 : 6, const Color(0xFFFFFFFF), speed: big ? 2.6 : 1.6, up: 1.5, size: big ? 0.3 : 0.2);
      sfx.add(Sfx.snowball);
      if (!t.alive) return;
      t.hp -= p.dmg;
      t.flash = 1;
      if (t.hp <= 0) _killWolf(t);
    }
  }

  void _catchFish(Fish f) {
    f.alive = false;
    if (fishPad.isFull) return;
    final slot = fishPad.items.length + fishPad.incoming;
    fishPad.incoming++;
    final it = f.kind;
    flights.add(Flight(it, f.pos, waterZ + 0.1, () => fishPad.slotXY(slot), () => fishPad.slotZ(slot), 0.75,
        3.4, () {
      fishPad.incoming--;
      fishPad.items.add(it);
      fishPad.bounce = 1;
      sfx.add(Sfx.pop);
    }, spin: 1));
    if (it != Item.fish) {
      final n = it == Item.bigFish ? 2 : 1;
      _gainGems(n, f.pos, 0.6);
      texts.add(FloatText(f.pos, 1.4, '+$n', const Color(0xFF7FE7FF)));
    }
  }

  void _killWolf(Wolf w) {
    w.alive = false;
    raid.defeated++;
    _burst(PK.puff, w.pos, 0.5, 18, const Color(0xFFFFFFFF), speed: 3, up: 2.5, size: 0.32, life: 0.9);
    _burst(PK.spark, w.pos, 0.6, 8, const Color(0xFF8DEBFF), speed: 2.5, up: 4);
    sfx.add(Sfx.poof);
    final gems = w.leader ? 4 : 1;
    raid.earned += gems;
    _gainGems(gems, w.pos, 0.8);
    texts.add(FloatText(w.pos, 1.5, '+$gems', const Color(0xFF7FE7FF)));
    final it = w.stolen;
    final src = w.stolenFrom;
    if (it != null && src != null && !src.isFull) {
      final slot = src.items.length + src.incoming;
      src.incoming++;
      flights.add(Flight(it, w.pos, 0.8, () => src.slotXY(slot), () => src.slotZ(slot), 0.6, 2.2, () {
        src.incoming--;
        src.items.add(it);
        src.bounce = 1;
      }));
    }
    w.stolen = null;
  }

  void _updateCannons(double dt) {
    for (final c in cannons) {
      if (c.pop < 1) c.pop = math.min(1, c.pop + dt * 2.5);
      c.recoil = math.max(0, c.recoil - dt * 3);
      c.cd -= dt;
      final w = _nearestWolf(c.pos, 9.5);
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

  // ---------------------------------------------------------------- fish
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

  // ---------------------------------------------------------------- items
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
    final it = a.carry.removeLast();
    final from = a.stackPos;
    final fz = groundZ(a.pos) + a.stackZ(a.carry.length);
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
      final cat = p.carryCat;
      var done = false;
      if (cat != null && p.carry.isNotEmpty) {
        for (final pile in dropPiles) {
          if (pile.cat == cat && pile.zone.contains(p.pos)) {
            if (!pile.isFull) {
              _actorToPile(p, pile);
              _pickCd = 0.06;
              done = true;
            } else {
              pile.warn = 1;
            }
            break;
          }
        }
      }
      if (!done && !p.isFull) {
        for (final pile in pickPiles) {
          if (pile.items.isNotEmpty && pile.zone.contains(p.pos) && (cat == null || cat == pile.cat)) {
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
          final chunk = math.min(c.amount, math.max(5, (c.amount / 4).ceil()));
          c.amount -= chunk;
          c.bounce = 1;
          _gainMoney(chunk, c.at, 0.4);
          _cashCd = 0.05;
          break;
        }
      }
    }
  }

  void _gainMoney(int v, Offset at, double z) {
    hudFlies.add(HudFly(cam.w2s(at.dx, at.dy, z), false, v, 0.5 + rnd.nextDouble() * 0.15, 0));
  }

  void _gainGems(int n, Offset at, double z) {
    final s = cam.w2s(at.dx, at.dy, z);
    for (var i = 0; i < n; i++) {
      hudFlies.add(HudFly(s + Offset(rr(-12, 12), rr(-12, 12)), true, 1, 0.65, i * 0.07));
    }
  }

  // ---------------------------------------------------------------- unlocks
  void _updateTiles(double dt) {
    _payCd -= dt;
    _coinFxCd -= dt;
    for (final t in tiles) {
      if (!tileVisible(t)) continue;
      t.appear = math.min(1, t.appear + dt * 2.2);
      final inside = t.zone.contains(player.pos);
      t.glow = inside ? math.min(1, t.glow + dt * 5) : math.max(0, t.glow - dt * 4);
      if (inside && _payCd <= 0 && money > 0 && t.paid < t.def.price) {
        final remain = t.def.price - t.paid;
        final step = math.max(1, (t.def.price / 36).ceil());
        final chunk = math.min(remain, math.min(money, step));
        money -= chunk;
        t.paid += chunk;
        dirty = true;
        _payCd = 0.035;
        if (_coinFxCd <= 0) {
          _coinFxCd = 0.07;
          final from = player.pos;
          final pz = groundZ(player.pos) + 1.4;
          flights.add(Flight(null, from, pz, () => t.def.pos, () => groundZ(t.def.pos) + 0.05, 0.25, 0.8, null));
          sfx.add(Sfx.coin);
        }
        if (t.paid >= t.def.price) unlock(t.def.id);
      }
    }
  }

  void unlock(String id, {bool silent = false}) {
    if (unlocked.contains(id)) return;
    final def = unlockDefs.firstWhere((d) => d.id == id);
    unlocked.add(id);
    switch (id) {
      case 'harp1' || 'harp2' || 'harp3' || 'harp4':
        harpooners.add(Actor(def.pos, Looks.harpooner, facing: math.pi)..pop = silent ? 1 : 0);
      case 'porter1':
        _addCourier(def.pos, Looks.porter, fishPad, grill.input, silent);
      case 'waiter1':
        _addCourier(def.pos, Looks.waiter, grill.output, standA.stock, silent);
      case 'cannon1' || 'cannon2':
        cannons.add(Cannon(def.pos)..pop = silent ? 1 : 0);
        _rebuildObstacles();
        _pushPlayerOut();
      case 'chowder':
        if (!silent) {
          for (final t in trees) {
            if (t.inZoneB) _burst(PK.puff, t.pos, 0.6, 8, const Color(0xFFFFFFFF), speed: 2, up: 2.5, size: 0.35, life: 0.9);
          }
        }
        _openZoneB();
      case 'porter2':
        _addCourier(def.pos, Looks.porter, fishPad, pot!.input, silent);
      case 'waiter2':
        _addCourier(def.pos, Looks.waiter, pot!.output, standB!.stock, silent);
      case 'lighthouse':
        lighthouse = true;
        _rebuildObstacles();
        _pushPlayerOut();
    }
    _applyUpgrades();
    dirty = true;
    if (!silent) {
      sfx.add(id == 'lighthouse' ? Sfx.victory : Sfx.unlock);
      shake = 0.25;
      _burst(PK.confetti, def.pos, 0.8, 46, const Color(0xFFFFFFFF), speed: 4.5, up: 6.5, size: 0.12, life: 1.4);
      _burst(PK.ring, def.pos, 0.05, 1, const Color(0xFFFFFFFF), life: 0.7);
      events.add(switch (id) {
        'lighthouse' => 'lighthouse',
        'chowder' => 'zoneB',
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

  // ---------------------------------------------------------------- kitchen
  void _updateProcessor(Processor pr, double dt) {
    if (pr.pop < 1) pr.pop = math.min(1, pr.pop + dt * 2);
    final w = pr.working;
    if (w == null) {
      pr.anim = math.max(0, pr.anim - dt);
      if (pr.input.items.isNotEmpty) {
        final it = pr.input.items.last;
        if (pr.output.space >= pr.yieldOf(it)) {
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
    pr.t += dt / (pr.baseTime * kitchenMul);
    pr.steamCd -= dt;
    if (pr.steamCd <= 0) {
      pr.steamCd = pr.isPot ? 0.16 : 0.1;
      parts.add(Particle(PK.steam, pr.workAt.dx + rr(-0.25, 0.25), pr.workAt.dy + rr(-0.25, 0.25), pr.workZ + 0.15,
          rr(-0.1, 0.1), rr(-0.1, 0.1), rr(0.8, 1.3), rr(0.8, 1.2), rr(0.16, 0.26), const Color(0xFFFFFFFF)));
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

  // ---------------------------------------------------------------- customers
  void _updateCounter(Counter k, double dt) {
    if (k.pop < 1) k.pop = math.min(1, k.pop + dt * 2);
    // keep the queue full
    if (k.queue.length < k.slots.length) {
      k.spawnCd -= dt;
      if (k.spawnCd <= 0) {
        final want = k.product == Item.cake ? 2 + rnd.nextInt(5) : 1 + rnd.nextInt(3);
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
          k.buyCd = buyInterval;
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
        texts.add(FloatText(c.pos, 2.9, '+${c.want * priceOf(k.product)}', const Color(0xFFFFD447)));
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

  // ---------------------------------------------------------------- raids
  void _updateRaid(double dt) {
    final r = raid;
    if (!r.enabled) {
      if (unlocked.contains('harp2') || playTime > 420) {
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
          _spawnWolf();
          r.toSpawn--;
          r.spawnCd = rr(0.45, 1.0);
        }
      }
      if (r.toSpawn == 0 && wolves.every((w) => !w.alive)) _endRaid();
    }
  }

  int get wolvesLeft => raid.toSpawn + wolves.where((w) => w.alive).length;

  void _startRaid() {
    raid.active = true;
    raid.howled = false;
    raid.defeated = 0;
    raid.earned = 0;
    final n = math.min(3 + raid.index * 2, 18);
    raid.toSpawn = n;
    raid.total = n;
    raid.spawnCd = 1.0;
    sfx.add(Sfx.alarm);
    events.add('raid_start');
    shake = 0.35;
  }

  void _endRaid() {
    raid.active = false;
    raid.index++;
    raid.timer = 100 + rnd.nextDouble() * 25;
    final bonus = 1 + raid.index;
    raid.earned += bonus;
    _gainGems(bonus, player.pos, 2.0);
    events.add('raid_end:${raid.earned}');
    sfx.add(Sfx.victory);
    wolves.clear();
    dirty = true;
  }

  void _spawnWolf() {
    final leader = raid.index >= 2 && raid.toSpawn == 1;
    final hp = math.min(3 + raid.index, 14) * (leader ? 3 : 1);
    final y = rr(-6.0, zoneB ? 10.0 : 3.0);
    final spd = math.min(2.3 + raid.index * 0.08, 3.2) * (leader ? 0.85 : 1);
    wolves.add(Wolf(Offset(-15.5, y), hp, leader, spd, rr(0, 6.28)));
  }

  Pile? _wolfTarget(Wolf w) {
    final cands = <Pile>[
      fishPad,
      grill.output,
      grill.input,
      if (pot != null) pot!.output,
      if (pot != null) pot!.input,
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

  void _updateWolves(double dt) {
    for (final w in wolves) {
      if (!w.alive) continue;
      w.life += dt;
      w.flash = math.max(0, w.flash - dt * 4);
      w.phase += dt * 12;
      Offset goal;
      var spd = w.speed;
      if (w.state == 0) {
        if (w.target == null || w.target!.items.isEmpty) w.target = _wolfTarget(w);
        final tg = w.target;
        goal = tg?.at ?? const Offset(5.6, -1.0);
        if ((goal - w.pos).distanceSquared < 0.6) {
          if (tg != null && tg.items.isNotEmpty) {
            w.stolen = tg.items.removeLast();
            w.stolenFrom = tg;
            tg.bounce = 1;
            texts.add(FloatText(tg.at, 1.4, '-1', const Color(0xFFFF5A5A)));
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
      for (final o in wolves) {
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
    wolves.removeWhere((w) => !w.alive);
  }

  // ---------------------------------------------------------------- effects
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
        PK.confetti || PK.splash || PK.spark => 9.0,
        PK.puff => 1.5,
        _ => 0.0,
      };
      parts.add(Particle(kind, at.dx, at.dy, z, math.cos(a) * s, math.sin(a) * s,
          up * (0.5 + rnd.nextDouble() * 0.7), life * (0.7 + rnd.nextDouble() * 0.6),
          size * (0.7 + rnd.nextDouble() * 0.6), c,
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
          sfx.add(Sfx.coin);
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
    if (lighthouse) lighthouseT += dt;
  }

  // ---------------------------------------------------------------- guide
  Offset? guideTarget() {
    if (!started) return null;
    UnlockTile? best;
    for (final t in tiles) {
      if (!tileVisible(t)) continue;
      if (money >= t.def.price - t.paid && (best == null || t.def.price < best.def.price)) best = t;
    }
    if (unlocked.length >= 3) return best?.def.pos;
    final cat = player.carryCat;
    if (cat == Cat.fish) return grill.input.zone.center;
    if (cat == Cat.cake) return standA.stock.zone.center;
    if (cat == Cat.chowder) return standB?.stock.zone.center;
    if (best != null) return best.def.pos;
    if (standA.cash.amount > 0) return standA.cash.zone.center;
    if (grill.output.items.length >= 3) return grill.output.zone.center;
    final onDock = dockRect.contains(player.pos);
    if (onDock) {
      return fishPad.items.length >= 6 || fishPad.isFull ? fishPad.zone.center : null;
    }
    if (fishPad.items.isNotEmpty) return fishPad.zone.center;
    return const Offset(-2.3, 0.6);
  }

  // ---------------------------------------------------------------- save
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
      'v': 1,
      'money': money + pendingMoney,
      'crystals': crystals + pendingGems,
      'earned': earned,
      'playTime': playTime,
      'upg': {for (final u in Upg.values) u.name: lv(u)},
      'unlocked': [
        for (final d in unlockDefs)
          if (unlocked.contains(d.id)) d.id
      ],
      'paid': {
        for (final t in tiles)
          if (t.paid > 0 && !unlocked.contains(t.def.id)) t.def.id: t.paid
      },
      'raid': {
        'enabled': raid.enabled,
        'index': raid.index,
        'timer': raid.active ? 30.0 : raid.timer,
      },
      'piles': {
        for (final p in piles) p.id: [for (final it in p.items) it.index]
      },
      'cash': {for (final c in cashPiles) c.id: c.amount},
      'carry': [for (final it in player.carry) it.index],
      'pos': [player.pos.dx, player.pos.dy],
    };
  }

  static int _i(Object? v, [int d = 0]) => v is num ? v.toInt() : d;
  static double _d(Object? v, [double d = 0]) => v is num ? v.toDouble() : d;

  void loadJson(Map<String, dynamic> j) {
    try {
      money = math.max(0, _i(j['money']));
      crystals = math.max(0, _i(j['crystals']));
      earned = math.max(0, _i(j['earned']));
      playTime = _d(j['playTime']);
      final u = j['upg'];
      if (u is Map) {
        for (final x in Upg.values) {
          upg[x] = _i(u[x.name]).clamp(0, upgMax);
        }
      }
      final ul = j['unlocked'];
      if (ul is List) {
        for (final d in unlockDefs) {
          if (ul.contains(d.id)) unlock(d.id, silent: true);
        }
      }
      final paid = j['paid'];
      if (paid is Map) {
        for (final t in tiles) {
          t.paid = _i(paid[t.def.id]).clamp(0, t.def.price - 1);
        }
      }
      final r = j['raid'];
      if (r is Map) {
        raid.enabled = r['enabled'] == true;
        raid.index = math.max(0, _i(r['index']));
        raid.timer = _d(r['timer'], 75).clamp(20, 200).toDouble();
      }
      final ps = j['piles'];
      if (ps is Map) {
        for (final p in piles) {
          final l = ps[p.id];
          if (l is! List) continue;
          p.items
            ..clear()
            ..addAll(l
                .whereType<num>()
                .map((e) => Item.values[e.toInt().clamp(0, Item.values.length - 1)])
                .where((it) => catOf(it) == p.cat)
                .take(p.capacity));
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
        final items = carry.whereType<num>().map((e) => Item.values[e.toInt().clamp(0, Item.values.length - 1)]).toList();
        if (items.isNotEmpty && items.every((it) => catOf(it) == catOf(items.first))) {
          player.carry.addAll(items.take(player.capacity));
        }
      }
      final pos = j['pos'];
      if (pos is List && pos.length == 2) {
        final p = Offset(_d(pos[0]), _d(pos[1]));
        if (_walkable(p)) player.pos = p;
      }
      cam.cx = player.pos.dx;
      cam.cy = player.pos.dy;
    } catch (_) {
      // A corrupted save should never prevent the game from starting.
    }
  }

  /// Debug/demo helper used by the web build (query parameters).
  void applyDemo(String mode) {
    if (mode == 'rich') {
      money = 99999;
      crystals = 99;
    } else if (mode == 'all') {
      for (final d in unlockDefs) {
        unlock(d.id, silent: true);
      }
      money = 5000;
      crystals = 60;
      for (var i = 0; i < 14; i++) {
        fishPad.items.add(i % 7 == 0 ? Item.goldFish : Item.fish);
        grill.output.items.add(Item.cake);
        standA.stock.items.add(Item.cake);
      }
      for (var i = 0; i < 9; i++) {
        pot!.output.items.add(Item.chowder);
        standB!.stock.items.add(Item.chowder);
      }
      standA.cash.amount = 160;
      standB!.cash.amount = 240;
    }
  }

  void triggerRaidSoon() {
    raid.enabled = true;
    raid.timer = 3;
  }
}
