import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/api/subflow_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../widgets/widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final connections = ref.watch(connectionsProvider);
    final email = auth is SignedIn ? auth.email : '';
    final initial = email.isEmpty ? '?' : email.characters.first.toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Профіль')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(initial,
                      style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(email, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 20),
            connections.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: LoadingView()),
              error: (e, _) => const Text('Не вдалось завантажити статус'),
              data: (list) => _ConnectionStatus(connection: list.isEmpty ? null : list.first),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Детекція помилилась?'),
              trailing: const Icon(Icons.chevron_right),
              contentPadding: EdgeInsets.zero,
              onTap: () => context.push('/feedback'),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Безпека і приватність'),
              trailing: const Icon(Icons.chevron_right),
              contentPadding: EdgeInsets.zero,
              onTap: () => context.push('/security'),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Вийти'),
              contentPadding: EdgeInsets.zero,
              onTap: () => ref.read(authControllerProvider.notifier).signOut(),
            ),
            ListTile(
              leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
              title: Text('Видалити акаунт', style: TextStyle(color: theme.colorScheme.error)),
              contentPadding: EdgeInsets.zero,
              onTap: () => _confirmDelete(context, ref),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Subflow 1.0.0 · Умови · Приватність',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    // one dialog, but armed by typing the confirmation word — honest, irreversible copy
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _DeleteDialog(),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(subflowApiProvider).deleteAccount();
    await ref.read(authControllerProvider.notifier).signOut(); // local logout → router → /login
  }
}

/// Type-to-confirm deletion per the mockup: the red button unlocks only after
/// the user types ВИДАЛИТИ.
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog();

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  static const _word = 'ВИДАЛИТИ';
  final _input = TextEditingController();
  bool _armed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(Icons.delete_forever, color: theme.colorScheme.error, size: 32),
      title: const Text('Видалити акаунт назавжди?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Зникне все: історія підписок, підключення monobank, налаштування. '
            'Токен буде відкликано. Це незворотно.',
          ),
          const SizedBox(height: 16),
          Text('Щоб підтвердити, введи $_word', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _input,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(hintText: _word),
            onChanged: (v) => setState(() => _armed = v.trim().toUpperCase() == _word),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            minimumSize: const Size(0, 44),
          ),
          onPressed: _armed ? () => Navigator.pop(context, true) : null,
          child: const Text('Видалити назавжди'),
        ),
      ],
    );
  }
}

class _ConnectionStatus extends ConsumerWidget {
  const _ConnectionStatus({required this.connection});
  final Connection? connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = connection;
    if (c == null) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.link_off, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            const Expanded(child: Text('monobank не підключено')),
            // the global FilledButton theme is full-width (Size.fromHeight); constrain it here
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => context.go('/onboarding'),
              child: const Text('Підключити'),
            ),
          ],
        ),
      );
    }
    final active = c.isActive;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(active ? Icons.check_circle : Icons.error,
                  color: active ? theme.colorScheme.primary : theme.colorScheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('monobank', style: theme.textTheme.titleMedium),
                    Text(
                      active ? 'Підключено' : 'Доступ втрачено',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (c.lastSyncAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Останнє оновлення виписки — ${_date(c.lastSyncAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (!active)
                Expanded(child: OutlinedButton(onPressed: () => context.go('/onboarding'), child: const Text('Перепідключити'))),
              if (!active) const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _confirmDisconnect(context, ref, c.id),
                  style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  child: const Text("Від'єднати банк"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDisconnect(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Від'єднати monobank?"),
        content: const Text('Заберемо доступ і зітремо завантажені транзакції. Підписки залишаться, поки не підключиш знову.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Від'єднати")),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(subflowApiProvider).disconnect(id);
    ref.invalidate(connectionsProvider);
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
