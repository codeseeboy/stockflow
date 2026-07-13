import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../data/rik_entitlement.dart';
import '../theme/app_theme.dart';

export '../data/rik_entitlement.dart';

enum UserRole { admin, worker, customer }

enum StockStatus { inStock, low, out }

enum OrderStatus { pending, confirmed, fulfilled, cancelled }

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

/// A ration entitlement tier ("zone"). Models the Indian-Navy ration system:
/// each zone has its own criteria — a master ration cap, a cap per food
/// category, and optional per-item maximums. The customer never sees stock;
/// these limits (not availability) govern how much they may order.
class RationZone {
  final String name; // 'High Level' / 'Medium Level' / 'Low Level'
  final String level; // short badge label
  final double masterLimit; // total ration points across all categories
  final Map<String, double> categoryLimits; // per-category cap
  final Map<String, double> itemMax; // optional per-item cap, by item name
  final double defaultCategoryLimit;

  const RationZone({
    required this.name,
    required this.level,
    required this.masterLimit,
    this.categoryLimits = const {},
    this.itemMax = const {},
    this.defaultCategoryLimit = 8,
  });

  double categoryLimit(String category) => categoryLimits[category] ?? defaultCategoryLimit;
  double maxForItem(String itemName) => itemMax[itemName] ?? double.infinity;
}

double _rikCap(double perDay) => double.parse((perDay * kRationPeriodDays).toStringAsFixed(3));

final Map<String, double> _officersCategoryLimits = {
  for (final c in kRikOfficers) c.name: _rikCap(c.perDay),
};

/// The Officers ration scale, derived from the real RIK per-day entitlement
/// × the ordering period (a week). Category caps and the master total come
/// straight from the sheet; admins can still tune them per zone in the store.
final RationZone _officersZone = RationZone(
  name: 'Officers',
  level: 'Officers',
  masterLimit: _officersCategoryLimits.values.fold(0.0, (s, v) => s + v),
  categoryLimits: _officersCategoryLimits,
  itemMax: const {},
);

/// Ration scales by personnel category. Currently only the real Officers sheet
/// is loaded; more (Sailors, etc.) can be added as their scales arrive.
final List<RationZone> kRationZones = [_officersZone];

final List<String> kZoneNames = [for (final z in kRationZones) z.name];

/// Resolve a scale by name (case-insensitive); falls back to the first (Officers).
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

  OrderCycle({
    required this.id,
    required this.title,
    required this.weekStart,
    required this.weekEnd,
    required this.status,
    required this.shareToken,
    this.designation = '',
  });

  /// True when this window is open to everyone (no designation restriction).
  bool get isPublic => designation.trim().isEmpty;

  String get link => '${SupabaseConfig.publicWebBase}/c/$shareToken';
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

  Order({
    required this.id,
    required this.cycleId,
    required this.customerName,
    required this.customerPhone,
    required this.lines,
    required this.status,
    required this.createdAt,
  });

  int get itemCount => lines.length;
  double get totalUnits => lines.fold(0.0, (s, l) => s + l.qty);

  Map<String, dynamic> toJson() => {
        'id': id,
        'cycleId': cycleId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'lines': lines.map((l) => l.toJson()).toList(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
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
