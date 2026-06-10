import 'dart:convert';

import 'package:flutter/services.dart';

/// Runtime loader for the 18,000+ alias food icon brain (assets/data/food_icon_brain.json).
class FoodIconBrainLoader {
  FoodIconBrainLoader._();

  static Map<String, ({String emoji, String category})>? _lookup;
  static int _aliasCount = 0;

  static bool get isReady => _lookup != null;
  static int get aliasCount => _aliasCount;

  static Future<void> init() async {
    if (_lookup != null) return;
    try {
      final raw = await rootBundle.loadString('assets/data/food_icon_brain.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _aliasCount = (json['alias_count'] as num?)?.toInt() ?? 0;
      final map = json['lookup'] as Map<String, dynamic>? ?? {};
      _lookup = {
        for (final e in map.entries)
          e.key: (
            emoji: (e.value['emoji'] as String?) ?? '📦',
            category: (e.value['category'] as String?) ?? 'Essentials',
          ),
      };
      if (_aliasCount == 0) _aliasCount = _lookup!.length;
    } catch (_) {
      _lookup = {};
      _aliasCount = 0;
    }
  }

  /// Fast O(1) lookup, then token / substring scan.
  static ({String emoji, String category, String matched})? match(String query) {
    final lookup = _lookup;
    if (lookup == null || lookup.isEmpty) return null;
    final q = query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (q.isEmpty) return null;

    final exact = lookup[q];
    if (exact != null) return (emoji: exact.emoji, category: exact.category, matched: q);

    for (final w in q.split(RegExp(r'\s+'))) {
      if (w.length < 3) continue;
      final hit = lookup[w];
      if (hit != null) return (emoji: hit.emoji, category: hit.category, matched: w);
    }

    String? bestKey;
    var bestLen = 0;
    for (final e in lookup.entries) {
      if (e.key.length < 3) continue;
      if (q.contains(e.key) || e.key.contains(q)) {
        if (e.key.length > bestLen) {
          bestLen = e.key.length;
          bestKey = e.key;
        }
      }
    }
    if (bestKey != null) {
      final hit = lookup[bestKey]!;
      return (emoji: hit.emoji, category: hit.category, matched: bestKey);
    }
    return null;
  }
}
