import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Admin sheet to blast in-app, SMS, and WhatsApp notifications to customers.
Future<BroadcastResult?> showNotifyCustomersSheet(
  BuildContext context, {
  required String title,
  required String body,
  String? itemEmoji,
  bool showPreview = true,
}) {
  return showModalBottomSheet<BroadcastResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _NotifyCustomersSheet(
      title: title,
      body: body,
      itemEmoji: itemEmoji,
      showPreview: showPreview,
    ),
  );
}

class _NotifyCustomersSheet extends StatefulWidget {
  final String title;
  final String body;
  final String? itemEmoji;
  final bool showPreview;

  const _NotifyCustomersSheet({
    required this.title,
    required this.body,
    this.itemEmoji,
    required this.showPreview,
  });

  @override
  State<_NotifyCustomersSheet> createState() => _NotifyCustomersSheetState();
}

class _NotifyCustomersSheetState extends State<_NotifyCustomersSheet> {
  bool _inApp = true;
  bool _sms = true;
  bool _whatsapp = true;
  bool _email = true;
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final customers = store.users.where((u) => u.role == UserRole.customer).toList();
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_rounded, color: AppColors.brand),
              const SizedBox(width: 8),
              Text('Notify customers', style: t.titleLarge),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${customers.length} customers · in-app + SMS + WhatsApp + email',
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (widget.showPreview) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.itemEmoji != null) Text(widget.itemEmoji!, style: const TextStyle(fontSize: 28)),
                  if (widget.itemEmoji != null) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(widget.body, style: t.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _ChannelTile(
            icon: Icons.notifications_active_rounded,
            color: AppColors.brand,
            title: 'In-app notification',
            subtitle: 'Shows in customer app bell icon',
            value: _inApp,
            onChanged: (v) => setState(() => _inApp = v),
          ),
          _ChannelTile(
            icon: Icons.sms_rounded,
            color: const Color(0xFF2563EB),
            title: 'SMS',
            subtitle: 'Text message to registered phone numbers',
            value: _sms,
            onChanged: (v) => setState(() => _sms = v),
          ),
          _ChannelTile(
            icon: Icons.chat_rounded,
            color: const Color(0xFF25D366),
            title: 'WhatsApp',
            subtitle: 'WhatsApp message to customer numbers',
            value: _whatsapp,
            onChanged: (v) => setState(() => _whatsapp = v),
          ),
          _ChannelTile(
            icon: Icons.mail_rounded,
            color: const Color(0xFFEA4335),
            title: 'Email',
            subtitle: 'Email to registered customer addresses',
            value: _email,
            onChanged: (v) => setState(() => _email = v),
          ),
          const SizedBox(height: 12),
          Text('All customers (${customers.length})', style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: customers.length,
              itemBuilder: (_, i) {
                final c = customers[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: AppColors.brandWash,
                        child: Text(c.name.substring(0, 1), style: const TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(c.name, style: t.bodyMedium)),
                      Text(c.phone, style: t.bodySmall),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sending || (!_inApp && !_sms && !_whatsapp && !_email) || customers.isEmpty
                  ? null
                  : () async {
                      final ok = await _confirmSend(context, customers, _inApp, _sms, _whatsapp, _email);
                      if (!ok || !context.mounted) return;
                      setState(() => _sending = true);
                      final result = await store.broadcastToCustomers(
                        title: widget.title,
                        body: widget.body,
                        inApp: _inApp,
                        sms: _sms,
                        whatsapp: _whatsapp,
                        email: _email,
                        itemEmoji: widget.itemEmoji,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context, result);
                    },
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_sending ? 'Sending…' : 'Review & send'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirmSend(BuildContext context, List<AppUser> customers, bool inApp, bool sms, bool whatsapp, bool email) async {
  final t = Theme.of(context).textTheme;
  final channels = <String>[
    if (inApp) 'In-app',
    if (sms) 'SMS',
    if (whatsapp) 'WhatsApp',
    if (email) 'Email',
  ].join(', ');
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Confirm send'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send to ${customers.length} customers via $channels?', style: t.bodyMedium),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: customers.length,
                itemBuilder: (_, i) {
                  final c = customers[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(c.name, style: t.titleSmall)),
                        Text(c.phone, style: t.bodySmall),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm & send')),
      ],
    ),
  );
  return ok ?? false;
}

String _cleanPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) return '91$digits';
  if (digits.length == 12 && digits.startsWith('91')) return digits;
  return digits;
}

Future<void> _openWhatsApp(String phone, String message) async {
  final p = _cleanPhone(phone);
  if (p.isEmpty) return;
  final encoded = Uri.encodeComponent(message);
  final uri = Uri.parse('https://wa.me/$p?text=$encoded');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _openSms(String phone, String message) async {
  final p = _cleanPhone(phone);
  if (p.isEmpty) return;
  final encoded = Uri.encodeComponent(message);
  final uri = Uri.parse('sms:+$p?body=$encoded');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

Future<void> _shareViaWhatsApp(String message) async {
  // Opens WhatsApp new chat / forward screen so admin can pick group or contacts
  final encoded = Uri.encodeComponent(message);
  final uri = Uri.parse('https://wa.me/?text=$encoded');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _openEmail(String to, String subject, String body) async {
  if (to.isEmpty) return;
  final uri = Uri(
    scheme: 'mailto',
    path: to,
    query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
  );
  await launchUrl(uri);
}

Future<void> _emailAll(List<String> emails, String subject, String body) async {
  if (emails.isEmpty) return;
  final uri = Uri(
    scheme: 'mailto',
    path: '',
    query: 'bcc=${emails.join(',')}&subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
  );
  await launchUrl(uri);
}

/// Shows per-customer delivery status after a broadcast with live WhatsApp, SMS & Email open buttons.
Future<void> showBroadcastDeliveryDialog(BuildContext context, BroadcastResult result, {String message = '', String subject = 'StockFlow update'}) {
  return showDialog(
    context: context,
    builder: (ctx) {
      final t2 = Theme.of(ctx).textTheme;
      final scheme = Theme.of(ctx).colorScheme;
      final hasSms = result.logs.any((l) => l.smsDelivered && l.phone.isNotEmpty);
      final hasWa = result.logs.any((l) => l.whatsappDelivered && l.phone.isNotEmpty);
      final emailList = [for (final l in result.logs) if (l.emailDelivered && l.email.isNotEmpty) l.email];
      return AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success),
            const SizedBox(width: 8),
            Text('Notification sent', style: t2.titleLarge),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary row
              Text(
                'In-app: ${result.inAppCount}  ·  SMS: ${result.smsCount}  ·  WhatsApp: ${result.whatsappCount}  ·  Email: ${result.emailCount}',
                style: t2.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text('In-app notifications delivered to customer apps in real time.', style: t2.bodySmall),
              if (result.autoEmailed) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA4335).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_read_rounded, color: Color(0xFFEA4335), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Email sent automatically to ${result.emailCount} customer${result.emailCount == 1 ? '' : 's'}.',
                          style: t2.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (message.isNotEmpty) ...[
                const SizedBox(height: 14),
                // Quick-action buttons
                if (hasWa || hasSms)
                  Text('Send to all via:', style: t2.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                if (hasWa || hasSms) const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (hasWa)
                      _ActionChip(
                        label: 'WhatsApp broadcast',
                        icon: Icons.chat_rounded,
                        color: const Color(0xFF25D366),
                        onTap: () => _shareViaWhatsApp(message),
                      ),
                    if (!result.autoEmailed && emailList.isNotEmpty)
                      _ActionChip(
                        label: 'Email all (${emailList.length})',
                        icon: Icons.mail_rounded,
                        color: const Color(0xFFEA4335),
                        onTap: () => _emailAll(emailList, subject, message),
                      ),
                    _ActionChip(
                      label: 'Copy message text',
                      icon: Icons.copy_rounded,
                      color: scheme.primary,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: message));
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Message copied')));
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Text('Per-customer', style: t2.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: result.logs.length,
                  itemBuilder: (_, i) {
                    final log = result.logs[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.brandWash,
                            child: Text(log.customerName.isNotEmpty ? log.customerName[0] : '?',
                                style: const TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(log.customerName, style: t2.titleSmall),
                                Text(log.phone, style: t2.bodySmall),
                              ],
                            ),
                          ),
                          Row(children: [
                            if (log.inAppDelivered)
                              _DeliveryChip('In-app', Icons.notifications_active_rounded, AppColors.brand),
                            const SizedBox(width: 4),
                            if (log.smsDelivered && log.phone.isNotEmpty)
                              _ActionChip(
                                label: 'SMS',
                                icon: Icons.sms_rounded,
                                color: const Color(0xFF2563EB),
                                onTap: () => _openSms(log.phone, message),
                              ),
                            const SizedBox(width: 4),
                            if (log.whatsappDelivered && log.phone.isNotEmpty)
                              _ActionChip(
                                label: 'WA',
                                icon: Icons.chat_rounded,
                                color: const Color(0xFF25D366),
                                onTap: () => _openWhatsApp(log.phone, message),
                              ),
                            const SizedBox(width: 4),
                            if (log.emailDelivered && log.email.isNotEmpty)
                              _ActionChip(
                                label: 'Mail',
                                icon: Icons.mail_rounded,
                                color: const Color(0xFFEA4335),
                                onTap: () => _openEmail(log.email, subject, message),
                              ),
                          ]),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done')),
        ],
      );
    },
  );
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(width: 2),
            Icon(Icons.open_in_new_rounded, size: 10, color: color),
          ],
        ),
      ),
    );
  }
}

class _DeliveryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _DeliveryChip(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ChannelTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: t.titleSmall),
      subtitle: Text(subtitle, style: t.bodySmall),
      value: value,
      onChanged: onChanged,
    );
  }
}
