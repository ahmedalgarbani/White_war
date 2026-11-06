import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the game state and the player's settings.
class SaveStore {
  SaveStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'white_war_save_v1';

  static Future<SaveStore?> open() async {
    try {
      return SaveStore(await SharedPreferences.getInstance());
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? load() {
    final s = _prefs.getString(_key);
    if (s == null) return null;
    try {
      final v = jsonDecode(s);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    try {
      await _prefs.setString(_key, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      await _prefs.remove(_key);
    } catch (_) {}
  }

  String? get lang => _prefs.getString('ww_lang');
  set lang(String? v) => v == null ? _prefs.remove('ww_lang') : _prefs.setString('ww_lang', v);

  bool get sound => _prefs.getBool('ww_sound') ?? true;
  set sound(bool v) => _prefs.setBool('ww_sound', v);

  bool get music => _prefs.getBool('ww_music') ?? true;
  set music(bool v) => _prefs.setBool('ww_music', v);

  bool get vibration => _prefs.getBool('ww_vibe') ?? true;
  set vibration(bool v) => _prefs.setBool('ww_vibe', v);
}
