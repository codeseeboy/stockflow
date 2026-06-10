/// Built-in grocery icon + keyword brain used by the emoji picker and
/// auto-matching when admins type a new item name.
/// 300+ entries covering Indian Navy mess supplies, standard groceries,
/// spices, oils, cleaning supplies, beverages, and more.
const kGroceryIconSections = <String, List<List<String>>>{
  // ─── GRAINS & CEREALS ────────────────────────────────────────────────────
  'Grains & Cereals': [
    ['🍚', 'rice basmati chawal sona masoori kolam parboiled raw rice boiled'],
    ['🌾', 'wheat grain atta flour maida wheat flour plain flour'],
    ['🌽', 'corn maize makka cornmeal cornflour corn flour maize flour'],
    ['🥣', 'oats oatmeal dalia porridge broken wheat cereal'],
    ['🍜', 'noodles maggi ramen seviyan vermicelli instant noodles'],
    ['🍝', 'pasta macaroni spaghetti penne fusilli elbow pasta'],
    ['🫘', 'soybean soya bean textured soy protein tsp soya'],
    ['🌱', 'bajra pearl millet jowar sorghum ragi finger millet nachni'],
    ['🍘', 'poha flattened rice beaten rice chivda'],
    ['💎', 'sabudana sago tapioca pearl tapioca sago pearls'],
    ['🥜', 'besan gram flour chickpea flour sattu chana flour'],
    ['🫙', 'suji semolina sooji rava upma rava idli rava'],
    ['🍱', 'quinoa millets foxtail kodo little millet proso millet'],
    ['🌿', 'maize flour cornstarch arrowroot'],
  ],
  // ─── BAKERY & BREADS ─────────────────────────────────────────────────────
  'Bakery & Breads': [
    ['🍞', 'bread loaf sandwich bread white bread brown bread'],
    ['🥖', 'baguette garlic bread french bread long bread'],
    ['🫓', 'roti chapati naan flatbread kulcha phulka tortilla'],
    ['🥐', 'croissant puff pastry danish'],
    ['🥯', 'bagel bread roll pav bun dinner roll'],
    ['🍪', 'biscuit cookie marie biscuit bourbon cream biscuit rusk khari'],
    ['🧇', 'waffle pancake crepe'],
    ['🍰', 'cake sponge cake pound cake fruit cake pastry'],
    ['🥧', 'pie tart quiche pie crust'],
    ['🥞', 'pancake appam idli dosa dosai uttapam'],
    ['🥟', 'samosa kachori pakora vada fritter dumpling momo'],
    ['🍩', 'donut doughnut gulab jamun'],
    ['🍫', 'chocolate cocoa drinking chocolate milo'],
    ['🍿', 'popcorn chips wafers crisps namkeen bhujia mixture'],
  ],
  // ─── PULSES & LEGUMES ────────────────────────────────────────────────────
  'Pulses & Legumes': [
    ['🫘', 'toor dal arhar dal pigeon pea split pigeon pea'],
    ['🟡', 'chana dal split chickpea yellow dal bengal gram split'],
    ['🟢', 'moong dal green gram mung bean moong sabut'],
    ['🔴', 'masoor dal red lentil whole masoor pink lentil split masoor'],
    ['⚫', 'urad dal black gram white urad split urad black urad whole urad'],
    ['🔵', 'rajma kidney beans red kidney beans dark kidney beans'],
    ['🫛', 'kabuli chana chickpeas white chickpeas chole garbanzo'],
    ['🟤', 'lobia black eyed peas cowpea white lobia'],
    ['🌱', 'horse gram kulthi moth bean matki sprouted beans'],
    ['🥜', 'peanut groundnut mungfali roasted peanut peanut butter'],
    ['🌰', 'cashew kaju roasted cashew cashew nut'],
    ['🍂', 'almond badam raw almond roasted almond almond flour'],
    ['🫐', 'walnut akhrot walnuts shelled walnut'],
    ['🍇', 'raisin kishmish sultana dried grape black raisin'],
    ['🍑', 'pistachio pista salted pistachio'],
    ['🟡', 'chestnut dried fruit mixed nuts'],
  ],
  // ─── VEGETABLES ──────────────────────────────────────────────────────────
  'Vegetables': [
    ['🥔', 'potato aloo batata sweet potato shakarkandi yam'],
    ['🧅', 'onion pyaaz shallot pearl onion spring onion green onion scallion'],
    ['🍅', 'tomato tamatar cherry tomato plum tomato sundried tomato'],
    ['🥕', 'carrot gajar baby carrot parsnip'],
    ['🌶️', 'green chilli chilli mirch hari mirch chilli pepper fresh chilli'],
    ['🫑', 'capsicum bell pepper shimla mirch colored pepper red yellow green'],
    ['🥬', 'spinach palak leafy greens methi fenugreek leaves mustard greens'],
    ['🥦', 'broccoli cauliflower gobi phool gobi romanesco'],
    ['🍆', 'brinjal eggplant baingan aubergine'],
    ['🥒', 'cucumber kheera gherkin ridge gourd turai'],
    ['🧄', 'garlic lehsun garlic cloves garlic bulb'],
    ['🫚', 'ginger adrak fresh ginger ginger root'],
    ['🍄', 'mushroom button mushroom oyster mushroom shiitake'],
    ['🫛', 'peas matar green peas frozen peas snow peas'],
    ['🥗', 'cabbage patta gobi red cabbage savoy cabbage'],
    ['🥬', 'lettuce iceberg romaine']  ,
    ['🌿', 'coriander leaves dhania dhaniya fresh coriander cilantro'],
    ['🌿', 'mint pudina fresh mint peppermint spearmint'],
    ['🌿', 'curry leaves kari patta kadhi patta sweet neem'],
    ['🌿', 'celery ajwain leaves parsley dill herb greens'],
    ['🍠', 'taro arbi colocasia yam suran elephant yam'],
    ['🥬', 'ladyfinger okra bhindi ladies finger'],
    ['🥬', 'drumstick moringa sehjan sahjan'],
    ['🥒', 'bottle gourd lauki ghia dudhi zucchini courgette'],
    ['🥒', 'bitter gourd karela ampalaya'],
    ['🥒', 'pumpkin kaddu red pumpkin orange pumpkin'],
    ['🥒', 'ash gourd petha white gourd wax gourd'],
    ['🥒', 'snake gourd parwal tindli pointed gourd ivy gourd'],
    ['🍠', 'beetroot chukandar beet red beet'],
    ['🥬', 'radish mooli daikon white radish'],
    ['🥬', 'turnip shalgam swede'],
    ['🥬', 'artichoke asparagus brussel sprout'],
    ['🫒', 'olive olives green olive black olive'],
    ['🌽', 'baby corn corn on cob sweet corn roasted corn'],
    ['🍠', 'cassava tapioca yuca raw tapioca'],
  ],
  // ─── FRUITS ──────────────────────────────────────────────────────────────
  'Fruits': [
    ['🍎', 'apple seb shimla apple green apple red apple'],
    ['🍌', 'banana kela raw banana plantain'],
    ['🍊', 'orange santra mosambi sweet lime kinnow mandarin tangerine'],
    ['🍋', 'lemon nimbu lime kaffir lime lemon juice'],
    ['🍇', 'grapes angur black grape green grape seedless grape'],
    ['🍉', 'watermelon tarbuj'],
    ['🥭', 'mango aam alphonso hapus kesar totapuri raw mango kacha aam'],
    ['🍍', 'pineapple ananas'],
    ['🍓', 'strawberry'],
    ['🥥', 'coconut nariyal tender coconut desiccated coconut'],
    ['🍐', 'pear nashpati'],
    ['🍑', 'peach apricot khubani plum aloo bukhara'],
    ['🍒', 'cherry sour cherry black cherry'],
    ['🫐', 'blueberry blackberry mulberry jamun'],
    ['🥝', 'kiwi kiwifruit'],
    ['🍈', 'melon muskmelon kharbooja honeydew'],
    ['🍅', 'guava amrud peru'],
    ['🍈', 'papaya papita raw papaya'],
    ['🍈', 'pomegranate anaar anar seeds'],
    ['🥑', 'avocado butter fruit'],
    ['🍈', 'custard apple sitaphal sharifa'],
    ['🍈', 'sapota chikoo sapodilla'],
    ['🍈', 'jackfruit kathal raw jackfruit'],
    ['🍈', 'lychee litchi lichee longan'],
    ['🍋', 'tamarind imli raw tamarind imli paste'],
    ['🍈', 'fig anjeer dried fig fresh fig'],
    ['🍎', 'pear nashpati'],
    ['🍈', 'dates khajoor medjool deglet'],
  ],
  // ─── DAIRY & EGGS ────────────────────────────────────────────────────────
  'Dairy & Eggs': [
    ['🥛', 'milk doodh toned milk full cream homogenised skimmed fortified'],
    ['🍶', 'curd yogurt dahi fresh curd set curd greek yogurt'],
    ['🧀', 'paneer cottage cheese fresh paneer soft paneer'],
    ['🧈', 'butter makhan white butter salted unsalted amul butter'],
    ['🫙', 'ghee clarified butter pure ghee cow ghee desi ghee'],
    ['🥛', 'buttermilk chaas lassi'],
    ['🧀', 'cheese cheddar mozzarella processed cheese cheese slices'],
    ['🥚', 'egg anda eggs dozen eggs tray fresh eggs white eggs brown eggs'],
    ['🍦', 'ice cream kulfi frozen dessert'],
    ['🥛', 'condensed milk khoya mawa evaporated milk'],
    ['🫙', 'cream malai whipping cream fresh cream thick cream'],
    ['🥛', 'milk powder skimmed milk powder full cream powder'],
    ['🫙', 'khoya mawa dried milk solid'],
    ['🫙', 'shrikhand mishti doi rasmalai'],
  ],
  // ─── MEAT & SEAFOOD ──────────────────────────────────────────────────────
  'Meat & Seafood': [
    ['🍗', 'chicken murga whole chicken curry cut broiler chicken'],
    ['🍗', 'chicken breast boneless chicken tender fillet chicken strips'],
    ['🍗', 'chicken leg drumstick chicken thigh wings lollipop'],
    ['🍗', 'chicken keema minced chicken chicken mince'],
    ['🍖', 'mutton goat meat lamb chops mutton keema mince'],
    ['🍖', 'mutton curry cut bone in mutton leg chop'],
    ['🥩', 'beef pork sausage salami ham luncheon meat'],
    ['🐟', 'fish machli fillet fresh fish whole fish'],
    ['🐟', 'rohu fish carp freshwater fish'],
    ['🐟', 'pomfret white pomfret black pomfret silver pomfret'],
    ['🐟', 'salmon tuna mackerel sardine hilsa bangda'],
    ['🐟', 'catfish tilapia basa fillet frozen fish'],
    ['🦐', 'prawn shrimp jhinga tiger prawn king prawn medium prawn'],
    ['🦞', 'lobster crab blue crab mud crab seafood'],
    ['🦑', 'squid calamari cuttlefish octopus'],
    ['🐚', 'mussel oyster clam shellfish'],
  ],
  // ─── SPICES & HERBS ──────────────────────────────────────────────────────
  'Spices & Herbs': [
    ['🌶️', 'red chilli lal mirch chilli powder chilli flakes kashmiri chilli'],
    ['🌿', 'turmeric haldi haldee turmeric powder ground turmeric'],
    ['🌿', 'cumin jeera jeera powder ground cumin cumin seeds roasted jeera'],
    ['🌿', 'coriander dhaniya dhania coriander powder ground coriander'],
    ['🫙', 'garam masala whole spice blend masala powder spice mix'],
    ['🌿', 'black pepper kali mirch pepper powder whole pepper corn'],
    ['🌿', 'cardamom elaichi green cardamom whole elaichi pods'],
    ['🌿', 'cinnamon dalchini stick cinnamon ground cinnamon bark'],
    ['🌿', 'clove laung whole cloves ground clove'],
    ['🌿', 'bay leaf tej patta tejpatta dried bay leaf'],
    ['🌿', 'mustard seed rai sarson black mustard yellow mustard'],
    ['🌿', 'fenugreek seed methi dana methi seeds kasuri methi dried fenugreek'],
    ['🌿', 'fennel saunf sweet fennel anise seed'],
    ['🌿', 'asafoetida hing heeng perungayam'],
    ['🌿', 'star anise chakra phool chinese star anise'],
    ['🌿', 'nutmeg jaiphal mace javitri'],
    ['🌿', 'saffron kesar zafran keshar threads'],
    ['🌿', 'vanilla vanilla essence vanilla extract bean'],
    ['🌿', 'thyme oregano dried herbs mixed herbs italian seasoning'],
    ['🌿', 'peppercorn whole pepper spice black white green pepper'],
    ['🌶️', 'paprika smoked paprika hungarian paprika chilli flakes'],
    ['🌿', 'ajwain carom seeds bishop weed thymol seed'],
    ['🌿', 'amchur dry mango powder amchoor'],
    ['🌿', 'chat masala chaat masala snack spice'],
    ['🌿', 'chole masala pav bhaji masala biryani masala curry powder'],
    ['🫙', 'sambhar masala rasam powder idli podi coconut chutney powder'],
    ['🌿', 'mace javitri whole mace'],
    ['🌿', 'caraway seeds kala jeera shahi jeera black cumin'],
  ],
  // ─── OILS & FATS ─────────────────────────────────────────────────────────
  'Oils & Fats': [
    ['🛢️', 'sunflower oil refined oil cooking oil tel sunflower refined'],
    ['🛢️', 'mustard oil sarson tel kachi ghani mustard cold pressed'],
    ['🛢️', 'groundnut oil peanut oil moongphali tel'],
    ['🛢️', 'coconut oil nariyal tel cold pressed virgin coconut'],
    ['🫒', 'olive oil extra virgin olive refined olive light olive'],
    ['🛢️', 'rice bran oil rice oil fortified rice bran'],
    ['🛢️', 'sesame oil til oil gingelly oil til tel'],
    ['🛢️', 'palm oil vanaspati dalda hydrogenated vegetable fat'],
    ['🧈', 'ghee pure ghee desi ghee cow ghee buffalo ghee'],
    ['🧈', 'butter white butter salted butter'],
    ['🛢️', 'soybean oil soya oil'],
    ['🛢️', 'corn oil blended oil mixed vegetable oil fortified oil'],
  ],
  // ─── CONDIMENTS & SAUCES ─────────────────────────────────────────────────
  'Condiments & Sauces': [
    ['🍯', 'honey shahad pure honey bees honey natural honey'],
    ['🧴', 'tomato ketchup ketchup tomato sauce bottle sauce'],
    ['🧴', 'soy sauce soya sauce dark soy light soy chinese sauce'],
    ['🧴', 'vinegar sirka white vinegar apple cider vinegar malt vinegar'],
    ['🫙', 'pickle achar mango pickle lime pickle mix pickle mixed achar'],
    ['🫙', 'jam strawberry jam mixed fruit jam marmalade preserve'],
    ['🫙', 'chutney pudina chutney tamarind chutney coconut chutney green'],
    ['🧴', 'mayonnaise mayo garlic mayo eggless mayo sandwich spread'],
    ['🧴', 'hot sauce chilli sauce sriracha tabasco'],
    ['🧴', 'worcestershire sauce fish sauce oyster sauce'],
    ['🧴', 'mustard sauce yellow mustard dijon mustard'],
    ['🍋', 'tamarind imli paste extract block'],
    ['🫙', 'tomato paste tomato puree crushed tomato'],
    ['🧴', 'salad dressing ranch caesar vinaigrette'],
    ['🧴', 'hoisin sauce teriyaki sauce marinade'],
    ['🧂', 'baking powder baking soda sodium bicarbonate yeast'],
    ['🧂', 'food colour artificial colour red colour yellow colour'],
    ['🧂', 'citric acid lemon salt tatri'],
  ],
  // ─── BEVERAGES ───────────────────────────────────────────────────────────
  'Beverages': [
    ['🍵', 'tea chai dust tea leaf tea black tea assam tea green tea'],
    ['🍵', 'herbal tea tulsi tea ginger tea lemon tea chamomile'],
    ['☕', 'coffee instant coffee filter coffee espresso chicory'],
    ['🥛', 'bournvita horlicks complan ovaltine health drink malt drink'],
    ['🧃', 'juice fruit juice orange juice mango juice mixed fruit'],
    ['💧', 'water pani mineral water packaged water drinking water'],
    ['🥤', 'soft drink cola soda cold drink pepsi coke sprite lemon'],
    ['🥤', 'energy drink health drink sports drink electrolyte'],
    ['🥥', 'coconut water tender coconut water packaged coconut water'],
    ['🍺', 'beer alcohol spirits liquor'],
    ['🍷', 'wine spirits'],
    ['🧋', 'milk tea bubble tea iced coffee cold coffee'],
    ['🍵', 'tea bags dip tea bag green tea bag masala chai bag'],
    ['☕', 'cocoa cocoa powder drinking chocolate bournvita powder'],
    ['🥛', 'flavoured milk chocolate milk strawberry milk badam milk'],
  ],
  // ─── SNACKS & SWEETS ─────────────────────────────────────────────────────
  'Snacks & Sweets': [
    ['🍬', 'sugar cheeni granulated sugar powdered sugar icing sugar caster'],
    ['🍯', 'jaggery gur gudh dark jaggery palm jaggery coconut jaggery'],
    ['🍭', 'candy toffee caramel sweet lolly'],
    ['🍫', 'chocolate dark chocolate milk chocolate chocolate bar block'],
    ['🍪', 'biscuit cream biscuit marie digestive bourbon glucose parle g'],
    ['🍩', 'halwa sheera sooji halwa gajar halwa moong dal halwa'],
    ['🍮', 'ladoo besan ladoo motichoor boondi ladoo coconut ladoo'],
    ['🍮', 'barfi burfi kaju barfi milk cake kalakand'],
    ['🍮', 'gulab jamun rasgulla rasmalai rasogolla kheer payasam'],
    ['🍮', 'jalebi imarti funnel cake deep fried sweet'],
    ['🥜', 'chikki peanut brittle til chikki groundnut chikki'],
    ['🍿', 'namkeen mixture bhujia sev gathia farsan'],
    ['🍿', 'chips wafers kurkure lays nachos tortilla chips'],
    ['🥟', 'mathri chakli murukku rice cracker savoury cracker'],
    ['🍬', 'mishri rock sugar crystallised sugar candy sugar'],
    ['🎂', 'cake pastry dessert mousse pudding flan'],
  ],
  // ─── CLEANING & HYGIENE ──────────────────────────────────────────────────
  'Cleaning & Hygiene': [
    ['🧼', 'soap bar soap bathing soap toilet soap body wash hand wash'],
    ['🫧', 'detergent washing powder laundry powder surf ariel'],
    ['🫧', 'liquid detergent laundry liquid fabric wash'],
    ['🧴', 'dishwash liquid dishwash gel vim pril washing up liquid'],
    ['🧽', 'scrubber scourer steel wool dish scrub scotch brite'],
    ['🧻', 'tissue toilet paper tissue paper paper towel kitchen roll napkin'],
    ['🧴', 'floor cleaner phenol phenyl floor liquid harpic domex'],
    ['🧴', 'bleach sodium hypochlorite whitener household bleach'],
    ['🧴', 'disinfectant sanitizer surface cleaner dettol lizol'],
    ['🪣', 'bucket mop wiper floor mop cleaning mop'],
    ['🧹', 'broom jhadu dustpan brush sweeping'],
    ['🧴', 'glass cleaner window cleaner colin mirror cleaner'],
    ['🧴', 'toilet cleaner harpic commode cleaner WC cleaner'],
    ['🧴', 'drain cleaner pipe cleaner drano'],
    ['🧴', 'shoe polish shoe cream boot polish'],
    ['🪥', 'toothbrush toothpaste dental floss oral hygiene'],
    ['🧴', 'shampoo conditioner hair oil hair wash'],
    ['🧴', 'mosquito repellent insecticide spray hit lizard repellent'],
    ['🕯️', 'naphthalene balls camphor moth balls'],
  ],
  // ─── ESSENTIALS & MISC ───────────────────────────────────────────────────
  'Essentials': [
    ['🧂', 'salt namak iodised salt sendha rock salt table salt'],
    ['🔥', 'gas lpg cylinder domestic gas fuel cooking gas'],
    ['🧊', 'ice ice cube frozen block ice factory ice'],
    ['🕯️', 'matches matchbox agarbatti incense candle'],
    ['📦', 'general item misc provision ration store supplies'],
    ['🛒', 'dry ration ration kit weekly ration provisions'],
    ['🧺', 'grocery basket fresh produce daily needs'],
    ['📌', 'stationery pen pencil register notebook stationary'],
    ['🪑', 'disposable plate cup glass spoon fork bowl'],
    ['🧴', 'hand sanitizer antiseptic dettol betadine'],
    ['🩺', 'medicine tablet capsule vitamin supplement'],
    ['🔋', 'battery torch lamp bulb electrical'],
    ['🪴', 'plant food fertilizer indoor plant'],
    ['🎁', 'gift packaging wrapping tape box bubble wrap'],
    ['💊', 'vitamin supplement mineral nutritional'],
    ['🌡️', 'thermometer first aid band aid bandage'],
  ],
};

/// Maps catalog section → app [Category] name.
String categoryForIconSection(String section) {
  if (section.startsWith('Grains')) return 'Grains';
  if (section.startsWith('Bakery')) return 'Bakery';
  if (section.startsWith('Pulses')) return 'Pulses';
  if (section.startsWith('Vegetables')) return 'Vegetables';
  if (section.startsWith('Fruits')) return 'Fruits';
  if (section.startsWith('Dairy')) return 'Dairy';
  if (section.startsWith('Meat')) return 'Essentials';
  if (section.startsWith('Spices')) return 'Essentials';
  if (section.startsWith('Oils')) return 'Essentials';
  if (section.startsWith('Condiments')) return 'Essentials';
  if (section.startsWith('Beverages')) return 'Essentials';
  if (section.startsWith('Snacks')) return 'Bakery';
  if (section.startsWith('Cleaning')) return 'Essentials';
  if (section.startsWith('Essentials')) return 'Essentials';
  return 'Essentials';
}

/// Bread/bakery keywords override grains section when present.
String refineCategory(String section, String query) {
  final q = query.toLowerCase();
  if (section.startsWith('Grains') &&
      RegExp(r'\b(bread|pav|bun|croissant|bagel|bakery|rusk|biscuit)\b').hasMatch(q)) {
    return 'Bakery';
  }
  return categoryForIconSection(section);
}

/// Default unit guess from item name + category.
String defaultUnitFor(String name, String category) {
  final q = name.toLowerCase();
  if (RegExp(r'\b(egg|anda)\b').hasMatch(q)) return 'dozen';
  if (RegExp(r'\b(bread|packet|biscuit|maggi|noodle|tissue|soap|detergent|match|candle|incense)\b').hasMatch(q)) return 'packet';
  if (RegExp(r'\b(milk|oil|water|juice|doodh|tel|litre|ltr|ghee|butter|cream|lassi|chaas)\b').hasMatch(q)) return 'litre';
  if (RegExp(r'\b(gas|cylinder|lpg)\b').hasMatch(q)) return 'piece';
  if (RegExp(r'\b(piece|pieces|pcs|nos|number|unit|each|count)\b').hasMatch(q)) return 'piece';
  if (category == 'Dairy' && RegExp(r'\b(milk|curd|dahi)\b').hasMatch(q)) return 'litre';
  return 'kg';
}

/// Flat list of every emoji + keyword string in the built-in brain.
List<({String emoji, String keywords, String section})> get allGroceryIcons {
  final out = <({String emoji, String keywords, String section})>[];
  for (final e in kGroceryIconSections.entries) {
    for (final row in e.value) {
      out.add((emoji: row[0], keywords: row[1], section: e.key));
    }
  }
  return out;
}
