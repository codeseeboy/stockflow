import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../data/entitlement.dart';
import '../data/rik_entitlement.dart';
import '../theme/app_theme.dart';

export '../data/entitlement.dart';
export '../data/rik_entitlement.dart';

enum UserRole { admin, worker, customer }

enum StockStatus { inStock, low, out }

/// The order's lifecycle. `pending` is where every demand starts (created and
/// submitted by the customer in the same action); everything after that is an
/// admin action, tracked with who and when in [OrderStatusEvent].
enum OrderStatus { pending, viewed, accepted, rejected, processing, fulfilled, cancelled }

/// One step in an order's timeline: what it became, when, and who did it —
/// so a customer can always see where their demand stands without asking.
class OrderStatusEvent {
  final OrderStatus status;
  final DateTime at;
  final String by;
  const OrderStatusEvent({required this.status, required this.at, required this.by});

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'at': at.toIso8601String(),
        'by': by,
      };

  factory OrderStatusEvent.fromJson(Map<String, dynamic> j) => OrderStatusEvent(
        status: OrderStatus.values.byName((j['status'] as String?) ?? 'pending'),
        at: DateTime.tryParse(j['at']?.toString() ?? '') ?? DateTime.now(),
        by: (j['by'] as String?) ?? '',
      );
}

enum CycleStatus { draft, open, closed }

/// A product category with its own icon + accent colour.
class Category {
  final String name;
  final IconData icon;
  final Color color;
  const Category(this.name, this.icon, this.color);
}

const _catPalette = <Color>[
  AppColors.cGrains, AppColors.cPulses, AppColors.cVeg, AppColors.cFruits,
  AppColors.cDairy, AppColors.cBakery, AppColors.cEssentials, AppColors.brand,
  AppColors.accent, AppColors.warning,
];

IconData _rikIcon(String name) {
  switch (name) {
    case 'Cereals':
      return Icons.grain_rounded;
    case 'Dal':
      return Icons.spa_rounded;
    case 'Refined Oil':
      return Icons.water_drop_rounded;
    case 'Sugar':
      return Icons.cookie_rounded;
    case 'Milk':
      return Icons.local_drink_rounded;
    case 'Meat':
      return Icons.set_meal_rounded;
    case 'Vegetables':
      return Icons.eco_rounded;
    case 'Potato':
    case 'Onion':
      return Icons.spa_outlined;
    case 'Eggs':
      return Icons.egg_rounded;
    case 'Tea/Coffee':
      return Icons.coffee_rounded;
    case 'Fruit':
      return Icons.apple_rounded;
    case 'Dalia':
      return Icons.rice_bowl_rounded;
    case 'Butter':
      return Icons.breakfast_dining_rounded;
    case 'Condiments':
      return Icons.local_fire_department_rounded;
    case 'Salt':
      return Icons.grain_outlined;
    case 'LPG':
      return Icons.propane_tank_rounded;
    default:
      return Icons.restaurant_rounded;
  }
}

/// Categories are the 17 real RIK entitlement categories (from [kRikOfficers]).
final List<Category> kCategories = [
  for (var i = 0; i < kRikOfficers.length; i++)
    Category(kRikOfficers[i].name, _rikIcon(kRikOfficers[i].name), _catPalette[i % _catPalette.length]),
];

Category categoryOf(String name) =>
    kCategories.firstWhere((c) => c.name == name, orElse: () => kCategories.last);

/// A ration entitlement scale — a "zone", which the unit treats as a
/// **designation** (Officers, Commanders, …). Each zone carries its own
/// criteria, so Zone A and Zone B differ in entitlement.
///
/// The scale is held as a **per-day rate per category** — the form the RIK
/// sheet actually comes in — because every allowance in the system is
/// `perDay × days`: a month's allowance uses the days in the month, and a
/// demand's own span (5 / 10 / 15 / 30 days, from the unit's Excel) uses its
/// own day count. The customer never sees stock; these rates, not availability,
/// govern how much they may order.
class RationZone {
  final String name; // 'Officers', 'Commanders', …
  final String level; // short badge label
  final Map<String, double> perDay; // entitlement per person per DAY, by category
  final Map<String, double> itemMax; // optional per-item cap, by item name
  final double defaultPerDay;

  const RationZone({
    required this.name,
    required this.level,
    this.perDay = const {},
    this.itemMax = const {},
    this.defaultPerDay = 0.05,
  });

  /// Entitlement per person per day for a category.
  double perDayFor(String category) => perDay[category] ?? defaultPerDay;

  /// Entitlement for a span of [days] — e.g. a 10-day fresh demand.
  double allowanceFor(String category, int days) => perDayFor(category) * days;

  /// The month's entitlement for a category (per-day × days in that month).
  /// This is the figure the customer's balance is measured against.
  double monthlyAllowance(String category, RationMonth month) =>
      allowanceFor(category, month.days);

  /// Total entitlement across all categories for a month — informational only
  /// (the enforced cap is per category, as the unit specified).
  double monthlyTotal(RationMonth month) =>
      kCategories.fold(0.0, (s, c) => s + monthlyAllowance(c.name, month));

  double maxForItem(String itemName) => itemMax[itemName] ?? double.infinity;

  RationZone copyWith({String? name, String? level, Map<String, double>? perDay, Map<String, double>? itemMax}) =>
      RationZone(
        name: name ?? this.name,
        level: level ?? this.level,
        perDay: perDay ?? this.perDay,
        itemMax: itemMax ?? this.itemMax,
        defaultPerDay: defaultPerDay,
      );
}

/// The real Officers per-day scale, straight from the RIK sheet.
final Map<String, double> kOfficersPerDay = {
  for (final c in kRikOfficers) c.name: c.perDay,
};

/// The Officers ration scale — the one real sheet the unit has given us so far.
/// Further zones (Sailors, Commanders, …) are created by the admin and filled
/// in from their own Excel, rather than being invented here.
final RationZone kOfficersZone = RationZone(
  name: 'Officers',
  level: 'Officers',
  perDay: kOfficersPerDay,
  itemMax: const {},
);

/// Ration scales shipped with the app. Admins can add more at runtime.
final List<RationZone> kRationZones = [kOfficersZone];

final List<String> kZoneNames = [for (final z in kRationZones) z.name];

/// Resolve a built-in scale by name (case-insensitive); falls back to Officers.
RationZone rationZoneFor(String name) {
  final n = name.trim().toLowerCase();
  return kRationZones.firstWhere(
    (z) => z.name.toLowerCase() == n,
    orElse: () => kRationZones.first,
  );
}

/// A stock item (also carries its own live quantity for this prototype).
class Item {
  final String id;
  String name;
  String emoji;
  String category;
  String unit; // kg, litre, dozen, packet, piece
  double openingQty;
  double currentQty;
  double reorderLevel;

  Item({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.unit,
    required this.openingQty,
    required this.currentQty,
    required this.reorderLevel,
  });

  StockStatus get status {
    if (currentQty <= 0) return StockStatus.out;
    if (currentQty <= reorderLevel) return StockStatus.low;
    return StockStatus.inStock;
  }

  /// 0..1 of opening stock remaining.
  double get fraction {
    if (openingQty <= 0) return 0;
    return (currentQty / openingQty).clamp(0, 1);
  }

  Category get cat => categoryOf(category);
}

class AppUser {
  final String id;
  final String name;
  final UserRole role;
  final String phone;
  final String unit;
  final String email;
  final String zone; // ration zone for customers ('' for staff/admin)
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    required this.unit,
    this.email = '',
    this.zone = '',
  });
}

/// A demand window — what the unit calls "opening the demand".
///
/// The unit raises three **fresh** demands a month (~10 days each) and one
/// **dry** demand covering the whole month. Every demand in a month draws from
/// that month's entitlement balance, which is why [month] matters: bread taken
/// on a fresh demand is spent out of the same Cereals balance the dry demand
/// later draws on.
class OrderCycle {
  final String id;
  final String title;
  final DateTime weekStart;
  final DateTime weekEnd;
  CycleStatus status;
  final String shareToken;

  /// Free-text audience for this link. Empty = open to everyone; otherwise only
  /// customers whose designation matches (e.g. 'Officers', 'Sailors Mess A')
  /// can see and use this window.
  final String designation;

  /// Fresh ration or dry ration — decides which articles can appear at all.
  final DemandType type;

  /// How many days this demand covers (5 / 10 / 15 / 30 — from the unit's Excel).
  /// Informational for the customer: the enforced cap is the month's balance.
  final int days;

  /// The entitlement month this demand spends from.
  final RationMonth month;

  /// The varieties the admin added to this demand. Empty = every article valid
  /// for [type]. The customer only ever sees what's in here — "if I am not
  /// adding it, the customer will not see it".
  final Set<String> itemIds;

  OrderCycle({
    required this.id,
    required this.title,
    required this.weekStart,
    required this.weekEnd,
    required this.status,
    required this.shareToken,
    this.designation = '',
    this.type = DemandType.fresh,
    int? days,
    RationMonth? month,
    Set<String>? itemIds,
  })  : days = days ?? type.defaultDays,
        month = month ?? RationMonth.of(weekStart),
        itemIds = itemIds ?? const {};

  /// True when this window is open to everyone (no designation restriction).
  bool get isPublic => designation.trim().isEmpty;

  /// True when the admin has hand-picked the varieties on this demand.
  bool get hasCuratedList => itemIds.isNotEmpty;

  /// Whether an article appears on this demand list: it must be valid for the
  /// demand's ration type, and — once the admin has curated the list — be one
  /// of the varieties they added.
  bool includes(Item item) {
    if (!itemAllowedIn(type, item.category, item.name)) return false;
    return itemIds.isEmpty || itemIds.contains(item.id);
  }

  String get link => '${SupabaseConfig.publicWebBase}/c/$shareToken';

  OrderCycle copyWith({String? title, CycleStatus? status, DemandType? type, int? days, RationMonth? month, Set<String>? itemIds}) =>
      OrderCycle(
        id: id,
        title: title ?? this.title,
        weekStart: weekStart,
        weekEnd: weekEnd,
        status: status ?? this.status,
        shareToken: shareToken,
        designation: designation,
        type: type ?? this.type,
        days: days ?? this.days,
        month: month ?? this.month,
        itemIds: itemIds ?? this.itemIds,
      );
}

class OrderLine {
  final String itemId;
  final String name;
  final String emoji;
  final String unit;
  final double qty;
  const OrderLine({
    required this.itemId,
    required this.name,
    required this.emoji,
    required this.unit,
    required this.qty,
  });

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'name': name,
        'emoji': emoji,
        'unit': unit,
        'qty': qty,
      };

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        itemId: (j['itemId'] as String?) ?? '',
        name: (j['name'] as String?) ?? 'Item',
        emoji: (j['emoji'] as String?) ?? '📦',
        unit: (j['unit'] as String?) ?? '',
        qty: (j['qty'] as num?)?.toDouble() ?? 0,
      );
}

class Order {
  final String id;
  final String cycleId;
  final String customerName;
  final String customerPhone;
  final List<OrderLine> lines;
  OrderStatus status;
  final DateTime createdAt;

  /// Server-assigned running number → the human-readable `SF-101` code.
  final int? orderNo;

  /// Every status this order has passed through, with who and when. Always
  /// has at least the "submitted" event — see [timeline].
  final List<OrderStatusEvent> history;

  Order({
    required this.id,
    required this.cycleId,
    required this.customerName,
    required this.customerPhone,
    required this.lines,
    required this.status,
    required this.createdAt,
    this.orderNo,
    this.history = const [],
  });

  int get itemCount => lines.length;
  double get totalUnits => lines.fold(0.0, (s, l) => s + l.qty);

  /// Short, readable order code — never the raw UUID.
  String get displayId {
    if (orderNo != null) return 'SF-$orderNo';
    if (id.startsWith('ORD-')) return id.replaceFirst('ORD-', 'SF-');
    final tail = id.replaceAll('-', '');
    return 'SF-${tail.substring(0, tail.length < 4 ? tail.length : 4).toUpperCase()}';
  }

  /// The full timeline, guaranteed to start with the submission event even
  /// for orders synced before status history existed.
  List<OrderStatusEvent> get timeline {
    if (history.isNotEmpty) return history;
    return [OrderStatusEvent(status: OrderStatus.pending, at: createdAt, by: customerName)];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cycleId': cycleId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'lines': lines.map((l) => l.toJson()).toList(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        if (orderNo != null) 'orderNo': orderNo,
        'history': history.map((h) => h.toJson()).toList(),
      };

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: (j['id'] as String?) ?? '',
        cycleId: (j['cycleId'] as String?) ?? '',
        customerName: (j['customerName'] as String?) ?? '',
        customerPhone: (j['customerPhone'] as String?) ?? '',
        lines: ((j['lines'] as List?) ?? const [])
            .map((e) => OrderLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        status: OrderStatus.values.byName((j['status'] as String?) ?? 'pending'),
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
        orderNo: (j['orderNo'] as num?)?.toInt(),
        history: ((j['history'] as List?) ?? const [])
            .map((e) => OrderStatusEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Admin → customer broadcast (in-app, SMS, WhatsApp).
class CustomerBroadcast {
  final String id;
  final String title;
  final String body;
  final DateTime sentAt;
  final bool inApp;
  final bool sms;
  final bool whatsapp;
  final int recipientCount;
  final String? itemEmoji;

  const CustomerBroadcast({
    required this.id,
    required this.title,
    required this.body,
    required this.sentAt,
    required this.inApp,
    required this.sms,
    required this.whatsapp,
    required this.recipientCount,
    this.itemEmoji,
  });
}

/// Per-customer delivery status (SMS / WhatsApp / email / in-app).
class DeliveryLogEntry {
  final String customerName;
  final String phone;
  final String email;
  final bool inAppDelivered;
  final bool smsDelivered;
  final bool whatsappDelivered;
  final bool emailDelivered;

  const DeliveryLogEntry({
    required this.customerName,
    required this.phone,
    required this.inAppDelivered,
    required this.smsDelivered,
    required this.whatsappDelivered,
    this.email = '',
    this.emailDelivered = false,
  });
}

/// Result summary after sending a customer broadcast.
class BroadcastResult {
  final int inAppCount;
  final int smsCount;
  final int whatsappCount;
  final int emailCount;
  final bool autoEmailed; // true when emails were sent server-side automatically
  final List<DeliveryLogEntry> logs;

  const BroadcastResult({
    required this.inAppCount,
    required this.smsCount,
    required this.whatsappCount,
    this.emailCount = 0,
    this.autoEmailed = false,
    this.logs = const [],
  });

  int get total => inAppCount + smsCount + whatsappCount + emailCount;
}

/// In-app notification / alert (low stock, new order, etc.)
class Alert {
  final String id;
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final DateTime time;
  const Alert({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.time,
  });
}
