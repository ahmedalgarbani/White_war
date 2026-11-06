import 'defs.dart';

/// Arabic / English string table.
class Tr {
  static String lang = 'ar';

  static bool get rtl => lang == 'ar';

  static const Map<String, Map<String, String>> _t = {
    'title': {'ar': 'الحرب البيضاء', 'en': 'WHITE WAR'},
    'play': {'ar': 'ابدأ اللعب', 'en': 'PLAY'},
    'continue': {'ar': 'متابعة', 'en': 'CONTINUE'},
    'howto': {
      'ar': 'اسحب للتحرك • اجمع الموارد تلقائياً • اصنع وبِع ووسّع\nاحمِ معسكرك في حرب الثلج وسافر عبر 3 مناطق بلا نهاية!',
      'en': 'Drag to move • gather automatically • craft, sell and expand\nwin the Snow War and travel an endless 3-region expedition!',
    },
    // regions
    'region_harbor': {'ar': 'ميناء الصقيع', 'en': 'Frost Harbor'},
    'region_quarry': {'ar': 'منجم البلّور', 'en': 'Crystal Quarry'},
    'region_timber': {'ar': 'وادي الحطّابين', 'en': 'Timber Hollow'},
    'regiondesc_harbor': {'ar': 'اصطد السمك بالحربة واصنع أقراص السمك والحساء', 'en': 'Harpoon fish, cook fish cakes and chowder'},
    'regiondesc_quarry': {'ar': 'انقب البلّور واصنع سبائك ومصابيح مضيئة', 'en': 'Mine glowing crystals, craft bars and lamps'},
    'regiondesc_timber': {'ar': 'احطب الأشجار واصنع حزم الحطب والزلاجات', 'en': 'Chop trees, make firewood and sleds'},
    // helpers & unlocks
    'helper_harbor': {'ar': 'صيّاد', 'en': 'Harpooner'},
    'helper_quarry': {'ar': 'منقّب', 'en': 'Miner'},
    'helper_timber': {'ar': 'حطّاب', 'en': 'Lumberjack'},
    'porter': {'ar': 'حمّال', 'en': 'Porter'},
    'waiter': {'ar': 'بائع', 'en': 'Seller'},
    'cashier': {'ar': 'أمين الصندوق', 'en': 'Cashier'},
    'cannon': {'ar': 'مدفع الثلج', 'en': 'Snow Cannon'},
    'zoneB_harbor': {'ar': 'بيت الحساء', 'en': 'Chowder House'},
    'zoneB_quarry': {'ar': 'ورشة المصابيح', 'en': 'Lamp Works'},
    'zoneB_timber': {'ar': 'ورشة الزلاجات', 'en': 'Sled Workshop'},
    'landmark_harbor': {'ar': 'منارة الشفق', 'en': 'Aurora Lighthouse'},
    'landmark_quarry': {'ar': 'برج البلّور', 'en': 'Crystal Spire'},
    'landmark_timber': {'ar': 'الموقد العظيم', 'en': 'Great Hearth'},
    'newArea': {'ar': 'منطقة جديدة مفتوحة!', 'en': 'A new area is open!'},
    'unlocked': {'ar': 'تم الفتح!', 'en': 'Unlocked!'},
    'landmarkDone': {'ar': 'اكتملت المنطقة! الأسعار ×2 والرحلة تنتظرك', 'en': 'Region complete! Prices ×2 — the expedition awaits'},
    // stations
    'st_pad_harbor': {'ar': 'منصة السمك', 'en': 'Fish pad'},
    'st_pad_quarry': {'ar': 'منصة البلّور', 'en': 'Crystal pad'},
    'st_pad_timber': {'ar': 'منصة الخشب', 'en': 'Log pad'},
    'st_procA_harbor': {'ar': 'الشوّاية', 'en': 'Grill'},
    'st_procA_quarry': {'ar': 'آلة الصقل', 'en': 'Cutter'},
    'st_procA_timber': {'ar': 'جذع التقطيع', 'en': 'Chopping block'},
    'st_standA_harbor': {'ar': 'كشك الأقراص', 'en': 'Cake stand'},
    'st_standA_quarry': {'ar': 'كشك السبائك', 'en': 'Bar stand'},
    'st_standA_timber': {'ar': 'كشك الحطب', 'en': 'Firewood stand'},
    'st_procB_harbor': {'ar': 'قِدر الحساء', 'en': 'Chowder pot'},
    'st_procB_quarry': {'ar': 'فرن المصابيح', 'en': 'Lamp forge'},
    'st_procB_timber': {'ar': 'طاولة الزلاجات', 'en': 'Sled bench'},
    'st_standB_harbor': {'ar': 'كشك الحساء', 'en': 'Chowder stand'},
    'st_standB_quarry': {'ar': 'كشك المصابيح', 'en': 'Lamp stand'},
    'st_standB_timber': {'ar': 'كشك الزلاجات', 'en': 'Sled stand'},
    // item names (plural, used in quests)
    'raw_harbor': {'ar': 'سمكة', 'en': 'fish'},
    'raw_quarry': {'ar': 'بلّورة', 'en': 'crystals'},
    'raw_timber': {'ar': 'جذع', 'en': 'logs'},
    'rare_harbor': {'ar': 'سمكة ذهبية', 'en': 'golden fish'},
    'rare_quarry': {'ar': 'بلّورة شفق', 'en': 'aurora crystals'},
    'rare_timber': {'ar': 'جذع ذهبي', 'en': 'golden logs'},
    'prodA_harbor': {'ar': 'قرص سمك', 'en': 'fish cakes'},
    'prodA_quarry': {'ar': 'سبيكة بلّور', 'en': 'crystal bars'},
    'prodA_timber': {'ar': 'حزمة حطب', 'en': 'firewood bundles'},
    'prodB_harbor': {'ar': 'وعاء حساء', 'en': 'chowder bowls'},
    'prodB_quarry': {'ar': 'مصباح', 'en': 'crystal lamps'},
    'prodB_timber': {'ar': 'زلاجة', 'en': 'sleds'},
    'enemy_harbor': {'ar': 'ذئب صقيع', 'en': 'frost wolves'},
    'enemy_quarry': {'ar': 'عملاق جليد', 'en': 'ice golems'},
    'enemy_timber': {'ar': 'يتي', 'en': 'yetis'},
    // raids
    'raidIn': {'ar': 'حرب الثلج بعد', 'en': 'Snow War in'},
    'bossIn': {'ar': 'زعيم قادم بعد', 'en': 'Boss raid in'},
    'raidNow': {'ar': 'حرب الثلج!', 'en': 'SNOW WAR!'},
    'raidSub': {'ar': 'العاصفة وصلت والأعداء قادمون لسرقة مخزونك', 'en': 'The storm hits — raiders are coming for your goods'},
    'bossNow': {'ar': 'هجوم الزعيم!', 'en': 'BOSS RAID!'},
    'bossSub': {'ar': 'زعيم ضخم يقود الهجوم — اهزمه لتربح بلورات كثيرة', 'en': 'A giant leads the attack — beat it for a crystal haul'},
    'victory': {'ar': 'انتصار!', 'en': 'VICTORY!'},
    'crystals': {'ar': 'بلورة', 'en': 'crystals'},
    // workshop
    'workshop': {'ar': 'الورشة', 'en': 'Workshop'},
    'upgrades': {'ar': 'التطويرات', 'en': 'Upgrades'},
    'wardrobe': {'ar': 'خزانة الملابس', 'en': 'Wardrobe'},
    'upg_power': {'ar': 'قوة الضرب', 'en': 'Power'},
    'upg_rate': {'ar': 'سرعة الضرب', 'en': 'Attack Speed'},
    'upg_capacity': {'ar': 'سعة الحمل', 'en': 'Carry Capacity'},
    'upg_speed': {'ar': 'سرعة المشي', 'en': 'Move Speed'},
    'upg_helpers': {'ar': 'سرعة العمّال', 'en': 'Helper Speed'},
    'upg_income': {'ar': 'زيادة الأرباح', 'en': 'Income Boost'},
    'upgd_power': {'ar': 'ضرر أكبر للموارد والأعداء', 'en': 'More damage to resources and raiders'},
    'upgd_rate': {'ar': 'تضرب وترمي أسرع', 'en': 'Hit and throw faster'},
    'upgd_capacity': {'ar': 'تحمل أكثر أنت والعمّال', 'en': 'You and your helpers carry more'},
    'upgd_speed': {'ar': 'تتحرك أسرع', 'en': 'Move faster'},
    'upgd_helpers': {'ar': 'العمّال والجامعون أسرع', 'en': 'Helpers work and walk faster'},
    'upgd_income': {'ar': '+6% على كل المبيعات', 'en': '+6% on every sale'},
    'level': {'ar': 'مستوى', 'en': 'Lv'},
    'maxLevel': {'ar': 'الأقصى', 'en': 'MAX'},
    'max': {'ar': 'ممتلئ', 'en': 'FULL'},
    'gemsHint': {
      'ar': 'البلورات من هزيمة الأعداء والزعماء والموارد النادرة والمهام',
      'en': 'Crystals come from raiders, bosses, rare resources and quests',
    },
    'wear': {'ar': 'ارتدِ', 'en': 'Wear'},
    'wearing': {'ar': 'ترتديه', 'en': 'Wearing'},
    'outfit_red': {'ar': 'الحارس الأحمر', 'en': 'Red Ranger'},
    'outfit_glacier': {'ar': 'الجليدي', 'en': 'Glacier'},
    'outfit_pine': {'ar': 'الصنوبري', 'en': 'Pine Scout'},
    'outfit_aurora': {'ar': 'الشفق', 'en': 'Aurora'},
    'outfit_golden': {'ar': 'الذهبي', 'en': 'Golden'},
    'outfit_midnight': {'ar': 'منتصف الليل', 'en': 'Midnight'},
    // quests
    'quests': {'ar': 'المهام', 'en': 'Quests'},
    'claim': {'ar': 'استلم', 'en': 'Claim'},
    'q_harvest': {'ar': 'اجمع {n} {raw}', 'en': 'Gather {n} {raw}'},
    'q_rare': {'ar': 'احصل على {n} {rare}', 'en': 'Get {n} {rare}'},
    'q_sellA': {'ar': 'بِع {n} {prodA}', 'en': 'Sell {n} {prodA}'},
    'q_sellB': {'ar': 'بِع {n} {prodB}', 'en': 'Sell {n} {prodB}'},
    'q_defeat': {'ar': 'اهزم {n} {enemy}', 'en': 'Defeat {n} {enemy}'},
    'q_earn': {'ar': 'اربح {n} عملة', 'en': 'Earn {n} coins'},
    'q_levelUp': {'ar': 'طوّر المحطات {n} مرة', 'en': 'Upgrade stations {n}×'},
    'q_unlock': {'ar': 'افتح شيئاً جديداً', 'en': 'Unlock something new'},
    // expedition
    'expedition': {'ar': 'الرحلة', 'en': 'Expedition'},
    'travel': {'ar': 'سافر', 'en': 'Travel'},
    'travelTo': {'ar': 'السفر إلى', 'en': 'Travel to'},
    'travelInfo': {
      'ar': 'تحتفظ بالبلورات والتطويرات والملابس، وتحصل على +25% أرباح دائمة. العملات تبقى هنا.',
      'en': 'You keep crystals, upgrades and outfits, and gain a permanent +25% income. Coins stay behind.',
    },
    'travelLocked': {'ar': 'ابنِ المعلم الأخير في هذه المنطقة لتفتح السفر', 'en': 'Build this region\'s final landmark to unlock travel'},
    'current': {'ar': 'أنت هنا', 'en': 'You are here'},
    'done': {'ar': 'مكتملة', 'en': 'Done'},
    'loopInfo': {
      'ar': 'بعد المنطقة الثالثة تبدأ الرحلة من جديد بنجمة إضافية: أسعار أعلى وأعداء أقوى',
      'en': 'After the third region the journey starts over with an extra star: bigger prices, tougher raiders',
    },
    'bonus': {'ar': 'مكافأة الأرباح', 'en': 'Income bonus'},
    'stay': {'ar': 'ابقَ هنا', 'en': 'Stay'},
    // offline
    'welcomeBack': {'ar': 'أهلاً بعودتك!', 'en': 'Welcome back!'},
    'offlineEarned': {'ar': 'عمّالك ربحوا أثناء غيابك', 'en': 'Your helpers earned while you were away'},
    'collect': {'ar': 'اجمع', 'en': 'Collect'},
    // misc
    'settings': {'ar': 'الإعدادات', 'en': 'Settings'},
    'sound': {'ar': 'المؤثرات الصوتية', 'en': 'Sound effects'},
    'music': {'ar': 'الموسيقى', 'en': 'Music'},
    'vibration': {'ar': 'الاهتزاز', 'en': 'Vibration'},
    'language': {'ar': 'اللغة', 'en': 'Language'},
    'reset': {'ar': 'البدء من جديد', 'en': 'Reset progress'},
    'resetConfirm': {'ar': 'هل تريد حذف كل التقدّم؟', 'en': 'Delete all progress?'},
    'yes': {'ar': 'نعم', 'en': 'Yes'},
    'no': {'ar': 'لا', 'en': 'No'},
    'close': {'ar': 'إغلاق', 'en': 'Close'},
    'levelUp': {'ar': 'ترقية!', 'en': 'Level up!'},
    'credits': {'ar': 'لعبة أصلية • كل الرسوم والأصوات مولّدة بالكود', 'en': 'Original game • all art & sound generated in code'},
  };

  static String t(String key) => _t[key]?[lang] ?? _t[key]?['en'] ?? key;

  static String region(RegionDef r) => t('region_${r.key}');

  static String station(StationKind k, RegionDef r) => t('st_${k.name}_${r.key}');

  static String quest(QuestKind k, int n, RegionDef r) => t('q_${k.name}')
      .replaceAll('{n}', '$n')
      .replaceAll('{raw}', t('raw_${r.key}'))
      .replaceAll('{rare}', t('rare_${r.key}'))
      .replaceAll('{prodA}', t('prodA_${r.key}'))
      .replaceAll('{prodB}', t('prodB_${r.key}'))
      .replaceAll('{enemy}', t('enemy_${r.key}'));
}
