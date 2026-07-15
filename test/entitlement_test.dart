import 'package:flutter_test/flutter_test.dart';

import 'package:stockflow/data/app_store.dart';
import 'package:stockflow/models/models.dart';

/// These tests pin down the entitlement rules from the 13 Jul 2026 meeting:
/// balance = allowance + carry-in − consumed, carry-forward within the month
/// and to the next month, and the fresh/dry demand rules.
void main() {
  group('RationMonth', () {
    test('days, previous/next, and parsing', () {
      const june = RationMonth(2026, 6);
      expect(june.days, 30);
      expect(june.previous, const RationMonth(2026, 5));
      expect(june.next, const RationMonth(2026, 7));
      expect(RationMonth.tryParse('2026-06'), june);
      expect(const RationMonth(2026, 1).previous, const RationMonth(2025, 12));
      expect(const RationMonth(2026, 12).next, const RationMonth(2027, 1));
      expect(RationMonth.tryParse('nonsense'), isNull);
    });

    test('February leap vs non-leap', () {
      expect(const RationMonth(2024, 2).days, 29);
      expect(const RationMonth(2026, 2).days, 28);
    });
  });

  group('fresh vs dry classification', () {
    test('bread is on both lists; atta is dry; meat is fresh', () {
      expect(rationKindOf('Cereals', 'Brown Bread 400 g'), RationKind.both);
      expect(rationKindOf('Cereals', 'Atta 1 kg'), RationKind.dry);
      expect(rationKindOf('Meat', 'Meat Fresh 1 kg'), RationKind.fresh);

      // Bread shows up whether the demand is fresh or dry.
      expect(itemAllowedIn(DemandType.fresh, 'Cereals', 'Brown Bread 400 g'), isTrue);
      expect(itemAllowedIn(DemandType.dry, 'Cereals', 'Brown Bread 400 g'), isTrue);
      // Atta only on dry; meat only on fresh.
      expect(itemAllowedIn(DemandType.fresh, 'Cereals', 'Atta 1 kg'), isFalse);
      expect(itemAllowedIn(DemandType.dry, 'Cereals', 'Atta 1 kg'), isTrue);
      expect(itemAllowedIn(DemandType.dry, 'Meat', 'Meat Fresh 1 kg'), isFalse);
      expect(itemAllowedIn(DemandType.fresh, 'Meat', 'Meat Fresh 1 kg'), isTrue);
    });
  });

  group('CategoryBalance', () {
    test('remaining = allowance + carriedIn − consumed, floored at 0', () {
      const b = CategoryBalance(category: 'Cereals', unit: 'kg', allowance: 500, carriedIn: 300, consumed: 200);
      expect(b.total, 800); // the unit's 500 + 300 = 800 example
      expect(b.remaining, 600);

      const over = CategoryBalance(category: 'Cereals', unit: 'kg', allowance: 100, carriedIn: 0, consumed: 250);
      expect(over.remaining, 0); // never negative
      expect(over.isExhausted, isTrue);
    });
  });

  group('AppStore entitlement ledger', () {
    // Build a controlled store: no Supabase, a single zone with round per-day
    // rates so the month math is easy to read.
    late AppStore store;
    late RationMonth month;
    late String cerealsItemId;

    setUp(() {
      store = AppStore()..seedDemoData();
      month = store.currentMonth;
      // 1 kg/day of Cereals → allowance = days-in-month kg. Clear the rest so
      // only Cereals has an allowance and the totals are unambiguous.
      for (final c in kCategories) {
        store.setZonePerDay('Officers', c.name, c.name == 'Cereals' ? 1.0 : 0.0);
      }
      cerealsItemId = store.items.firstWhere((i) => i.category == 'Cereals').id;
    });

    test('a customer who ordered nothing sees the full allowance', () {
      final bal = store.balanceOf(
        name: 'Nobody', phone: '+91 90000 00000', zone: 'Officers', category: 'Cereals', month: month,
      );
      expect(bal.allowance, month.days.toDouble());
      expect(bal.consumed, 0);
      expect(bal.remaining, month.days.toDouble());
    });

    test('ordering in a fresh demand reduces the same month balance (within-month carry-forward)', () {
      final fresh = store.openNewCycle(
        designation: 'Officers', type: DemandType.fresh, month: month, itemIds: {cerealsItemId},
      );
      store.placeOrder(
        customerName: 'Cdr A', customerPhone: '+91 90000 12345',
        cart: {cerealsItemId: 4}, cycleId: fresh.id, zone: 'Officers',
      );

      final bal = store.balanceOf(
        name: 'Cdr A', phone: '+91 90000 12345', zone: 'Officers', category: 'Cereals', month: month,
      );
      // Bread taken on the fresh demand comes out of the shared Cereals balance.
      expect(bal.consumed, 4);
      expect(bal.remaining, month.days.toDouble() - 4);
    });

    test('an order cannot exceed the remaining balance', () {
      final dry = store.openNewCycle(
        designation: 'Officers', type: DemandType.dry, month: month, itemIds: {cerealsItemId},
      );
      // Allowance is days-in-month kg; asking for +1 kg must be refused.
      expect(
        () => store.placeOrder(
          customerName: 'Cdr B', customerPhone: '+91 90000 22222',
          cart: {cerealsItemId: month.days + 1.0}, cycleId: dry.id, zone: 'Officers',
        ),
        throwsStateError,
      );
    });

    test('leftover rolls into next month on top of the new allowance', () {
      final prev = month.previous;
      // Open last month's demand and take 10 kg less than the allowance.
      final prevDemand = store.openNewCycle(
        designation: 'Officers', type: DemandType.dry, month: prev, itemIds: {cerealsItemId},
      );
      final taken = prev.days - 10.0; // leaves exactly 10 kg
      store.placeOrder(
        customerName: 'Cdr C', customerPhone: '+91 90000 33333',
        cart: {cerealsItemId: taken}, cycleId: prevDemand.id, zone: 'Officers',
      );

      final carried = store.carriedInto('Cdr C', '+91 90000 33333', 'Officers', month);
      expect(carried['Cereals'], closeTo(10, 1e-9));

      // This month's balance = this month's allowance + the 10 kg carried in.
      final bal = store.balanceOf(
        name: 'Cdr C', phone: '+91 90000 33333', zone: 'Officers', category: 'Cereals', month: month,
      );
      expect(bal.allowance, month.days.toDouble());
      expect(bal.carriedIn, closeTo(10, 1e-9));
      expect(bal.total, closeTo(month.days + 10.0, 1e-9));
    });

    test('an overdraw is not carried forward as a debt', () {
      final prev = month.previous;
      // Give last month a small allowance and consume all of it — nothing left.
      store.setZonePerDay('Officers', 'Cereals', 1.0);
      final prevDemand = store.openNewCycle(
        designation: 'Officers', type: DemandType.dry, month: prev, itemIds: {cerealsItemId},
      );
      store.placeOrder(
        customerName: 'Cdr D', customerPhone: '+91 90000 44444',
        cart: {cerealsItemId: prev.days.toDouble()}, cycleId: prevDemand.id, zone: 'Officers',
      );
      final carried = store.carriedInto('Cdr D', '+91 90000 44444', 'Officers', month);
      expect(carried['Cereals'] ?? 0, 0);
    });
  });

  group('demand item curation', () {
    test('only ticked items appear; type still filters', () {
      final store = AppStore()..seedDemoData();
      final atta = store.items.firstWhere((i) => i.name == 'Atta 1 kg');
      final bread = store.items.firstWhere((i) => i.name == 'Brown Bread 400 g');

      // Dry demand curated to just atta: bread (allowed in dry) is excluded
      // because it wasn't ticked; atta is included.
      final dry = store.openNewCycle(type: DemandType.dry, itemIds: {atta.id});
      final onDemand = store.itemsForCycle(dry).map((i) => i.id).toSet();
      expect(onDemand.contains(atta.id), isTrue);
      expect(onDemand.contains(bread.id), isFalse);

      // A fresh demand can never include atta even if it were ticked.
      final fresh = store.openNewCycle(type: DemandType.fresh, itemIds: {atta.id, bread.id});
      final freshItems = store.itemsForCycle(fresh).map((i) => i.id).toSet();
      expect(freshItems.contains(atta.id), isFalse);
      expect(freshItems.contains(bread.id), isTrue);
    });
  });
}
