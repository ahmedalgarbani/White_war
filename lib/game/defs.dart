import 'dart:ui';

// =============================================================================
// Enums
// =============================================================================

enum Item {
  // Frost Harbor
  fish, goldFish, bigFish, cake, chowder,
  // Crystal Quarry
  ore, auroraOre, bigOre, ingot, lamp,
  // Timber Hollow
  log, goldLog, bigLog, firewood, sled,
}

/// Item category inside the current region: raw resource or one of the two products.
enum Cat { raw, prodA, prodB }

enum Sfx { throwSpear, hit, pop, coin, unlock, alarm, howl, poof, snowball, victory, chop, mine, quest, boss }

enum Upg { power, rate, capacity, speed, helpers, income }

enum TileIcon { helper, porter, waiter, cannon, key, landmark, cashier }

enum ProjKind { harpoon, snowball, cannonball }

enum PK { puff, spark, confetti, steam, splash, ring, ember, heart, chip }

enum PropKind { lantern, crate, barrel, mound, rock, sign, boulder, crystals, cart, logpile, stump }

enum SourceKind { river, quarry, grove }

enum EnemyKind { wolf, golem, yeti }

enum StationKind { pad, procA, standA, procB, standB }

enum QuestKind { harvest, rare, sellA, sellB, defeat, earn, levelUp, unlock }

Cat catOf(Item i) => switch (i) {
      Item.fish ||
      Item.goldFish ||
      Item.bigFish ||
      Item.ore ||
      Item.auroraOre ||
      Item.bigOre ||
      Item.log ||
      Item.goldLog ||
      Item.bigLog =>
        Cat.raw,
      Item.cake || Item.ingot || Item.firewood => Cat.prodA,
      Item.chowder || Item.lamp || Item.sled => Cat.prodB,
    };

bool isRare(Item i) => i == Item.goldFish || i == Item.auroraOre || i == Item.goldLog;
bool isBig(Item i) => i == Item.bigFish || i == Item.bigOre || i == Item.bigLog;

/// Height of one item when stacked (world units).
double itemH(Item i) => switch (i) {
      Item.fish || Item.goldFish || Item.bigFish => 0.21,
      Item.cake => 0.11,
      Item.chowder => 0.2,
      Item.ore || Item.auroraOre || Item.bigOre => 0.24,
      Item.ingot => 0.13,
      Item.lamp => 0.34,
      Item.log || Item.goldLog || Item.bigLog => 0.22,
      Item.firewood => 0.2,
      Item.sled => 0.17,
    };

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
  final int hatKind; // 0 beanie, 1 chef, 2 fur cap, 3 hood, 4 miner helmet
  final Color? scarf;
  final int tool; // 0 none, 1 harpoon, 2 ladle, 3 pickaxe, 4 axe, 5 hammer, 6 coin bag

  const Look({
    required this.coat,
    required this.coatDark,
    required this.hat,
    this.trim = const Color(0xFFF7F4EE),
    this.skin = const Color(0xFFF6CFB0),
    this.pants = const Color(0xFF34395A),
    this.hatKind = 0,
    this.scarf,
    this.tool = 0,
  });
}

class Looks {
  static const chef = Look(
      coat: Color(0xFFF4F6FA), coatDark: Color(0xFFC6CFDD), hat: Color(0xFFFFFFFF), hatKind: 1, pants: Color(0xFF59607A), tool: 2);
  static const cook = Look(
      coat: Color(0xFFF3A65A), coatDark: Color(0xFFC97B34), hat: Color(0xFFFFFFFF), hatKind: 1, skin: Color(0xFFC98E66), tool: 2);
  static const cutter = Look(
      coat: Color(0xFF8E9AAF), coatDark: Color(0xFF66728A), hat: Color(0xFF4A5568), hatKind: 2, skin: Color(0xFFE8B48F), tool: 5);
  static const smith = Look(
      coat: Color(0xFF8A5634), coatDark: Color(0xFF633B22), hat: Color(0xFF2F3447), skin: Color(0xFF9C6644), tool: 5);
  static const splitter = Look(
      coat: Color(0xFF2E7D4F), coatDark: Color(0xFF1F5A38), hat: Color(0xFFF28C28), tool: 4);
  static const carpenter = Look(
      coat: Color(0xFF34618E), coatDark: Color(0xFF244766), hat: Color(0xFFE5484D), skin: Color(0xFFC98E66), tool: 5);
  static const porter = Look(
      coat: Color(0xFF43A35B), coatDark: Color(0xFF2D7841), hat: Color(0xFFF2C14E), skin: Color(0xFFE8B48F));
  static const waiter = Look(coat: Color(0xFF7E5BD6), coatDark: Color(0xFF583CA4), hat: Color(0xFFFF8FB1));
  static const cashier = Look(
      coat: Color(0xFFF2C14E), coatDark: Color(0xFFC8962A), hat: Color(0xFF2F3447), skin: Color(0xFFFFDDC4), tool: 6);
  static const harpooner = Look(
      coat: Color(0xFF2E5E8E), coatDark: Color(0xFF1E4168), hat: Color(0xFF8A5A3B), hatKind: 2, skin: Color(0xFFE8B48F), tool: 1);
  static const miner = Look(
      coat: Color(0xFFE58A2E), coatDark: Color(0xFFB4651A), hat: Color(0xFFFFD447), hatKind: 4, pants: Color(0xFF3C4560), tool: 3);
  static const lumberjack = Look(
      coat: Color(0xFFC0392B), coatDark: Color(0xFF8E2A20), hat: Color(0xFF3B3F52), skin: Color(0xFFE8B48F), tool: 4);
}

/// Hero outfits (wardrobe). Index 0 is free.
class Outfit {
  final String key;
  final int cost;
  final Look look;

  const Outfit(this.key, this.cost, this.look);
}

const List<Outfit> outfits = [
  Outfit('red', 0,
      Look(coat: Color(0xFFE2483D), coatDark: Color(0xFFAE2E28), hat: Color(0xFFE2483D), hatKind: 3, scarf: Color(0xFFFFC93C))),
  Outfit('glacier', 20,
      Look(coat: Color(0xFF3D8BEA), coatDark: Color(0xFF2563B5), hat: Color(0xFF3D8BEA), hatKind: 3, scarf: Color(0xFFFFFFFF))),
  Outfit('pine', 40,
      Look(coat: Color(0xFF2E9E5B), coatDark: Color(0xFF1F7442), hat: Color(0xFF2E9E5B), hatKind: 3, scarf: Color(0xFFFF8A3D))),
  Outfit('aurora', 70,
      Look(coat: Color(0xFF7E57C2), coatDark: Color(0xFF5A3A99), hat: Color(0xFF7E57C2), hatKind: 3, scarf: Color(0xFF39E0C8))),
  Outfit('golden', 110,
      Look(coat: Color(0xFFE5B53A), coatDark: Color(0xFFB88A1C), hat: Color(0xFFE5B53A), hatKind: 3, scarf: Color(0xFFE5484D))),
  Outfit('midnight', 160,
      Look(coat: Color(0xFF243256), coatDark: Color(0xFF151E36), hat: Color(0xFF243256), hatKind: 3, scarf: Color(0xFF6FF0FF))),
];

const List<Color> coatsHarbor = [
  Color(0xFF5DADE2), Color(0xFFF5B041), Color(0xFFAF7AC5), Color(0xFF48C9B0), Color(0xFFEC7063), Color(0xFFF4D03F),
  Color(0xFF85C1E9), Color(0xFFF1948A), Color(0xFF82E0AA), Color(0xFFBB8FCE), Color(0xFF5D6D7E), Color(0xFFE59866),
];
const List<Color> coatsQuarry = [
  Color(0xFF5DADE2), Color(0xFF7F8FD6), Color(0xFF9B7BD8), Color(0xFF48C9B0), Color(0xFF6C7A96), Color(0xFFB39DDB),
  Color(0xFF4FC3F7), Color(0xFF90A4AE), Color(0xFF26A69A), Color(0xFFCE93D8),
];
const List<Color> coatsTimber = [
  Color(0xFFE57373), Color(0xFFF5B041), Color(0xFF8D6E63), Color(0xFF66BB6A), Color(0xFFFF8A65), Color(0xFFD4AC0D),
  Color(0xFFA1887F), Color(0xFF9CCC65), Color(0xFFEF5350), Color(0xFF26A69A),
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
// Regions
// =============================================================================

class RegionDef {
  final int index;
  final String key;
  final SourceKind source;
  final EnemyKind enemy;
  final Item raw, rare, big, prodA, prodB;
  final Look helper, chefA, chefB;
  final Color canopyA, canopyB, camp, campEdge;
  final List<Color> coats;
  final double enemyHp, enemySpeed;
  final int enemySteal;
  final int nodeHp;
  final double regrow;

  const RegionDef({
    required this.index,
    required this.key,
    required this.source,
    required this.enemy,
    required this.raw,
    required this.rare,
    required this.big,
    required this.prodA,
    required this.prodB,
    required this.helper,
    required this.chefA,
    required this.chefB,
    required this.canopyA,
    required this.canopyB,
    required this.camp,
    required this.campEdge,
    required this.coats,
    required this.enemyHp,
    required this.enemySpeed,
    required this.enemySteal,
    required this.nodeHp,
    required this.regrow,
  });
}

const List<RegionDef> regions = [
  RegionDef(
    index: 0,
    key: 'harbor',
    source: SourceKind.river,
    enemy: EnemyKind.wolf,
    raw: Item.fish,
    rare: Item.goldFish,
    big: Item.bigFish,
    prodA: Item.cake,
    prodB: Item.chowder,
    helper: Looks.harpooner,
    chefA: Looks.chef,
    chefB: Looks.cook,
    canopyA: Color(0xFFE5484D),
    canopyB: Color(0xFF3D8BEA),
    camp: Color(0xFFE7D8CA),
    campEdge: Color(0xFFD6C1AE),
    coats: coatsHarbor,
    enemyHp: 1.0,
    enemySpeed: 2.3,
    enemySteal: 1,
    nodeHp: 3,
    regrow: 0,
  ),
  RegionDef(
    index: 1,
    key: 'quarry',
    source: SourceKind.quarry,
    enemy: EnemyKind.golem,
    raw: Item.ore,
    rare: Item.auroraOre,
    big: Item.bigOre,
    prodA: Item.ingot,
    prodB: Item.lamp,
    helper: Looks.miner,
    chefA: Looks.cutter,
    chefB: Looks.smith,
    canopyA: Color(0xFF8E5BD6),
    canopyB: Color(0xFF16A3A3),
    camp: Color(0xFFDCE1EB),
    campEdge: Color(0xFFBCC5D6),
    coats: coatsQuarry,
    enemyHp: 2.2,
    enemySpeed: 1.6,
    enemySteal: 1,
    nodeHp: 6,
    regrow: 6.5,
  ),
  RegionDef(
    index: 2,
    key: 'timber',
    source: SourceKind.grove,
    enemy: EnemyKind.yeti,
    raw: Item.log,
    rare: Item.goldLog,
    big: Item.bigLog,
    prodA: Item.firewood,
    prodB: Item.sled,
    helper: Looks.lumberjack,
    chefA: Looks.splitter,
    chefB: Looks.carpenter,
    canopyA: Color(0xFFF28C28),
    canopyB: Color(0xFF2E9E5B),
    camp: Color(0xFFE6D5BF),
    campEdge: Color(0xFFCCB394),
    coats: coatsTimber,
    enemyHp: 3.0,
    enemySpeed: 2.05,
    enemySteal: 2,
    nodeHp: 9,
    regrow: 8.0,
  ),
];

// =============================================================================
// Layout shared by all regions
// =============================================================================

const double riverX0 = -10.5;
const double riverX1 = -1.6;
const double waterZ = -0.45;
const double dockZ = 0.12;
const Rect dockRect = Rect.fromLTRB(-4.9, -3.2, -1.2, 2.0);
const Rect fieldRect = Rect.fromLTRB(-9.7, -6.2, -1.2, 3.9);
const Rect walkA = Rect.fromLTRB(-1.5, -6.7, 10.2, 3.7);
const Rect walkB = Rect.fromLTRB(-1.5, 3.6, 10.2, 10.7);
const Rect zoneARect = Rect.fromLTRB(-1.35, -7.0, 10.5, 4.0);
const Rect zoneBRect = Rect.fromLTRB(-1.35, 4.0, 10.5, 11.0);
const Offset landmarkPos = Offset(-0.45, -6.1);
const Offset cashierHome = Offset(8.9, -4.8);

const List<Offset> dockSlots = [Offset(-4.45, -2.6), Offset(-4.45, -1.25), Offset(-4.45, 0.1), Offset(-4.45, 1.45)];
const List<Offset> fieldSlots = [Offset(-3.9, -3.3), Offset(-6.3, -0.9), Offset(-3.8, 1.6), Offset(-7.3, -3.2)];
const List<Offset> nodeSpots = [
  Offset(-2.6, -4.8), Offset(-4.9, -5.0), Offset(-6.9, -5.2), Offset(-8.8, -4.6), Offset(-2.7, -2.0),
  Offset(-5.0, -2.3), Offset(-8.6, -1.6), Offset(-2.5, 0.4), Offset(-4.9, 0.2), Offset(-7.6, 0.7),
  Offset(-2.9, 3.0), Offset(-5.4, 2.6), Offset(-8.0, 3.0),
];

const Map<StationKind, Offset> levelTileSpots = {
  StationKind.pad: Offset(0.9, -1.7),
  StationKind.procA: Offset(4.0, 0.3),
  StationKind.standA: Offset(3.0, -6.05),
  StationKind.procB: Offset(1.2, 8.3),
  StationKind.standB: Offset(9.0, 5.5),
};

const Map<StationKind, int> levelBaseCost = {
  StationKind.pad: 80,
  StationKind.procA: 120,
  StationKind.standA: 150,
  StationKind.procB: 300,
  StationKind.standB: 350,
};

const int stationMaxLevel = 10;
const List<int> upgCosts = [2, 4, 6, 9, 13, 18, 24, 32, 42, 55];
const int upgMax = 10;

class UnlockDef {
  final String id;
  final Offset pos;
  final int price;
  final List<String> req;
  final String name;
  final TileIcon icon;

  const UnlockDef(this.id, this.pos, this.price, this.req, this.name, this.icon);
}

/// The unlock path of a region (prices are multiplied by the region multiplier).
List<UnlockDef> unlocksFor(RegionDef r) {
  final h = r.source == SourceKind.river ? dockSlots : fieldSlots;
  final helper = 'helper_${r.key}';
  return [
    UnlockDef('h1', h[0], 40, const [], helper, TileIcon.helper),
    const UnlockDef('porter1', Offset(2.3, -0.2), 110, ['h1'], 'porter', TileIcon.porter),
    UnlockDef('h2', h[1], 180, const ['h1'], helper, TileIcon.helper),
    const UnlockDef('waiter1', Offset(7.0, -3.4), 260, ['porter1'], 'waiter', TileIcon.waiter),
    const UnlockDef('cannon1', Offset(0.3, 3.0), 330, ['h2'], 'cannon', TileIcon.cannon),
    UnlockDef('zoneB', const Offset(4.5, 3.1), 650, const ['waiter1'], 'zoneB_${r.key}', TileIcon.key),
    UnlockDef('h3', h[2], 700, const ['zoneB'], helper, TileIcon.helper),
    const UnlockDef('porter2', Offset(2.0, 5.3), 800, ['zoneB'], 'porter', TileIcon.porter),
    const UnlockDef('waiter2', Offset(7.0, 9.3), 950, ['porter2'], 'waiter', TileIcon.waiter),
    const UnlockDef('cashier', cashierHome, 1500, ['waiter1', 'zoneB'], 'cashier', TileIcon.cashier),
    UnlockDef('h4', h[3], 1200, const ['h3'], helper, TileIcon.helper),
    const UnlockDef('cannon2', Offset(0.3, 9.7), 1400, ['zoneB', 'cannon1'], 'cannon', TileIcon.cannon),
    UnlockDef('landmark', const Offset(0.75, -5.7), 9000, const ['h4', 'waiter2'], 'landmark_${r.key}', TileIcon.landmark),
  ];
}

/// Unlock ids used by version 1 saves.
const Map<String, String> legacyUnlockIds = {
  'harp1': 'h1',
  'harp2': 'h2',
  'harp3': 'h3',
  'harp4': 'h4',
  'chowder': 'zoneB',
  'lighthouse': 'landmark',
};
