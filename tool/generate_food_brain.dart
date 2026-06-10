// Run: dart run tool/generate_food_brain.dart
// Generates assets/data/food_icon_brain.json with 10,000+ food name aliases.
import 'dart:convert';
import 'dart:io';

void main() {
  const maxAliases = 18000;
  final lookup = <String, Map<String, String>>{};
  var entryCount = 0;

  void register(String alias, String emoji, String category) {
    if (lookup.length >= maxAliases) return;
    final key = alias.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (key.length < 2) return;
    lookup.putIfAbsent(key, () => {'emoji': emoji, 'category': category});
  }

  void add(String emoji, String category, List<String> names) {
    entryCount++;
    const prefixes = ['', 'fresh ', 'organic ', 'frozen ', 'dried ', 'raw ', 'premium ', 'indian ', 'imported ', 'best ', 'pure ', 'whole '];
    const suffixes = ['', ' kg', ' packet', ' box'];

    for (final name in names) {
      final base = name.trim().toLowerCase();
      if (base.isEmpty) continue;
      register(base, emoji, category);
      for (final p in prefixes) {
        register('$p$base'.trim(), emoji, category);
        for (final s in suffixes) {
          if (s.isNotEmpty) register('$p$base$s'.trim(), emoji, category);
        }
      }
      if (base.length > 4) {
        register(base.replaceAll('oo', 'o'), emoji, category);
        register('${base}s', emoji, category);
      }
      if (lookup.length >= maxAliases) return;
    }
  }

  // --- Grains (extensive) ---
  add('🍚', 'Grains', [
    'rice', 'basmati rice', 'basmati', 'chawal', 'brown rice', 'white rice', 'jasmine rice', 'sona masuri',
    'kolam rice', 'parboiled rice', 'sella rice', 'steam rice', 'raw rice', 'boiled rice', 'ponni rice',
    'indrayani rice', 'ambemohar', 'gobindobhog', 'red rice', 'black rice', 'wild rice', 'sticky rice',
    'glutinous rice', 'arborio rice', 'sushi rice', 'idli rice', 'poha rice', 'flattened rice', 'poha',
    'chivda', 'chura', 'kheel', 'murmura', 'puffed rice', 'rice flour', 'rice bran', 'rice flakes',
  ]);
  add('🌾', 'Grains', [
    'wheat', 'atta', 'wheat flour', 'flour', 'maida', 'all purpose flour', 'bread flour', 'whole wheat',
    'multigrain flour', 'semolina', 'suji', 'rava', 'sooji', 'durum wheat', 'bulgur', 'cracked wheat',
    'besan', 'gram flour', 'chickpea flour', 'cornflour', 'corn starch', 'starch', 'arrowroot',
    'sago', 'sabudana', 'tapioca pearls', 'barley', 'jau', 'oats flour', 'rye flour', 'spelt',
  ]);
  add('🌽', 'Grains', ['corn', 'maize', 'makka', 'cornmeal', 'polenta', 'sweet corn', 'corn kernels', 'popcorn maize']);
  add('🍜', 'Grains', [
    'noodles', 'maggi', 'ramen', 'udon', 'soba', 'vermicelli', 'seviyan', 'semiya', 'rice noodles',
    'egg noodles', 'instant noodles', 'cup noodles', 'hakka noodles', 'chow mein', 'rice vermicelli',
  ]);
  add('🍝', 'Grains', ['pasta', 'spaghetti', 'macaroni', 'penne', 'fusilli', 'linguine', 'fettuccine', 'lasagna sheets']);
  add('🥣', 'Grains', [
    'oats', 'oatmeal', 'cereal', 'dalia', 'broken wheat', 'quinoa', 'millets', 'bajra', 'pearl millet',
    'jowar', 'sorghum', 'ragi', 'finger millet', 'foxtail millet', 'barnyard millet', 'kodo millet',
    'little millet', 'proso millet', 'amaranth', 'rajgira', 'buckwheat', 'kuttu', 'teff', 'farro',
  ]);
  add('🍞', 'Bakery', ['bread', 'pav', 'bun', 'loaf', 'sandwich bread', 'multigrain bread', 'brown bread', 'milk bread']);
  add('🥖', 'Bakery', ['baguette', 'french bread', 'garlic bread', 'ciabatta', 'focaccia']);
  add('🥐', 'Bakery', ['croissant', 'puff', 'pastry', 'puff pastry', 'danish']);
  add('🥯', 'Bakery', ['bagel', 'donut', 'doughnut']);
  add('🫓', 'Bakery', [
    'roti', 'chapati', 'naan', 'kulcha', 'paratha', 'thepla', 'puri', 'bhatura', 'tortilla', 'pita',
    'lavash', 'khakhra', 'papad', 'papadum', 'appalam',
  ]);
  add('🍪', 'Bakery', ['biscuit', 'cookie', 'cracker', 'rusk', 'khari', 'marie biscuit', 'digestive biscuit']);
  add('🧇', 'Bakery', ['waffle', 'pancake', 'crepe', 'dosa batter', 'idli batter']);

  // Pulses & nuts
  add('🫘', 'Pulses', [
    'dal', 'lentil', 'toor dal', 'arhar dal', 'moong dal', 'masoor dal', 'urad dal', 'chana dal',
    'rajma', 'kidney beans', 'black eyed pea', 'lobia', 'chickpea', 'kabuli chana', 'black gram',
    'green gram', 'horse gram', 'kulthi', 'moth bean', 'matki', 'cowpea', 'soybean', 'soya bean',
    'split peas', 'whole moong', 'whole urad', 'whole masoor', 'val dal', 'hyacinth bean',
  ]);
  add('🟡', 'Pulses', ['chana dal', 'yellow dal', 'split pea', 'yellow moong', 'yellow lentils']);
  add('🥜', 'Pulses', [
    'peanut', 'groundnut', 'mungfali', 'cashew', 'kaju', 'almond', 'badam', 'walnut', 'akhrot',
    'pistachio', 'pista', 'hazelnut', 'pecan', 'macadamia', 'brazil nut', 'pine nut', 'dates nut',
    'fox nut', 'makhana', 'lotus seeds',
  ]);
  add('🌰', 'Pulses', ['chestnut', 'roasted chana', 'bhuna chana']);

  // Vegetables
  add('🥔', 'Vegetables', ['potato', 'aloo', 'sweet potato', 'shakarkandi', 'baby potato', 'new potato']);
  add('🧅', 'Vegetables', ['onion', 'pyaaz', 'shallot', 'spring onion', 'scallion', 'leek', 'red onion', 'white onion']);
  add('🍅', 'Vegetables', ['tomato', 'tamatar', 'cherry tomato', 'plum tomato', 'roma tomato', 'vine tomato']);
  add('🥕', 'Vegetables', ['carrot', 'gajar', 'baby carrot', 'red carrot']);
  add('🌶️', 'Vegetables', [
    'chilli', 'chili', 'mirch', 'red chilli', 'green chilli', 'jalapeno', 'habanero', 'paprika',
    'bell chilli', 'kashmiri chilli', 'byadgi chilli', 'bird eye chilli', 'chipotle',
  ]);
  add('🫑', 'Vegetables', ['capsicum', 'bell pepper', 'shimla mirch', 'pepper', 'red capsicum', 'yellow capsicum']);
  add('🥬', 'Vegetables', [
    'spinach', 'palak', 'lettuce', 'cabbage', 'patta gobi', 'kale', 'chard', 'mustard greens',
    'methi leaves', 'fenugreek leaves', 'bok choy', 'pak choi', 'collard greens', 'arugula', 'rocket',
    'iceberg lettuce', 'romaine', 'lollo rosso', 'amaranth leaves', 'chaulai', 'bathua', 'chenopodium',
  ]);
  add('🥦', 'Vegetables', ['broccoli', 'cauliflower', 'gobi', 'romanesco', 'broccolini']);
  add('🍆', 'Vegetables', ['brinjal', 'eggplant', 'baingan', 'aubergine', 'baby brinjal']);
  add('🥒', 'Vegetables', [
    'cucumber', 'kheera', 'gherkin', 'zucchini', 'courgette', 'bottle gourd', 'lauki', 'ridge gourd',
    'turai', 'bitter gourd', 'karela', 'snake gourd', 'pumpkin', 'kaddu', 'ash gourd', 'winter melon',
    'sponge gourd', 'tinda', 'apple gourd', 'ivy gourd', 'tendli', 'pointed gourd', 'parwal',
  ]);
  add('🧄', 'Vegetables', ['garlic', 'lehsun', 'garlic paste', 'peeled garlic']);
  add('🫚', 'Vegetables', ['ginger', 'adrak', 'ginger paste', 'young ginger']);
  add('🍄', 'Vegetables', [
    'mushroom', 'button mushroom', 'oyster mushroom', 'shiitake', 'portobello', 'enoki', 'milky mushroom',
  ]);
  add('🫛', 'Vegetables', ['peas', 'matar', 'green peas', 'snow peas', 'sugar snap', 'dried peas']);
  add('🥗', 'Vegetables', ['salad', 'mixed greens', 'coleslaw', 'salad mix']);
  add('🫒', 'Vegetables', ['olive', 'olives', 'black olive', 'green olive']);
  add('🍠', 'Vegetables', ['yam', 'taro', 'arbi', 'cassava', 'tapioca root', 'suran', 'elephant foot yam']);
  add('🌿', 'Vegetables', [
    'coriander', 'dhania', 'parsley', 'mint', 'pudina', 'basil', 'curry leaves', 'dill', 'rosemary',
    'thyme', 'oregano', 'sage', 'lemongrass', 'bay leaf', 'tej patta', 'kaffir lime leaves',
  ]);
  add('🥬', 'Vegetables', [
    'celery', 'asparagus', 'artichoke', 'okra', 'bhindi', 'ladyfinger', 'drumstick', 'moringa',
    'beetroot', 'chukandar', 'radish', 'mooli', 'turnip', 'shalgam', 'knol khol', 'kohlrabi',
    'fennel bulb', 'leek vegetable', 'chinese cabbage', 'napa cabbage', 'bean sprouts', 'bamboo shoots',
  ]);

  // Fruits — common + exotic
  add('🍎', 'Fruits', ['apple', 'seb', 'green apple', 'red apple', 'fuji apple', 'gala apple', 'honeycrisp']);
  add('🍌', 'Fruits', ['banana', 'kela', 'plantain', 'raw banana', 'robusta banana', 'elachi banana']);
  add('🍊', 'Fruits', ['orange', 'santra', 'mandarin', 'tangerine', 'clementine', 'kinnow', 'mosambi', 'sweet lime', 'nagpur orange']);
  add('🍋', 'Fruits', ['lemon', 'nimbu', 'lime', 'kaffir lime', 'key lime', 'sweet lemon']);
  add('🍇', 'Fruits', ['grape', 'angur', 'raisin', 'kishmish', 'black grape', 'green grape', 'sultana', 'currants']);
  add('🍉', 'Fruits', ['watermelon', 'tarbuj', 'muskmelon', 'kharbooja', 'cantaloupe', 'honeydew', 'galia melon']);
  add('🥭', 'Fruits', ['mango', 'aam', 'alphonso', 'hapus', 'kesar mango', 'raw mango', 'totapuri', 'banganapalli', 'dasheri', 'langra']);
  add('🍍', 'Fruits', ['pineapple', 'ananas']);
  add('🍓', 'Fruits', ['strawberry', 'berry', 'blueberry', 'raspberry', 'blackberry', 'cranberry', 'mulberry', 'shahtoot']);
  add('🥥', 'Fruits', ['coconut', 'nariyal', 'tender coconut', 'copra', 'desiccated coconut', 'coconut water']);
  add('🍐', 'Fruits', ['pear', 'nashpati', 'asian pear']);
  add('🍑', 'Fruits', ['peach', 'apricot', 'plum', 'nectarine']);
  add('🍒', 'Fruits', ['cherry', 'sour cherry']);
  add('🫐', 'Fruits', ['blueberry', 'acai', 'goji berry', 'blackcurrant']);
  add('🥝', 'Fruits', ['kiwi', 'kiwifruit', 'passion fruit', 'maracuja', 'passionfruit']);
  add('🥑', 'Fruits', ['avocado', 'avocados', 'butter fruit', 'avocado pear']);
  add('🍈', 'Fruits', [
    'melon', 'dragonfruit', 'dragon fruit', 'pitaya', 'pitahaya', 'rambutan', 'lychee', 'lichee', 'litchi',
    'longan', 'jackfruit', 'kathal', 'durian', 'starfruit', 'carambola', 'persimmon', 'fig', 'anjeer',
    'pomegranate', 'anaar', 'guava', 'amrud', 'papaya', 'papita', 'sapota', 'chikoo', 'sitaphal',
    'custard apple', 'wood apple', 'bel fruit', 'bael', 'tamarind', 'imli', 'jamun', 'java plum',
    'ber', 'indian jujube', 'amla', 'indian gooseberry', 'karonda', 'phalsa', 'rose apple', 'jambul',
    'soursop', 'cherimoya', 'feijoa', 'loquat', 'medlar', 'quince', 'sapodilla', 'mangosteen',
    'salak', 'snake fruit', 'santol', 'langsat', 'duku', 'breadfruit', 'plantain fruit', 'horned melon',
    'kiwano', 'ugli fruit', 'tangelo', 'pomelo', 'grapefruit', 'chakotra', 'kumquat', 'yuzu',
    'buddha hand', 'citron', 'physalis', 'golden berry', 'gooseberry', 'amla candy', 'star apple',
  ]);

  // Dairy
  add('🥛', 'Dairy', ['milk', 'doodh', 'toned milk', 'full cream milk', 'skim milk', 'buttermilk', 'chaas', 'lassi', 'flavoured milk']);
  add('🧀', 'Dairy', ['cheese', 'paneer', 'mozzarella', 'cheddar', 'feta', 'ricotta', 'cream cheese', 'cottage cheese', 'processed cheese']);
  add('🥚', 'Dairy', ['egg', 'anda', 'eggs', 'duck egg', 'quail egg', 'brown egg', 'white egg']);
  add('🧈', 'Dairy', ['butter', 'makhan', 'ghee', 'clarified butter', 'margarine', 'white butter']);
  add('🍦', 'Dairy', ['ice cream', 'icecream', 'kulfi', 'frozen yogurt', 'gelato']);
  add('🍶', 'Dairy', ['curd', 'yogurt', 'dahi', 'greek yogurt', 'shrikhand', 'buttermilk curd']);

  // Meat & seafood
  add('🍗', 'Essentials', ['chicken', 'murga', 'poultry', 'chicken breast', 'chicken leg', 'chicken wings', 'chicken curry cut']);
  add('🍖', 'Essentials', ['mutton', 'lamb', 'goat meat', 'keema', 'mutton curry cut']);
  add('🥩', 'Essentials', ['meat', 'beef', 'steak', 'pork', 'bacon', 'ham', 'sausage', 'salami', 'pepperoni']);
  add('🐟', 'Essentials', [
    'fish', 'machli', 'salmon', 'tuna', 'pomfret', 'rohu', 'hilsa', 'sardine', 'mackerel', 'cod', 'trout',
    'anchovy', 'basa', 'tilapia', 'catla', 'katla', 'surmai', 'kingfish', 'bombay duck', 'bangda',
  ]);
  add('🦐', 'Essentials', ['prawn', 'shrimp', 'jhinga', 'lobster', 'crab', 'seafood', 'squid', 'calamari', 'mussel', 'oyster', 'clam', 'scallop']);

  // Drinks & essentials
  add('🍵', 'Essentials', ['tea', 'chai', 'green tea', 'black tea', 'herbal tea', 'elaichi tea', 'masala chai', 'tea leaves']);
  add('☕', 'Essentials', ['coffee', 'espresso', 'cappuccino', 'latte', 'instant coffee', 'filter coffee', 'coffee powder']);
  add('🧃', 'Essentials', ['juice', 'fruit juice', 'orange juice', 'mango juice', 'apple juice', 'mixed fruit juice']);
  add('🥤', 'Essentials', ['soft drink', 'cola', 'soda', 'pepsi', 'coke', 'sprite', 'energy drink', 'cold drink']);
  add('💧', 'Essentials', ['water', 'pani', 'mineral water', 'bottled water', 'ro water', 'drinking water']);
  add('🧂', 'Essentials', ['salt', 'namak', 'rock salt', 'sendha namak', 'pink salt', 'iodized salt', 'sea salt']);
  add('🍬', 'Essentials', ['sugar', 'cheeni', 'jaggery', 'gur', 'brown sugar', 'candy', 'sweet', 'mishri', 'powdered sugar']);
  add('🛢️', 'Essentials', [
    'oil', 'cooking oil', 'tel', 'mustard oil', 'sunflower oil', 'olive oil', 'coconut oil', 'sesame oil',
    'groundnut oil', 'rice bran oil', 'soybean oil', 'palm oil', 'vegetable oil', 'refined oil',
  ]);
  add('🍯', 'Essentials', ['honey', 'shahad', 'maple syrup', 'golden syrup', 'date syrup']);
  add('🫙', 'Essentials', ['pickle', 'achar', 'jam', 'marmalade', 'spread', 'mayonnaise', 'mayo', 'relish']);
  add('🧴', 'Essentials', [
    'ketchup', 'sauce', 'soy sauce', 'vinegar', 'sirka', 'hot sauce', 'sriracha', 'mustard sauce',
    'tomato sauce', 'chilli sauce', 'schezwan sauce', 'pasta sauce', 'tomato puree', 'tomato paste',
  ]);
  add('🌶️', 'Essentials', [
    'spice mix', 'masala', 'garam masala', 'turmeric', 'haldi', 'cumin', 'jeera', 'coriander powder',
    'dhania powder', 'red chilli powder', 'black pepper', 'cardamom', 'elaichi', 'cinnamon', 'dalchini',
    'clove', 'laung', 'nutmeg', 'jaiphal', 'asafoetida', 'hing', 'fenugreek seed', 'methi seed',
    'mustard seed', 'rai', 'fennel', 'saunf', 'star anise', 'saffron', 'kesar', 'vanilla', 'ajwain',
    'carom seeds', 'nigella', 'kalonji', 'poppy seeds', 'khus khus', 'sesame seeds', 'til',
  ]);
  add('🍲', 'Essentials', ['soup', 'broth', 'stock cube', 'bouillon', 'ready to eat', 'rte meal', 'instant soup']);
  add('🥫', 'Essentials', ['canned', 'tin', 'canned beans', 'canned tomato', 'canned corn', 'canned peas']);
  add('🍿', 'Bakery', ['popcorn', 'nachos', 'chips', 'wafers', 'kurkure', 'namkeen', 'bhujia', 'mixture', 'sev']);
  add('🍫', 'Bakery', ['chocolate', 'cocoa', 'candy bar', 'chocolate spread']);
  add('🍩', 'Bakery', ['donut', 'gulab jamun', 'jalebi', 'ladoo', 'barfi', 'halwa', 'mithai', 'sweet', 'rasgulla', 'rasgula']);
  add('🥟', 'Bakery', ['dumpling', 'momos', 'dim sum', 'samosa', 'kachori', 'pakora', 'vada', 'cutlet', 'spring roll']);
  add('🍕', 'Bakery', ['pizza', 'burger', 'sandwich', 'wrap', 'shawarma', 'sub', 'hot dog']);
  add('🍛', 'Grains', ['curry', 'gravy', 'biryani', 'pulao', 'khichdi', 'fried rice', 'jeera rice', 'lemon rice']);
  add('🍱', 'Essentials', ['meal box', 'tiffin', 'combo pack', 'thali', 'ready meal', 'mess ration']);
  add('📦', 'Essentials', ['general', 'misc', 'miscellaneous', 'supplies', 'provision', 'ration', 'dry ration', 'consumable', 'item', 'product', 'pack', 'grocery', 'provisions']);

  final out = {
    'version': 2,
    'generated': DateTime.now().toIso8601String(),
    'alias_count': lookup.length,
    'entry_count': entryCount,
    'lookup': lookup,
  };

  final file = File('assets/data/food_icon_brain.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
  stdout.writeln('Wrote ${file.path} — ${lookup.length} aliases from $entryCount food groups');
}
