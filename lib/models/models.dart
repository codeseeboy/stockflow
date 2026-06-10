import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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

const kCategories = <Category>[
  Category('Grains', Icons.grain_rounded, AppColors.cGrains),
  Category('Pulses', Icons.spa_rounded, AppColors.cPulses),
  Category('Vegetables', Icons.eco_rounded, AppColors.cVeg),
  Category('Fruits', Icons.apple_rounded, AppColors.cFruits),
  Category('Dairy', Icons.egg_alt_rounded, AppColors.cDairy),
  Category('Bakery', Icons.bakery_dining_rounded, AppColors.cBakery),
  Category('Essentials', Icons.local_grocery_store_rounded, AppColors.cEssentials),
];

Category categoryOf(String name) =>
    kCategories.firstWhere((c) => c.name == name, orElse: () => kCategories.last);

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
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    required this.unit,
    this.email = '',
  });
}

class OrderCycle {
  final String id;
  final String title;
  final DateTime weekStart;
  final DateTime weekEnd;
  CycleStatus status;
  final String shareToken;

  OrderCycle({
    required this.id,
    required this.title,
    required this.weekStart,
    required this.weekEnd,
    required this.status,
    required this.shareToken,
  });

  String get link => 'https://order.stockflow.app/c/$shareToken';
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
