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

/// Fingerprint of what an order contains — used to spot the same order twice
/// (the local pre-sync copy vs the synced server row).
String _orderSignature(Order o) {
  final lines = o.lines.map((l) => '${l.name.toLowerCase()}:${l.qty}').toList()..sort();
  return '${o.cycleId}|${lines.join(',')}';
}

/// All orders for this customer — in-memory store + on-device cache, deduped
/// and pruned. The cache can hold junk (test orders from an old install
/// restored by Android backup, or a local copy whose synced twin arrived), and
/// junk here poisons everything downstream: duplicate rows in My Orders and a
/// wrongly-consumed balance. So:
///  * live mode: a cached order must reference a demand the server knows,
///    or already exist in the store — anything else is stale and is dropped;
///  * when a local `ORD-…` copy and a synced copy have identical content in
///    the same demand, only the synced one survives.
List<Order> customerOrdersFor(AppStore store, String name, String phone) {
  final seen = <String>{};
  final list = <Order>[];

  void add(Order o) {
    if (seen.add(o.id)) list.add(o);
  }

  for (final o in store.orders) {
    if (orderBelongsToCustomer(o, name, phone)) add(o);
  }

  final knownCycles = store.cycles.map((c) => c.id).toSet();
  for (final o in SavedCustomerOrders.load(name, phone)) {
    if (store.isLive && !knownCycles.contains(o.cycleId) && !seen.contains(o.id)) {
      continue; // stale cache from an old install / demo run
    }
    add(o);
  }

  // Same content, same demand → keep the synced row, drop the local copy.
  final syncedSignatures = <String>{
    for (final o in list)
      if (!o.id.startsWith('ORD-')) _orderSignature(o),
  };
  list.removeWhere((o) => o.id.startsWith('ORD-') && syncedSignatures.contains(_orderSignature(o)));

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

  /// Drop one cached order — used to retire the local `ORD-…` copy once its
  /// synced twin has been stored, so the pair never shows as two orders.
  static void remove(String name, String phone, String orderId) {
    final key = _storageKey(name, phone);
    final all = _readAll();
    final list = all[key];
    if (list == null) return;
    list.removeWhere((e) => (e['id'] as String?) == orderId);
    all[key] = list;
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
