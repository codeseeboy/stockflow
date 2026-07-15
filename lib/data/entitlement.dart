/// Entitlement domain — the rules the unit gave us in the 13 Jul 2026 meeting.
///
/// The customer never sees warehouse stock. What they see, and what caps their
/// order, is their own **entitlement balance** for the month:
///
///     balance(category) = allowance + carriedIn − consumed
///
/// * `allowance` — the month's entitlement: RIK per-day rate × days in the month.
/// * `carriedIn` — whatever was left over at the end of last month (a leftover
///   100 kg is added on top of the new month's allowance: 500 + 300 = 800).
/// * `consumed` — everything already ordered in that month, across *every*
///   demand in it. Because the balance is held per category, bread taken in a
///   fresh demand comes straight out of the same Cereals balance the dry demand
///   draws on — the "carry-forward within the month" the unit asked for.
///
/// Pure data — no Flutter imports — so it can be shared everywhere.
library;

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// The month an entitlement belongs to. Demands draw from the month's balance,
/// so every demand in June spends the same June allowance.
class RationMonth implements Comparable<RationMonth> {
  final int year;
  final int month; // 1..12

  const RationMonth(this.year, this.month);

  factory RationMonth.of(DateTime d) => RationMonth(d.year, d.month);

  /// Parses `2026-06`. Returns null when the text isn't a month key.
  static RationMonth? tryParse(String s) {
    final m = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(s.trim());
    if (m == null) return null;
    final mm = int.parse(m.group(2)!);
    if (mm < 1 || mm > 12) return null;
    return RationMonth(int.parse(m.group(1)!), mm);
  }

  /// Days in this month — the multiplier for the month's allowance.
  int get days => DateTime(year, month + 1, 0).day;

  RationMonth get previous => month == 1 ? RationMonth(year - 1, 12) : RationMonth(year, month - 1);
  RationMonth get next => month == 12 ? RationMonth(year + 1, 1) : RationMonth(year, month + 1);

  DateTime get firstDay => DateTime(year, month, 1);
  DateTime get lastDay => DateTime(year, month, days);

  /// Stable key for storage / maps: `2026-06`.
  String get key => '$year-${month.toString().padLeft(2, '0')}';

  /// Human label: `June 2026`.
  String get label => '${_monthNames[month - 1]} $year';

  /// Short label: `Jun 2026`.
  String get shortLabel => '${_monthNames[month - 1].substring(0, 3)} $year';

  bool isBefore(RationMonth o) => compareTo(o) < 0;
  bool isAfter(RationMonth o) => compareTo(o) > 0;

  /// Whole months from this to [o] (negative when [o] is earlier).
  int monthsTo(RationMonth o) => (o.year - year) * 12 + (o.month - month);

  @override
  int compareTo(RationMonth o) => year != o.year ? year.compareTo(o.year) : month.compareTo(o.month);

  @override
  bool operator ==(Object other) => other is RationMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => key;
}

/// Which ration a demand is for. The unit raises three **fresh** demands in a
/// month (~10 days each) and one **dry** demand covering the whole month.
enum DemandType { fresh, dry }

extension DemandTypeX on DemandType {
  String get label => this == DemandType.fresh ? 'Fresh' : 'Dry';

  /// The default span the unit described: fresh ≈ 10 days, dry = the month.
  int get defaultDays => this == DemandType.fresh ? 10 : 30;

  String get blurb => this == DemandType.fresh
      ? 'Chicken, mutton, vegetables, fruit, onion, potato, butter, eggs, milk — and bread.'
      : 'Atta, rice, dal, oil, sugar, condiments — and bread.';
}

/// Whether an article belongs to the fresh demand, the dry demand, or both.
/// Bread is the one that sits in **both**: it can be taken with the fresh ration
/// and again on the dry ration list — and either way it comes out of Cereals.
enum RationKind { fresh, dry, both }

/// RIK categories that are fresh by nature.
const _freshCategories = <String>{
  'Meat', 'Vegetables', 'Fruit', 'Potato', 'Onion', 'Butter', 'Eggs', 'Milk',
};

bool _isBread(String itemName) {
  final n = itemName.toLowerCase();
  return n.contains('bread') || n.contains('pav bun');
}

/// Fresh, dry, or both — for an article in a RIK category.
///
/// Cereals is the interesting one: atta / rice / millets are dry, but the bread
/// inside Cereals is available on *both* lists.
RationKind rationKindOf(String category, String itemName) {
  if (_isBread(itemName)) return RationKind.both;
  if (_freshCategories.contains(category)) return RationKind.fresh;
  return RationKind.dry;
}

/// True when an article may appear on a [type] demand list.
bool itemAllowedIn(DemandType type, String category, String itemName) {
  return switch (rationKindOf(category, itemName)) {
    RationKind.both => true,
    RationKind.fresh => type == DemandType.fresh,
    RationKind.dry => type == DemandType.dry,
  };
}

/// One category's entitlement position for a customer in a month. This — not
/// warehouse stock — is what the customer sees and what caps their order.
class CategoryBalance {
  final String category;
  final String unit;

  /// This month's entitlement: per-day rate × days in the month.
  final double allowance;

  /// Left over at the end of last month, added on top (500 + 300 = 800).
  final double carriedIn;

  /// Already ordered this month, across every demand in it.
  final double consumed;

  const CategoryBalance({
    required this.category,
    required this.unit,
    required this.allowance,
    required this.carriedIn,
    required this.consumed,
  });

  /// Everything the customer may take this month.
  double get total => allowance + carriedIn;

  /// What is still due to them — never negative.
  double get remaining {
    final r = total - consumed;
    return r < 0 ? 0 : r;
  }

  /// 0..1 of the month's entitlement used.
  double get usedFraction => total <= 0 ? 0 : (consumed / total).clamp(0.0, 1.0);

  bool get isExhausted => remaining <= 1e-9;
}
