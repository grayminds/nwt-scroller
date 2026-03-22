import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_entry.dart';

class HistoryRepository {
  static const _key = 'nwt_scroller_history';
  static const maxEntries = 25;

  Future<List<HistoryEntry>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final List<dynamic> list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to load history: $e');
      return [];
    }
  }

  Future<void> add(HistoryEntry entry) async {
    final entries = await load();
    entries.insert(0, entry);
    if (entries.length > maxEntries) {
      entries.removeRange(maxEntries, entries.length);
    }
    await _save(entries);
  }

  Future<void> removeAt(int index) async {
    final entries = await load();
    if (index >= 0 && index < entries.length) {
      entries.removeAt(index);
      await _save(entries);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _save(List<HistoryEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = json.encode(entries.map((e) => e.toJson()).toList());
      await prefs.setString(_key, raw);
    } catch (e) {
      debugPrint('Failed to save history: $e');
    }
  }
}
