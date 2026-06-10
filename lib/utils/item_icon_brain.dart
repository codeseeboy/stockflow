import '../data/food_icon_brain_loader.dart';
import '../data/food_wiki_icons.dart';
import '../data/grocery_icon_catalog.dart';
import '../models/models.dart';

/// Result of the built-in item icon / category matcher.
class ItemVisualSuggestion {
  final String emoji;
  final String category;
  final String unit;
  final String sourceLabel;
  final double confidence;

  const ItemVisualSuggestion({
    required this.emoji,
    required this.category,
    required this.unit,
    required this.sourceLabel,
    required this.confidence,
  });

  static const fallback = ItemVisualSuggestion(
    emoji: '📦',
    category: 'Essentials',
    unit: 'kg',
    sourceLabel: 'Default pack icon',
    confidence: 0,
  );
}

/// Smart matcher: catalog → food wiki → grocery brain → fuzzy fallback.
class ItemIconBrain {
  ItemIconBrain._();

  static ItemVisualSuggestion suggest(String name, List<Item> catalog) {
    final q = name.trim().toLowerCase();
    if (q.isEmpty) return ItemVisualSuggestion.fallback;

    final catalogHit = _matchCatalog(q, catalog);
    if (catalogHit != null) return catalogHit;

    final wikiHit = _matchFoodWiki(q);
    if (wikiHit != null) return wikiHit;

    final brainHit = _matchGroceryBrain(q);
    if (brainHit != null) return brainHit;

    final fuzzyWiki = _fuzzyFoodWiki(q);
    if (fuzzyWiki != null) return fuzzyWiki;

    return ItemVisualSuggestion(
      emoji: '📦',
      category: 'Essentials',
      unit: defaultUnitFor(name, 'Essentials'),
      sourceLabel: 'General item icon',
      confidence: 0.15,
    );
  }

  static ItemVisualSuggestion? _matchCatalog(String q, List<Item> catalog) {
    Item? best;
    var bestScore = 0;

    for (final item in catalog) {
      final score = _nameScore(q, item.name.toLowerCase());
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }

    if (best == null || bestScore < 55) return null;

    return ItemVisualSuggestion(
      emoji: best.emoji,
      category: best.category,
      unit: best.unit,
      sourceLabel: bestScore >= 95 ? 'Same as ${best.name}' : 'Matched ${best.name}',
      confidence: (bestScore / 100).clamp(0.55, 1.0),
    );
  }

  static ItemVisualSuggestion? _matchFoodWiki(String q) {
    final loaded = FoodIconBrainLoader.match(q);
    if (loaded != null) {
      return ItemVisualSuggestion(
        emoji: loaded.emoji,
        category: loaded.category,
        unit: defaultUnitFor(q, loaded.category),
        sourceLabel: 'Brain · ${loaded.matched}',
        confidence: 0.92,
      );
    }

    var bestEmoji = '📦';
    var bestCategory = 'Essentials';
    var bestScore = 0;
    String? bestAlias;

    for (final row in kFoodWikiRows) {
      for (final alias in row.aliases) {
        final score = _aliasScore(q, alias);
        if (score > bestScore) {
          bestScore = score;
          bestEmoji = row.emoji;
          bestCategory = row.category;
          bestAlias = alias;
        }
      }
    }

    if (bestScore < 62) return null;

    return ItemVisualSuggestion(
      emoji: bestEmoji,
      category: bestCategory,
      unit: defaultUnitFor(q, bestCategory),
      sourceLabel: 'Food wiki · $bestAlias',
      confidence: (bestScore / 100).clamp(0.55, 0.98),
    );
  }

  static ItemVisualSuggestion? _fuzzyFoodWiki(String q) {
    final tokens = q.split(RegExp(r'[^a-z0-9]+')).where((w) => w.length >= 4);
    var bestEmoji = '📦';
    var bestCategory = 'Essentials';
    var bestScore = 0;
    String? bestAlias;

    for (final token in tokens) {
      for (final row in kFoodWikiRows) {
        for (final alias in row.aliases) {
          if (alias.length < 4) continue;
          final dist = _levenshtein(token, alias);
          if (dist <= 2) {
            final score = 68 - dist * 8;
            if (score > bestScore) {
              bestScore = score;
              bestEmoji = row.emoji;
              bestCategory = row.category;
              bestAlias = alias;
            }
          }
        }
      }
    }

    if (bestScore < 55) return null;

    return ItemVisualSuggestion(
      emoji: bestEmoji,
      category: bestCategory,
      unit: defaultUnitFor(q, bestCategory),
      sourceLabel: 'Fuzzy match · $bestAlias',
      confidence: (bestScore / 100).clamp(0.45, 0.75),
    );
  }

  static ItemVisualSuggestion? _matchGroceryBrain(String q) {
    var bestEmoji = '📦';
    var bestSection = 'Essentials';
    var bestScore = 0;
    String? bestKeyword;

    for (final row in allGroceryIcons) {
      for (final word in row.keywords.split(RegExp(r'\s+'))) {
        final score = _aliasScore(q, word);
        if (score > bestScore) {
          bestScore = score;
          bestEmoji = row.emoji;
          bestSection = row.section;
          bestKeyword = word;
        }
      }
    }

    if (bestScore < 60) return null;

    final category = refineCategory(bestSection, q);
    return ItemVisualSuggestion(
      emoji: bestEmoji,
      category: category,
      unit: defaultUnitFor(q, category),
      sourceLabel: 'Smart pick · $bestKeyword',
      confidence: (bestScore / 100).clamp(0.5, 0.95),
    );
  }

  static int _aliasScore(String query, String alias) {
    if (alias.length < 2) return 0;
    if (query == alias) return 100;
    if (query.contains(alias)) return 88 + alias.length.clamp(0, 10);
    if (alias.contains(query) && query.length >= 3) return 80 + query.length.clamp(0, 8);

    final qWords = query.split(RegExp(r'\s+')).where((w) => w.length >= 3);
    for (final w in qWords) {
      if (w == alias) return 95;
      if (alias.contains(w) || w.contains(alias)) return 78 + w.length.clamp(0, 8);
    }
    return 0;
  }

  static int _nameScore(String query, String target) {
    if (target == query) return 100;
    if (target.contains(query) || query.contains(target)) return 85;

    final qWords = query.split(RegExp(r'\s+')).where((w) => w.length >= 3);
    final tWords = target.split(RegExp(r'\s+'));
    var hits = 0;
    for (final w in qWords) {
      if (tWords.any((tw) => tw.contains(w) || w.contains(tw))) hits++;
    }
    if (hits == 0) return 0;
    return 50 + hits * 18;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) {
      m[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      m[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        m[i][j] = [
          m[i - 1][j] + 1,
          m[i][j - 1] + 1,
          m[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return m[a.length][b.length];
  }
}
