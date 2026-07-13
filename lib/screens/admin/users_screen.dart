import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

String roleLabel(UserRole r) => switch (r) {
      UserRole.admin => 'Admin',
      UserRole.worker => 'Staff',
      UserRole.customer => 'Customer',
    };

Color roleColor(UserRole r) => switch (r) {
      UserRole.admin => AppColors.brand,
      UserRole.worker => AppColors.cDairy,
      UserRole.customer => AppColors.accent,
    };

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addUser(context, store),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add user'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Section(
                  title: 'Staff',
                  subtitle: 'Admins & store workers who manage stock and orders',
                  users: store.staff,
                  store: store,
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Customers',
                  subtitle: 'They receive the weekly link and place orders',
                  users: store.customers,
                  store: store,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addUser(BuildContext context, AppStore store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _AddUserSheet(store: store),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<AppUser> users;
  final AppStore store;
  const _Section({required this.title, required this.subtitle, required this.users, required this.store});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle, action: Pill('${users.length}', color: AppColors.brand)),
        const SizedBox(height: 12),
        ...users.map((u) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _UserRow(user: u, store: store),
            )),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  final AppUser user;
  final AppStore store;
  const _UserRow({required this.user, required this.store});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = roleColor(user.role);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: c.withValues(alpha: 0.16),
            child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase(), style: TextStyle(color: c, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(user.name, style: t.titleSmall, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Pill(roleLabel(user.role), color: c),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [user.phone, user.unit, if (user.zone.isNotEmpty) user.zone].where((s) => s.isNotEmpty).join(' · '),
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          if (user.role != UserRole.admin)
            IconButton(
              tooltip: 'Remove',
              onPressed: () => store.removeUser(user),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
            ),
        ],
      ),
    );
  }
}

class _AddUserSheet extends StatefulWidget {
  final AppStore store;
  const _AddUserSheet({required this.store});

  @override
  State<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<_AddUserSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController(text: '+91 ');
  final _unit = TextEditingController();
  UserRole _role = UserRole.customer;
  String _zone = kZoneNames.first;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add user', style: t.titleLarge),
          const SizedBox(height: 4),
          Text('Create a staff member or a customer who can order.', style: t.bodyMedium),
          const SizedBox(height: 18),
          Row(
            children: [
              _RolePick(label: 'Customer', selected: _role == UserRole.customer, color: AppColors.accent, onTap: () => setState(() => _role = UserRole.customer)),
              const SizedBox(width: 10),
              _RolePick(label: 'Staff', selected: _role == UserRole.worker, color: AppColors.cDairy, onTap: () => setState(() => _role = UserRole.worker)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Alpha Mess / Priya Nair')),
          const SizedBox(height: 14),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (for notifications)')),
          const SizedBox(height: 14),
          TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit / Block', hintText: 'e.g. Wardroom')),
          if (_role == UserRole.customer) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _zone,
              decoration: const InputDecoration(
                labelText: 'Ration scale (zone)',
                helperText: 'Entitlement scale this customer draws against',
                prefixIcon: Icon(Icons.shield_moon_outlined),
              ),
              items: [for (final z in kZoneNames) DropdownMenuItem(value: z, child: Text(z))],
              onChanged: (v) => setState(() => _zone = v ?? _zone),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final name = _name.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a name')));
                  return;
                }
                widget.store.addUser(
                  name: name,
                  role: _role,
                  phone: _phone.text.trim(),
                  unit: _unit.text.trim().isEmpty ? 'n/a' : _unit.text.trim(),
                  zone: _role == UserRole.customer ? _zone : '',
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name added')));
              },
              child: const Text('Add user'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RolePick extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _RolePick({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: selected ? color : Theme.of(context).colorScheme.outline, width: selected ? 1.6 : 1),
          ),
          child: Center(
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ),
      ),
    );
  }
}
