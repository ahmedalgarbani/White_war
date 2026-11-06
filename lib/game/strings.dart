/// Tiny Arabic / English string table.
class Tr {
  static String lang = 'ar';

  static bool get rtl => lang == 'ar';

  static const Map<String, Map<String, String>> _t = {
    'title': {'ar': 'الحرب البيضاء', 'en': 'WHITE WAR'},
    'subtitle': {'ar': 'ميناء الصقيع', 'en': 'FROST HARBOR'},
    'play': {'ar': 'ابدأ اللعب', 'en': 'PLAY'},
    'continue': {'ar': 'متابعة', 'en': 'CONTINUE'},
    'howto': {
      'ar': 'اسحب للتحرك • قف على الرصيف لتصطاد تلقائياً\nاطبخ أقراص السمك وبِعها ووسّع ميناءك\nواحمِه من ذئاب الصقيع في حرب الثلج!',
      'en': 'Drag to move • Stand on the dock to auto-harpoon fish\nCook fish cakes, sell them and grow your harbor\nthen defend it from frost wolves in the Snow War!',
    },
    'harpooner': {'ar': 'صيّاد', 'en': 'Harpooner'},
    'porter': {'ar': 'حمّال', 'en': 'Porter'},
    'waiter': {'ar': 'نادل', 'en': 'Waiter'},
    'cannon': {'ar': 'مدفع الثلج', 'en': 'Snow Cannon'},
    'chowderHouse': {'ar': 'بيت الحساء', 'en': 'Chowder House'},
    'lighthouse': {'ar': 'منارة الشفق', 'en': 'Aurora Lighthouse'},
    'raidIn': {'ar': 'حرب الثلج بعد', 'en': 'Snow War in'},
    'raidNow': {'ar': 'حرب الثلج!', 'en': 'SNOW WAR!'},
    'raidSub': {'ar': 'تجمّد النهر وذئاب الصقيع قادمة لسرقة السمك', 'en': 'The river froze — frost wolves are coming for your fish'},
    'victory': {'ar': 'انتصار!', 'en': 'VICTORY!'},
    'crystals': {'ar': 'بلورة', 'en': 'crystals'},
    'wolves': {'ar': 'ذئاب', 'en': 'wolves'},
    'workshop': {'ar': 'الورشة', 'en': 'Workshop'},
    'upg_power': {'ar': 'قوة الرمي', 'en': 'Throw Power'},
    'upg_rate': {'ar': 'سرعة الرمي', 'en': 'Throw Speed'},
    'upg_capacity': {'ar': 'سعة الحمل', 'en': 'Carry Capacity'},
    'upg_speed': {'ar': 'سرعة المشي', 'en': 'Move Speed'},
    'upg_kitchen': {'ar': 'سرعة المطبخ', 'en': 'Kitchen Speed'},
    'upgd_power': {'ar': 'ضرر أكبر للأسماك والذئاب', 'en': 'More damage to fish and wolves'},
    'upgd_rate': {'ar': 'رمي أسرع لك وللصيادين', 'en': 'Faster throws for you and harpooners'},
    'upgd_capacity': {'ar': 'تحمل أكثر أنت والعمال', 'en': 'You and your helpers carry more'},
    'upgd_speed': {'ar': 'تتحرك أسرع في الميناء', 'en': 'Move faster around the harbor'},
    'upgd_kitchen': {'ar': 'طبخ وبيع أسرع', 'en': 'Cook and sell faster'},
    'level': {'ar': 'مستوى', 'en': 'Lv'},
    'max': {'ar': 'ممتلئ', 'en': 'FULL'},
    'maxLevel': {'ar': 'الأقصى', 'en': 'MAX'},
    'gemsHint': {
      'ar': 'اكسب بلورات الصقيع بهزيمة الذئاب وصيد الأسماك الذهبية والعملاقة',
      'en': 'Earn frost crystals by beating wolves and catching golden or giant fish',
    },
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
    'harbor': {'ar': 'الميناء', 'en': 'Harbor'},
    'unlocked': {'ar': 'تم الفتح!', 'en': 'Unlocked!'},
    'lighthouseDone': {'ar': 'المنارة تضيء! أسعار البيع ×2', 'en': 'The lighthouse shines! Sale prices ×2'},
    'newArea': {'ar': 'منطقة جديدة: حساء السمك', 'en': 'New area: fish chowder'},
    'paused': {'ar': 'متوقف مؤقتاً', 'en': 'Paused'},
    'resume': {'ar': 'استئناف', 'en': 'Resume'},
    'credits': {'ar': 'لعبة أصلية • كل الرسوم والأصوات مولّدة بالكود', 'en': 'Original game • all art & sound generated in code'},
  };

  static String t(String key) => _t[key]?[lang] ?? _t[key]?['en'] ?? key;
}
