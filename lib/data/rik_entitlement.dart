/// Real Indian Navy RIK (Ration In Kind) entitlement scale — OFFICERS.
///
/// Source: "RIK ENTITLEMENT DETAILS - OFFICERS.xlsx" (docs/). Each category has a
/// per-officer, per-DAY entitlement, a unit, and the articles / in-lieu items
/// that can fulfil it. This is the authoritative data the ration app is built
/// on. Pure data — no Flutter imports — so it can be shared everywhere.
library;

/// A specific product option within a category. [inLieu] items are pre-approved
/// substitutes for the same entitlement.
class RikArticle {
  final String name;
  final bool inLieu;
  const RikArticle(this.name, {this.inLieu = false});
}

/// One RIK entitlement category (17 total for officers).
class RikCategory {
  final int ser;
  final String name; // short display name
  final String emoji;
  final String unit; // kg | litre | nos
  final double perDay; // entitlement per officer per day
  final List<RikArticle> articles;
  const RikCategory({
    required this.ser,
    required this.name,
    required this.emoji,
    required this.unit,
    required this.perDay,
    required this.articles,
  });
}

const kRikOfficers = <RikCategory>[
  RikCategory(ser: 1, name: 'Cereals', emoji: '🌾', unit: 'kg', perDay: 0.45, articles: [
    RikArticle('Atta 1 kg'),
    RikArticle('Atta 5 kg'),
    RikArticle('India Gate Rozana 1 kg'),
    RikArticle('India Gate Rozana 5 kg'),
    RikArticle('India Gate Basmati Premium 1 kg'),
    RikArticle('Dawat Basmati Pulao Rice 1 kg'),
    RikArticle('Dawat Biriyani Rice 1 kg'),
    RikArticle('Matta Naad Rice (Red) 1 kg'),
    RikArticle('Rice Long Grain (Aeroplane) 1 kg'),
    RikArticle('Sharbati Rice 1 kg'),
    RikArticle('Rice Sona Masuri 1 kg'),
    RikArticle('Millets 1 kg'),
    RikArticle('Bread White 600 g'),
    RikArticle('Brown Bread 400 g'),
    RikArticle('Multigrain Bread 400 g'),
    RikArticle('Pav Bun 140 g'),
  ]),
  RikCategory(ser: 2, name: 'Dal', emoji: '🫘', unit: 'kg', perDay: 0.04, articles: [
    RikArticle('Dal Arhar 400 g'),
    RikArticle('Dal Chana 400 g'),
    RikArticle('Masoor Whole 400 g'),
    RikArticle('Masoor Split 400 g'),
    RikArticle('Moong Whole 400 g'),
    RikArticle('Moong Split 400 g'),
    RikArticle('Urd Whole 400 g'),
    RikArticle('Urd Split 400 g'),
    RikArticle('Peas Dry 400 g'),
    RikArticle('Beans Dry 400 g'),
    RikArticle('Gram Whole Black 400 g'),
    RikArticle('Kabuli Chana 400 g'),
    RikArticle('Lobia 400 g'),
  ]),
  RikCategory(ser: 3, name: 'Refined Oil', emoji: '🛢️', unit: 'litre', perDay: 0.08, articles: [
    RikArticle('Refined Oil 1 L'),
    RikArticle('Mustard Oil 1 L', inLieu: true),
    RikArticle('Coconut Oil 500 ml', inLieu: true),
  ]),
  RikCategory(ser: 4, name: 'Sugar', emoji: '🍬', unit: 'kg', perDay: 0.09, articles: [
    RikArticle('Sugar 1 kg'),
    RikArticle('Jaggery 500 g', inLieu: true),
  ]),
  RikCategory(ser: 5, name: 'Milk', emoji: '🥛', unit: 'litre', perDay: 0.25, articles: [
    RikArticle('Milk Fresh (coupons)'),
    RikArticle('Milk Tinned', inLieu: true),
    RikArticle('Milk Powder', inLieu: true),
  ]),
  RikCategory(ser: 6, name: 'Meat', emoji: '🍖', unit: 'kg', perDay: 0.26, articles: [
    RikArticle('Meat Fresh 1 kg'),
    RikArticle("Fowl 'D' 2 kg", inLieu: true),
    RikArticle('Fish Fresh 10 kg', inLieu: true),
    RikArticle('Prawns 1 kg', inLieu: true),
    RikArticle('Eggs (4 nos)', inLieu: true),
  ]),
  RikCategory(ser: 7, name: 'Vegetables', emoji: '🥦', unit: 'kg', perDay: 0.17, articles: [
    RikArticle('Ash Gourd'),
    RikArticle('Beans French'),
    RikArticle('Beetroot'),
    RikArticle('Bitter Gourd'),
    RikArticle('Bottle Gourd'),
    RikArticle('Brinjal'),
    RikArticle('Cabbage'),
    RikArticle('Capsicum'),
    RikArticle('Carrot'),
    RikArticle('Cauliflower'),
    RikArticle('Chilly Green'),
    RikArticle('Coriander Green'),
    RikArticle('Cucumber'),
    RikArticle('Drum Stick'),
    RikArticle('Ginger Fresh'),
    RikArticle('Lady Finger'),
    RikArticle('Peas Green'),
    RikArticle('Pumpkin'),
    RikArticle('Spinach'),
    RikArticle('Tomato'),
    RikArticle('Mushroom'),
  ]),
  RikCategory(ser: 8, name: 'Potato', emoji: '🥔', unit: 'kg', perDay: 0.11, articles: [
    RikArticle('Potato'),
  ]),
  RikCategory(ser: 9, name: 'Onion', emoji: '🧅', unit: 'kg', perDay: 0.06, articles: [
    RikArticle('Onion'),
  ]),
  RikCategory(ser: 10, name: 'Eggs', emoji: '🥚', unit: 'nos', perDay: 2, articles: [
    RikArticle('Eggs'),
    RikArticle('Vegetable Fresh', inLieu: true),
    RikArticle('Meat Fresh', inLieu: true),
  ]),
  RikCategory(ser: 11, name: 'Tea/Coffee', emoji: '🍵', unit: 'kg', perDay: 0.009, articles: [
    RikArticle('Tea 250 g'),
    RikArticle('Coffee 50 g', inLieu: true),
  ]),
  RikCategory(ser: 12, name: 'Fruit', emoji: '🍎', unit: 'kg', perDay: 0.23, articles: [
    RikArticle('Apple Delicious'),
    RikArticle('Apple Royal'),
    RikArticle('Banana Yellow'),
    RikArticle('Grapes Seedless'),
    RikArticle('Guava'),
    RikArticle('Mango Alphonso'),
    RikArticle('Mango Neelam'),
    RikArticle('Musambies'),
    RikArticle('Muskmelon'),
    RikArticle('Orange'),
    RikArticle('Papaya'),
    RikArticle('Pineapple'),
    RikArticle('Pomegranate'),
    RikArticle('Sour Lime'),
    RikArticle('Watermelon'),
    RikArticle('Chickoo'),
    RikArticle('Kiwi'),
    RikArticle('Pears Hard'),
  ]),
  RikCategory(ser: 13, name: 'Dalia', emoji: '🥣', unit: 'kg', perDay: 0.02, articles: [
    RikArticle('Dalia 250 g'),
    RikArticle('Sago 100 g', inLieu: true),
    RikArticle('Cornflour 100 g', inLieu: true),
    RikArticle('Custard Powder 100 g', inLieu: true),
    RikArticle('Cornflakes 500 g', inLieu: true),
    RikArticle('Semolina 850 g', inLieu: true),
  ]),
  RikCategory(ser: 14, name: 'Butter', emoji: '🧈', unit: 'kg', perDay: 0.02, articles: [
    RikArticle('Butter 100 g'),
    RikArticle('Refined Oil 1 L', inLieu: true),
  ]),
  RikCategory(ser: 15, name: 'Condiments', emoji: '🌶️', unit: 'kg', perDay: 0.02, articles: [
    RikArticle('Chilly Powder 100 g', inLieu: true),
    RikArticle('Turmeric Powder 100 g', inLieu: true),
    RikArticle('Coriander Powder 100 g', inLieu: true),
    RikArticle('Cuminseed 100 g', inLieu: true),
    RikArticle('Tamarind 100 g', inLieu: true),
    RikArticle('Cinnamon Stick 100 g', inLieu: true),
    RikArticle('Cardamom Large 100 g', inLieu: true),
    RikArticle('Cloves 100 g', inLieu: true),
    RikArticle('Black Pepper 100 g', inLieu: true),
    RikArticle('Bay Leaf 100 g', inLieu: true),
    RikArticle('Mustard Whole 100 g', inLieu: true),
    RikArticle('Garam Masala 100 g', inLieu: true),
    RikArticle('Sabji Masala 100 g', inLieu: true),
    RikArticle('Chat Masala 100 g', inLieu: true),
    RikArticle('Meat Masala 100 g', inLieu: true),
    RikArticle('Chicken Masala 100 g', inLieu: true),
  ]),
  RikCategory(ser: 16, name: 'Salt', emoji: '🧂', unit: 'kg', perDay: 0.02, articles: [
    RikArticle('Salt 1 kg'),
  ]),
  RikCategory(ser: 17, name: 'LPG', emoji: '🔥', unit: 'kg', perDay: 0.15, articles: [
    RikArticle('LPG (14.2 kg cylinder)'),
  ]),
];

RikCategory? rikCategoryByName(String name) {
  for (final c in kRikOfficers) {
    if (c.name == name) return c;
  }
  return null;
}

final Map<String, String> _articleToCategory = {
  for (final c in kRikOfficers)
    for (final a in c.articles) a.name.toLowerCase(): c.name,
};

/// The RIK category an article belongs to, by article name. Used to attribute a
/// historic order line to a category when the item itself is no longer around.
String? rikCategoryForArticle(String articleName) =>
    _articleToCategory[articleName.trim().toLowerCase()];

/// Match a free-text category name (from an uploaded sheet) to a RIK category.
/// Returns null when nothing matches, so a bad row can be reported rather than
/// silently landing in the wrong bucket.
String? matchRikCategory(String text) {
  final t = text.trim().toLowerCase();
  if (t.isEmpty) return null;
  for (final c in kRikOfficers) {
    if (c.name.toLowerCase() == t) return c.name;
  }
  // Common wordings from the unit's sheets.
  const aliases = <String, String>{
    'cereal': 'Cereals',
    'grain': 'Cereals',
    'grains': 'Cereals',
    'atta': 'Cereals',
    'rice': 'Cereals',
    'bread': 'Cereals',
    'pulses': 'Dal',
    'pulse': 'Dal',
    'oil': 'Refined Oil',
    'refined oil': 'Refined Oil',
    'edible oil': 'Refined Oil',
    'meat': 'Meat',
    'chicken': 'Meat',
    'mutton': 'Meat',
    'fish': 'Meat',
    'vegetable': 'Vegetables',
    'vegetables': 'Vegetables',
    'veg': 'Vegetables',
    'fruit': 'Fruit',
    'fruits': 'Fruit',
    'egg': 'Eggs',
    'eggs': 'Eggs',
    'milk': 'Milk',
    'tea': 'Tea/Coffee',
    'coffee': 'Tea/Coffee',
    'tea/coffee': 'Tea/Coffee',
    'sugar': 'Sugar',
    'salt': 'Salt',
    'butter': 'Butter',
    'potato': 'Potato',
    'potatoes': 'Potato',
    'onion': 'Onion',
    'onions': 'Onion',
    'condiment': 'Condiments',
    'condiments': 'Condiments',
    'spices': 'Condiments',
    'masala': 'Condiments',
    'dalia': 'Dalia',
    'lpg': 'LPG',
    'gas': 'LPG',
  };
  final alias = aliases[t];
  if (alias != null) return alias;
  for (final c in kRikOfficers) {
    final n = c.name.toLowerCase();
    if (n.startsWith(t) || t.startsWith(n)) return c.name;
  }
  return null;
}

final Set<String> _inLieuNames = {
  for (final c in kRikOfficers)
    for (final a in c.articles)
      if (a.inLieu) a.name,
};

/// True when [itemName] is a pre-approved in-lieu substitute in any category.
bool isInLieuArticle(String itemName) => _inLieuNames.contains(itemName);
