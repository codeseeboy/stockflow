import 'dart:convert';

import '../data/app_store.dart';
import '../models/models.dart';
import 'app_prefs.dart';

String normCustomerPhone(String phone) => phone.replaceAll(RegExp(r'\D'), '');

/// True when [o] belongs to the customer identified by [name] / [phone].
bool orderBelongsToCustomer(Order o, String name, String phone) {
  if (o.customerName.trim().toLowerCase() == name.trim().toLowerCase()) return true;
  final np = normCustomerPhone(phone);
  if (np.length < 6) return false;
  return normCustomerPhone(o.customerPhone) == np;
}

/// All orders for this customer — in-memory store + on-device cache, deduped.
List<Order> customerOrdersFor(AppStore store, String name, String phone) {
  final seen = <String>{};
  final list = <Order>[];

  void add(Order o) {
    if (seen.add(o.id)) list.add(o);
  }

  for (final o in store.orders) {
    if (orderBelongsToCustomer(o, name, phone)) add(o);
  }
  for (final o in SavedCustomerOrders.load(name, phone)) {
    add(o);
  }

  list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return list;
}

/// Persists customer orders on-device so history survives reload / RLS gaps.
class SavedCustomerOrders {
  SavedCustomerOrders._();

  static const _key = 'customer_order_history';

  static String _storageKey(String name, String phone) {
    final np = normCustomerPhone(phone);
    if (np.length >= 6) return 'p:$np';
    return 'n:${name.trim().toLowerCase()}';
  }

  static void upsert(String name, String phone, Order order) {
    final key = _storageKey(name, phone);
    final all = _readAll();
    final list = (all[key] ?? const <Map<String, dynamic>>[])
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
        .where((o) => o.id != order.id)
        .toList()
      ..insert(0, order);
    if (list.length > 100) list.removeRange(100, list.length);
    all[key] = list.map((o) => o.toJson()).toList();
    _writeAll(all);
  }

  static List<Order> load(String name, String phone) {
    final key = _storageKey(name, phone);
    final raw = _readAll()[key] ?? const <Map<String, dynamic>>[];
    return raw
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
        .where((o) => orderBelongsToCustomer(o, name, phone))
        .toList();
  }

  static Map<String, List<Map<String, dynamic>>> _readAll() {
    final raw = AppPrefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(
            k,
            (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          ));
    } catch (_) {
      return {};
    }
  }

  static void _writeAll(Map<String, List<Map<String, dynamic>>> data) {
    AppPrefs.setString(_key, jsonEncode(data));
  }
}
